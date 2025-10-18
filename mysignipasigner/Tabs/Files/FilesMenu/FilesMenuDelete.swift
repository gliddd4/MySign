//
//  FilesMenuDelete.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct FilesMenuDelete: View {
    let item: FileItem
    let viewModel: DirectoryViewModel
    
    var body: some View {
        Button(role: .destructive, action: {
            deleteItem(item.url)
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func deleteItem(_ itemURL: URL) {
        Task {
            do {
                try FileManager.default.removeItem(at: itemURL)
                
                await MainActor.run {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.success("Deleted \(itemURL.lastPathComponent)")
                    viewModel.loadDocumentsDirectory()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to delete: \(error.localizedDescription)")
                }
            }
        }
    }
}
