//  UnifiedDocumentPicker.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI
import UniformTypeIdentifiers

// Fix for sideloaded apps - forces file copying instead of direct access
extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct UnifiedDocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var coordinator: FilePickerCoordinator
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: coordinator.currentPickerType.contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = coordinator.currentPickerType.allowsMultipleSelection
        
        if let accentColor = UserDefaults.standard.color(forKey: "accentColor") {
            picker.view.tintColor = accentColor
        }
        
        // Set initial directory to "On My iPhone" by not setting directoryURL
        // This allows the picker to default to the user's preferred location
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(coordinator: coordinator)
    }
    
    @MainActor
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let coordinator: FilePickerCoordinator
        
        init(coordinator: FilePickerCoordinator) {
            self.coordinator = coordinator
            super.init()
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if coordinator.currentPickerType == .certificatePairMultiple {
                Task { @MainActor in
                    await handleCertificatePairWithSecurityScope(urls: urls)
                }
                coordinator.isPresented = false
                return
            }
            
            // Handle single file selection (existing logic)
            guard let url = urls.first else { return }
            Task { @MainActor in
                ToastManager.shared.showToast.silentWarning("File selected \(url.lastPathComponent)")
            }
            
            Task { @MainActor in
                do {
                    guard let destinationFolder = coordinator.getDestinationFolder(for: coordinator.currentPickerType) else {
                        ToastManager.shared.showToast.error("Cannot determine destination folder")
                        return
                    }
                    
                    let normalizedSourcePath = url.standardized.deletingLastPathComponent().path
                    let normalizedDestPath = destinationFolder.standardized.path
                    ToastManager.shared.showToast.silentWarning("Comparing paths - Source parent \(normalizedSourcePath)")
                    ToastManager.shared.showToast.silentWarning("Comparing paths - Destination \(normalizedDestPath)")
                    
                    let isFileInDestination = normalizedSourcePath == normalizedDestPath
                    let isFileInDestinationSubfolder = normalizedSourcePath.hasPrefix(normalizedDestPath)
                    
                    let fileName = url.lastPathComponent
                    let potentialExistingFile = destinationFolder.appendingPathComponent(fileName)
                    let fileAlreadyExists = FileManager.default.fileExists(atPath: potentialExistingFile.path)
                    
                    if isFileInDestination || isFileInDestinationSubfolder {
                        ToastManager.shared.showToast.silentWarning("File is already in destination folder or subfolder, using existing file")
                        self.updateCoordinatorState(with: url)
                        return
                    }
                    
                    if fileAlreadyExists {
                        ToastManager.shared.showToast.silentWarning("File with same name already exists, using existing file")
                        self.updateCoordinatorState(with: potentialExistingFile)
                        return
                    }
                    
                    let originalName = url.lastPathComponent
                    let uniqueFilename = await nextAvailableNumberedFilename(for: originalName, in: destinationFolder)
                    let finalURL = destinationFolder.appendingPathComponent(uniqueFilename)

                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    
                    guard url.startAccessingSecurityScopedResource() else {
                        ToastManager.shared.showToast.error("Cannot access security-scoped resource")
                        return
                    }
                    
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    try FileManager.default.copyItem(at: url, to: finalURL)
                    ToastManager.shared.showToast.silentSuccess("File copied to \(finalURL.path)")
                    
                    self.updateCoordinatorState(with: finalURL)
                    
                } catch {
                    ToastManager.shared.showToast.error("Error handling file \(error.localizedDescription)")
                }
            }
        }
        
        private func handleCertificatePairWithSecurityScope(urls: [URL]) async {
            guard let destinationFolder = coordinator.getDestinationFolder(for: coordinator.currentPickerType) else {
                ToastManager.shared.showToast.error("Cannot determine destination folder")
                return
            }
            
            var p12URL: URL?
            var mpURL: URL?
            var copiedP12URL: URL?
            var copiedMPURL: URL?
            
            // First, identify the files
            for url in urls {
                let pathExtension = url.pathExtension.lowercased()
                switch pathExtension {
                case "p12":
                    p12URL = url
                case "mobileprovision":
                    mpURL = url
                default:
                    ToastManager.shared.showToast.warning("Ignoring unsupported file: \(url.lastPathComponent)")
                }
            }
            
            guard let p12 = p12URL, let mp = mpURL else {
                if p12URL != nil && mpURL == nil {
                    ToastManager.shared.showToast.error("Missing Mobile Provision file. Please select both P12 and .mobileprovision files.")
                } else if p12URL == nil && mpURL != nil {
                    ToastManager.shared.showToast.error("Missing P12 file. Please select both P12 and .mobileprovision files.")
                } else {
                    ToastManager.shared.showToast.error("No valid certificate files selected. Please select both P12 and .mobileprovision files.")
                }
                return
            }
            
            // Copy files with security-scoped access
            do {
                // Handle P12 file
                guard p12.startAccessingSecurityScopedResource() else {
                    ToastManager.shared.showToast.error("Cannot access P12 file")
                    return
                }
                
                defer { p12.stopAccessingSecurityScopedResource() }
                
                let p12Filename = await nextAvailableNumberedFilename(for: p12.lastPathComponent, in: destinationFolder)
                let p12Destination = destinationFolder.appendingPathComponent(p12Filename)
                
                if FileManager.default.fileExists(atPath: p12Destination.path) {
                    try FileManager.default.removeItem(at: p12Destination)
                }
                
                try FileManager.default.copyItem(at: p12, to: p12Destination)
                copiedP12URL = p12Destination
                ToastManager.shared.showToast.silentSuccess("P12 file copied to app storage")
                
                // Handle MP file
                guard mp.startAccessingSecurityScopedResource() else {
                    ToastManager.shared.showToast.error("Cannot access Mobile Provision file")
                    return
                }
                
                defer { mp.stopAccessingSecurityScopedResource() }
                
                let mpFilename = await nextAvailableNumberedFilename(for: mp.lastPathComponent, in: destinationFolder)
                let mpDestination = destinationFolder.appendingPathComponent(mpFilename)
                
                if FileManager.default.fileExists(atPath: mpDestination.path) {
                    try FileManager.default.removeItem(at: mpDestination)
                }
                
                try FileManager.default.copyItem(at: mp, to: mpDestination)
                copiedMPURL = mpDestination
                ToastManager.shared.showToast.silentSuccess("Mobile Provision file copied to app storage")
                
                // Update coordinator with copied files
                if let copiedP12 = copiedP12URL, let copiedMP = copiedMPURL {
                    coordinator.selectedCertificatePairP12URL = copiedP12
                    coordinator.selectedCertificatePairMPURL = copiedMP
                    coordinator.certificatePairImported = true
                    ToastManager.shared.showToast.success("Certificate pair selected: \(copiedP12.lastPathComponent) + \(copiedMP.lastPathComponent)")
                }
                
            } catch {
                ToastManager.shared.showToast.error("Failed to copy certificate files: \(error.localizedDescription)")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Task { @MainActor in
                ToastManager.shared.showToast.silentWarning("Document picker cancelled")
                coordinator.isPresented = false
            }
        }
        
        private func nextAvailableNumberedFilename(for originalName: String, in directory: URL) async -> String {
            let fileManager = FileManager.default
            do {
                let existingFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.nameKey], options: [.skipsHiddenFiles])
                let matchingFiles = existingFiles.filter { $0.lastPathComponent.hasSuffix("_\(originalName)") }
                let maxNumber = matchingFiles.compactMap { fileURL -> Int? in
                    let fileName = fileURL.lastPathComponent
                    let parts = fileName.components(separatedBy: "_")
                    if parts.count >= 2, let number = Int(parts[0]) {
                        let rest = parts[1...].joined(separator: "_")
                        if rest == originalName {
                            return number
                        }
                    }
                    return nil
                }.max() ?? 0
                return "\(maxNumber + 1)_\(originalName)"
            } catch {
                return "1_\(originalName)"
            }
        }
        
        private func updateCoordinatorState(with url: URL) {
            withAnimation {
                switch coordinator.currentPickerType {
                case .ipa:
                    coordinator.selectedFileURL = url
                    coordinator.fileImported = true
                    coordinator.customApp = false
                case .mobileprovision:
                    coordinator.selectedMPURL = url
                    coordinator.mobileProvisionImported = true
                case .p12:
                    coordinator.selectedP12URL = url
                    coordinator.p12Imported = true
                case .individualP12:
                    coordinator.selectedIndividualP12URL = url
                    coordinator.individualP12Imported = true
                case .individualMobileProv:
                    coordinator.selectedIndividualMPURL = url
                    coordinator.individualMPImported = true
                case .esigncert:
                    coordinator.selectedEsigncertURL = url
                    coordinator.esigncertImported = true
                case .tweak:
                    coordinator.selectedTweakURL = url
                    coordinator.tweakImported = true
                case .certificatePairP12, .certificatePairMobileProv:
                    coordinator.handleCertificatePairSelection(url: url, type: coordinator.currentPickerType)
                case .certificatePairMultiple:
                    // This case is handled in documentPicker method above
                    break
                case .image:
                    coordinator.selectedFileURL = url
                }
                coordinator.isPresented = false
            }
        }
    }
}