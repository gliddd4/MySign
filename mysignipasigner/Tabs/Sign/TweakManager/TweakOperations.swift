//
//  TweakOperations.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import UIKit

class TweakOperations {
    static let shared = TweakOperations()
    
    private init() {}
    
    // MARK: - Tweak Loading
    func loadTweaks() async -> [TweakFolder] {
        do {
            // Get the tweaks path on main actor first
            let tweaksPath = await MainActor.run {
                return DirectoryManager.shared.getURL(for: .importedTweaks)
            }
            
            guard let tweaksPath = tweaksPath else {
                return []
            }
            
            let fileManager = FileManager.default
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: tweaksPath.path) {
                try fileManager.createDirectory(at: tweaksPath, withIntermediateDirectories: true)
            }
            
            let contents = try fileManager.contentsOfDirectory(at: tweaksPath, includingPropertiesForKeys: [.isRegularFileKey])
            
            let tweakFiles = contents.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                return pathExtension == "dylib" || pathExtension == "deb"
            }
            
            let tweaks = tweakFiles.map { fileURL in
                TweakFolder(fileURL: fileURL)
            }.sorted { $0.name < $1.name }
            
            return tweaks
            
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.error("Error scanning tweaks: \(error.localizedDescription)")
            }
            return []
        }
    }
    
    // MARK: - Tweak Deletion
    func deleteTweak(_ tweak: TweakFolder) async -> Bool {
        do {
            try FileManager.default.removeItem(at: tweak.fileURL)
            
            await MainActor.run {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.success("Tweak '\(tweak.name)' deleted")
                
                // Remove from defaults if it was a default tweak
                if DefaultTweakManager.shared.isDefaultTweak(tweak.name) {
                    DefaultTweakManager.shared.removeDefaultTweak(tweak.name)
                }
            }
            return true
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.error("Error deleting tweak: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Tweak Sharing
    @MainActor
    func shareTweak(_ tweak: TweakFolder) {
        // Show immediate feedback
        HapticManager.shared.medium()
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: tweak.fileURL.path) else {
            ToastManager.shared.showToast.error("Tweak file not found.")
            return
        }
        
        ToastManager.shared.showToast.success("Sharing tweak: \(tweak.name)")
        
        // Add delay to ensure proper presentation timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                ToastManager.shared.showToast.error("Cannot access root view controller")
                return
            }
            
            // Dismiss any existing presentations first
            if rootVC.presentedViewController != nil {
                rootVC.dismiss(animated: false) {
                    self.presentShareSheet(with: tweak.fileURL, from: rootVC)
                }
            } else {
                self.presentShareSheet(with: tweak.fileURL, from: rootVC)
            }
        }
    }
    
    // MARK: - Tweak Import
    func handleMultipleTweakImport(urls: [URL]) async -> Bool {
        guard !urls.isEmpty else {
            await MainActor.run {
                ToastManager.shared.showToast.error("No tweak files selected")
            }
            return false
        }
        
        // Get the tweaks directory on main actor
        let tweaksDirectory = await MainActor.run {
            return DirectoryManager.shared.getURL(for: .importedTweaks)
        }
        
        guard let tweaksDirectory = tweaksDirectory else {
            await MainActor.run {
                ToastManager.shared.showToast.error("Cannot access tweaks directory")
            }
            return false
        }
        
        let fileManager = FileManager.default
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: tweaksDirectory.path) {
            do {
                try fileManager.createDirectory(at: tweaksDirectory, withIntermediateDirectories: true)
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Error creating tweaks directory: \(error.localizedDescription)")
                }
                return false
            }
        }
        
        var successCount = 0
        var failureCount = 0
        
        // Process all imports synchronously
        for url in urls {
            let success = await importSingleTweak(url: url, to: tweaksDirectory)
            if success {
                successCount += 1
            } else {
                failureCount += 1
            }
        }
        
        // Show final results on main actor
        await MainActor.run {
            if successCount > 0 {
                ToastManager.shared.showToast.success("Successfully imported \(successCount) tweak(s)")
            }
            
            if failureCount > 0 {
                ToastManager.shared.showToast.warning("\(failureCount) tweak(s) failed to import")
            }
        }
        
        return successCount > 0
    }
    
    // MARK: - Private Helper Methods
    private func importSingleTweak(url: URL, to tweaksDirectory: URL) async -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        
        guard pathExtension == "dylib" || pathExtension == "deb" else {
            await MainActor.run {
                ToastManager.shared.showToast.warning("Skipping unsupported file: \(url.lastPathComponent)")
            }
            return false
        }
        
        let destinationURL = tweaksDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: url, to: destinationURL)
            
            await MainActor.run {
                ToastManager.shared.showToast.silentSuccess("Imported: \(url.lastPathComponent)")
            }
            return true
            
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.error("Failed to import \(url.lastPathComponent): \(error.localizedDescription)")
            }
            return false
        }
    }
    
    private func presentShareSheet(with fileURL: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
}