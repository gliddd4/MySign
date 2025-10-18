//
//  FilesMenuShare.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI

struct FilesMenuShare: View {
    let item: FileItem
    @State private var triggerShare = false
    
    var body: some View {
        Button(action: handleShare) {
            HStack {
                Text("Share")
                Image(systemName: "square.and.arrow.up")
            }
        }
        .onChange(of: triggerShare) { _ in
            if triggerShare {
                presentShareSheet()
            }
        }
    }
    
    private func handleShare() {
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Share initiated: \(item.name)")
        triggerShare = true
    }
    
    private func presentShareSheet() {
        ToastManager.shared.showToast.log("presentShareSheet called")
        
        DispatchQueue.main.async {
            if item.isDirectory {
                presentDirectoryShare()
            } else {
                presentFileShare()
            }
        }
    }
    
    private func presentFileShare() {
        guard FileManager.default.fileExists(atPath: item.url.path) else {
            ToastManager.shared.showToast.error("File no longer exists")
            triggerShare = false
            return
        }
        
        ToastManager.shared.showToast.log("Presenting file share for: \(item.url.lastPathComponent)")
        
        let activityController = UIActivityViewController(
            activityItems: [item.url],
            applicationActivities: nil
        )
        
        activityController.completionWithItemsHandler = { _, completed, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    ToastManager.shared.showToast.error("Share error: \(error.localizedDescription)")
                } else if completed {
                    ToastManager.shared.showToast("Shared \(item.name)")
                }
                triggerShare = false
            }
        }
        
        // Configure for iPad
        if let popover = activityController.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingController = rootViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            
            ToastManager.shared.showToast.log("About to present UIActivityViewController")
            presentingController.present(activityController, animated: true) {
                ToastManager.shared.showToast.log("UIActivityViewController presented successfully")
            }
        } else {
            ToastManager.shared.showToast.error("Could not find view controller to present from")
            triggerShare = false
        }
    }
    
    private func presentDirectoryShare() {
        ToastManager.shared.showToast.log("Starting directory ZIP creation for: \(item.name)")
        
        Task {
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let zipName = "\(item.name).zip"
                let zipURL = tempDir.appendingPathComponent(zipName)
                
                // Remove existing temp file if it exists
                if FileManager.default.fileExists(atPath: zipURL.path) {
                    try FileManager.default.removeItem(at: zipURL)
                }
                
                // Verify source directory exists
                guard FileManager.default.fileExists(atPath: item.url.path) else {
                    await MainActor.run {
                        ToastManager.shared.showToast.error("Directory no longer exists")
                        triggerShare = false
                    }
                    return
                }
                
                // Create ZIP archive
                try FileManager.default.zipItem(at: item.url, to: zipURL)
                
                // Verify ZIP was created successfully
                guard FileManager.default.fileExists(atPath: zipURL.path) else {
                    await MainActor.run {
                        ToastManager.shared.showToast.error("Failed to create ZIP file")
                        triggerShare = false
                    }
                    return
                }
                
                await MainActor.run {
                    ToastManager.shared.showToast.log("ZIP created, presenting share sheet")
                    presentZipShare(zipURL: zipURL)
                }
                
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to prepare folder for sharing: \(error.localizedDescription)")
                    triggerShare = false
                }
            }
        }
    }
    
    private func presentZipShare(zipURL: URL) {
        let activityController = UIActivityViewController(
            activityItems: [zipURL],
            applicationActivities: nil
        )
        
        activityController.completionWithItemsHandler = { _, completed, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    ToastManager.shared.showToast.error("Share error: \(error.localizedDescription)")
                } else if completed {
                    ToastManager.shared.showToast("Shared \(item.name)")
                }
                
                // Clean up temp file
                DispatchQueue.global(qos: .utility).async {
                    do {
                        if FileManager.default.fileExists(atPath: zipURL.path) {
                            try FileManager.default.removeItem(at: zipURL)
                        }
                    } catch {
                        NSLog("Failed to clean up temporary file: \(error.localizedDescription)")
                    }
                }
                
                triggerShare = false
            }
        }
        
        // Configure for iPad
        if let popover = activityController.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingController = rootViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            
            presentingController.present(activityController, animated: true)
        } else {
            ToastManager.shared.showToast.error("Could not find view controller to present from")
            triggerShare = false
        }
    }
}
