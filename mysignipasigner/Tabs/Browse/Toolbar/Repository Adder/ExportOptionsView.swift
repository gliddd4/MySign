//
//  ExportOptionsView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ExportOptionsView: View {
    @ObservedObject var theme: Theme
    @ObservedObject var viewModel: RepositoryViewModel
    
    private var repositoryUrls: [String] {
        viewModel.repositories.compactMap { repository in
            viewModel.getRepositoryURL(for: repository.identifier)
        }
    }
    
    private func exportAsESign() {
        let urls = repositoryUrls
        if urls.isEmpty {
            HapticManager.shared.medium()
            theme.showToast("No repositories to export", isError: true)
            return
        }
        
        let urlList = urls.joined(separator: "\n")
        let encoded = ESignManager.shared.encryptSource(urlList)
        UIPasteboard.general.string = encoded
        HapticManager.shared.medium()
        theme.showToast("Copied eSign code!")
    }
    
    private func exportAsUrls() {
        let urls = repositoryUrls
        if urls.isEmpty {
            HapticManager.shared.medium()
            theme.showToast("No repositories to export", isError: true)
            return
        }
        
        let urlList = urls.joined(separator: "\n")
        UIPasteboard.general.string = urlList
        HapticManager.shared.medium()
        theme.showToast("Copied URLs!")
    }
    
    private func removeDuplicates() {
        let removedCount = viewModel.removeDuplicateRepositories()
        
        if removedCount > 0 {
            HapticManager.shared.medium()
            theme.showToast("Removed \(removedCount) duplicate \(removedCount == 1 ? "repository" : "repositories")")
        } else {
            HapticManager.shared.medium()
            theme.showToast("No duplicates found")
        }
    }
    
    var body: some View {
        Section(header: Text("EXPORT").secondaryHeader()) {
            Button("Export as eSign repo code") {
                exportAsESign()
            }
            .foregroundColor(theme.accentColor)
            
            Button("Export as URL list") {
                exportAsUrls()
            }
            .foregroundColor(theme.accentColor)
        }
        
        Section(header: Text("CLEANUP").secondaryHeader()) {
            Button("Remove Duplicate Repositories") {
                removeDuplicates()
            }
            .foregroundColor(theme.accentColor)
        }
    }
}
