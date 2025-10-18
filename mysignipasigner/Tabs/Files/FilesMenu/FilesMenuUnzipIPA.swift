//
//  FilesMenuUnzipIPA.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import ZIPFoundation

struct MenuUnzipIPA: View {
    let item: FileItem
    let viewModel: DirectoryViewModel
    
    var body: some View {
        Button(action: {
            unzipIPA(item.url)
        }) {
            HStack {
                Text("Unzip IPA")
                Image(systemName: "arrow.up.doc.on.clipboard")
            }
        }
    }
    
    private func unzipIPA(_ ipaURL: URL) {
        Task {
            do {
                let fileName = ipaURL.deletingPathExtension().lastPathComponent
                let extractURL = ipaURL.deletingLastPathComponent().appendingPathComponent(fileName)
                
                // Create destination directory if it doesn't exist
                try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)
                
                // Extract IPA archive
                try FileManager.default.unzipItem(at: ipaURL, to: extractURL)
                
                await MainActor.run {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.success("IPA unzipped successfully to \(fileName)")
                    viewModel.loadDocumentsDirectory()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to unzip IPA: \(error.localizedDescription)")
                }
            }
        }
    }
}