//
//  RepoMenuDelete.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct MenuDelete: View {
    let repository: RepositoryFormat
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @Binding var orderedRepositories: [String]
    
    var body: some View {
        Button(role: .destructive, action: deleteRepository) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func deleteRepository() {
        // Find index of repository to remove from viewModel.repositories
        guard let index = viewModel.repositories.firstIndex(where: { $0.identifier == repository.identifier }) else {
            themeManager.showToast("Repository not found", isError: true)
            return
        }
        
        // Remove from ordered repositories first
        if let orderIndex = orderedRepositories.firstIndex(of: repository.identifier) {
            orderedRepositories.remove(at: orderIndex)
            UserDefaults.standard.set(orderedRepositories, forKey: "repositories_ordered")
        }
        
        // Remove from view model (this will handle URL cleanup internally)
        viewModel.removeRepository(at: index)
        
        // Show success message
        themeManager.showToast("Deleted \(repository.name)")
        
        // Log the deletion
        ToastManager.shared.showToast.log("Deleted repository: \(repository.name)")
    }
}
