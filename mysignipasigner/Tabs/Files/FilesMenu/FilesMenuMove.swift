//
//  FilesMenuMove.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI
import UniformTypeIdentifiers

struct FilesMenuMove: View {
    let item: FileItem
    let viewModel: DirectoryViewModel
    @Binding var showMoveSheet: Bool
    @Binding var itemToMove: FileItem?
    
    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            ToastManager.shared.showToast.log("Move button tapped for \(item.name)")
            showMoveSheet = true
        }) {
            HStack {
                Text("Move")
                Image(systemName: "folder")
            }
        }
        .onChange(of: showMoveSheet) { newValue in
            if newValue {
                DocumentPickerManager.presentPicker(for: item, isPresented: $showMoveSheet, viewModel: viewModel)
            }
        }
    }
}

private class DocumentPickerManager: NSObject, UIDocumentPickerDelegate {
    @Binding var isPresented: Bool
    let item: FileItem
    let viewModel: DirectoryViewModel
    
    init(item: FileItem, isPresented: Binding<Bool>, viewModel: DirectoryViewModel) {
        self.item = item
        self._isPresented = isPresented
        self.viewModel = viewModel
        super.init()
    }
    
    static func presentPicker(for item: FileItem, isPresented: Binding<Bool>, viewModel: DirectoryViewModel) {
        let manager = DocumentPickerManager(item: item, isPresented: isPresented, viewModel: viewModel)
        
        let picker = UIDocumentPickerViewController(forExporting: [item.url])
        picker.delegate = manager
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .pageSheet
        
        let parentDirectory = item.url.deletingLastPathComponent()
        
        Task { @MainActor in
            ToastManager.shared.showToast.log("Setting picker directory to: \(parentDirectory.path)")
            picker.directoryURL = parentDirectory
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }
        
        var presentingController = rootViewController
        while let presented = presentingController.presentedViewController {
            presentingController = presented
        }
        
        presentingController.present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let destinationURL = urls.first else {
            DispatchQueue.main.async {
                self.isPresented = false
            }
            return
        }
        
        DispatchQueue.main.async {
            Task { @MainActor in
                await self.handleMoveCompletion(to: destinationURL)
                self.isPresented = false
            }
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        DispatchQueue.main.async {
            self.isPresented = false
        }
    }
    
    @MainActor
    private func handleMoveCompletion(to finalURL: URL) async {
        do {
            if FileManager.default.fileExists(atPath: finalURL.path) {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.success("Moved \(item.name) to \(finalURL.deletingLastPathComponent().lastPathComponent)")
                viewModel.loadDocumentsDirectory()
            } else {
                ToastManager.shared.showToast.error("Move operation may have failed")
            }
        }
    }
}
