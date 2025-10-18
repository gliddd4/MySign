//
//  RepoMenuJSON.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct MenuJSON: View {
    let repository: RepositoryFormat
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @ObservedObject var downloadManager: DownloadManager
    
    var body: some View {
        Group {
            Button(action: copyJSON) {
                Label("Copy JSON", systemImage: "doc.text")
            }
            .disabled(downloadManager.isLoading)
            
            Button(action: downloadJSON) {
                Label("Download JSON", systemImage: "arrow.down.doc")
            }
            .disabled(downloadManager.isLoading)
        }
    }
    
    private func copyJSON() {
        Task {
            do {
                downloadManager.isLoading = true
                let json = try await viewModel.fetchRepositoryJSON(for: repository)
                UIPasteboard.general.string = json
                await MainActor.run {
                    downloadManager.isLoading = false
                    themeManager.showToast("Copied")
                }
            } catch {
                await MainActor.run {
                    downloadManager.isLoading = false
                    themeManager.showToast("\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func downloadJSON() {
        Task {
            await downloadManager.downloadJSON(for: repository, viewModel: viewModel)
        }
    }
}
