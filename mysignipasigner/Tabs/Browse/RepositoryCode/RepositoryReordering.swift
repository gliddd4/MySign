//
//  RepositoryReordering.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct RepositoryDropDelegate: DropDelegate {
    let viewModel: RepositoryViewModel
    let isFavoritesSection: Bool
    @Binding var orderedRepositories: [String]
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            guard let data = data as? Data,
                  let id = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor in
                guard let repository = viewModel.repositories.first(where: { $0.id == id }) else { return }
                let isFavorite = FavoritesManager.shared.isFavorite(repository)
                guard isFavorite == isFavoritesSection else { return }
                
                // Remove from current position
                if let currentIndex = orderedRepositories.firstIndex(of: id) {
                    orderedRepositories.remove(at: currentIndex)
                    
                    // Calculate section repositories
                    let sectionRepositories = isFavoritesSection ?
                        viewModel.repositories.filter { FavoritesManager.shared.isFavorite($0) } :
                        viewModel.repositories.filter { !FavoritesManager.shared.isFavorite($0) }
                    
                    // Calculate relative drop position within section
                    let dropPosition = info.location.y
                    let rowHeight: CGFloat = 44 // Approximate row height
                    let targetIndex = Int(dropPosition / rowHeight)
                    
                    // Ensure target index is within bounds
                    let validTargetIndex = min(max(0, targetIndex), sectionRepositories.count)
                    
                    // Insert at new position
                    orderedRepositories.insert(id, at: min(validTargetIndex, orderedRepositories.count))
                    
                    // Save the new order
                    FavoritesManager.shared.saveOrderedRepositories(orderedRepositories)
                }
            }
        }
        return true
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
