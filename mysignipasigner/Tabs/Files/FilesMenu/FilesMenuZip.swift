//
//  FilesMenuZip.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import ZIPFoundation

struct MenuZip: View {
    let item: FileItem
    let viewModel: DirectoryViewModel
    
    var body: some View {
        Button(action: {
            zipFolder(item.url)
        }) {
            HStack {
                Text("Compress")
                Image(systemName: "archivebox")
            }
        }
    }
    
    private func zipFolder(_ folderURL: URL) {
        Task {
            do {
                let zipURL = folderURL.appendingPathExtension("zip")
                
                // Create zip archive
                try FileManager.default.zipItem(at: folderURL, to: zipURL)
                
                await MainActor.run {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.success("Folder zipped successfully")
                    viewModel.loadDocumentsDirectory()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to zip folder: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct MenuUnzip: View {
    let item: FileItem
    let viewModel: DirectoryViewModel
    
    var body: some View {
        Button(action: {
            unzipFile(item.url)
        }) {
            HStack {
                Text("Uncompress")
                Image(systemName: "archivebox.fill")
            }
        }
    }
    
    private func unzipFile(_ zipURL: URL) {
        Task {
            do {
                let fileName = zipURL.deletingPathExtension().lastPathComponent
                let extractURL = zipURL.deletingLastPathComponent().appendingPathComponent(fileName)
                
                // Create destination directory if it doesn't exist
                try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)
                
                // Extract zip archive
                try FileManager.default.unzipItem(at: zipURL, to: extractURL)
                
                await MainActor.run {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.success("File unzipped successfully")
                    viewModel.loadDocumentsDirectory()
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to unzip file: \(error.localizedDescription)")
                }
            }
        }
    }
}
