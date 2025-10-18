//
//  FilesMenuRename.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct MenuRename: View {
    let item: FileItem
    @Binding var showRenameAlert: Bool
    @Binding var newName: String
    
    var body: some View {
        Button(action: {
            newName = item.name
            showRenameAlert = true
            ToastManager.shared.showToast.log("Rename button tapped for \(item.name)")
        }) {
            HStack {
                Text("Rename")
                Image(systemName: "pencil")
            }
        }
    }
}

class MenuRenameHelper {
    static func renameItem(_ itemURL: URL, to newName: String, viewModel: DirectoryViewModel) {
        Task {
            do {
                let newURL = itemURL.deletingLastPathComponent().appendingPathComponent(newName)
                try FileManager.default.moveItem(at: itemURL, to: newURL)
                
                await MainActor.run {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.success("Renamed \(itemURL.lastPathComponent) to \(newName)")
                    viewModel.loadDocumentsDirectory()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to rename: \(error.localizedDescription)")
                }
            }
        }
    }
}
