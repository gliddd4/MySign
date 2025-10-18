//
//  FavoritesManager.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteIds: Set<String> = []
    
    private init() {
        loadFavorites()
    }
    
    func loadFavorites() {
        if let favorites = UserDefaults.standard.array(forKey: "repositories_favorites") as? [String] {
            favoriteIds = Set(favorites)
        }
    }
    
    func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: "repositories_favorites")
    }
    
    func toggleFavorite(for repository: RepositoryFormat, orderedRepositories: inout [String]) {
        objectWillChange.send()
        
        // Remove from current position
        orderedRepositories.removeAll(where: { $0 == repository.id })
        
        if favoriteIds.contains(repository.id) {
            // Unfavoriting
            favoriteIds.remove(repository.id)
            let favoriteCount = orderedRepositories.filter { id in
                favoriteIds.contains(id)
            }.count
            orderedRepositories.insert(repository.id, at: favoriteCount)
        } else {
            // Favoriting
            favoriteIds.insert(repository.id)
            orderedRepositories.insert(repository.id, at: 0)
        }
        
        saveFavorites()
        saveOrderedRepositories(orderedRepositories)
    }
    
    func isFavorite(_ repository: RepositoryFormat) -> Bool {
        favoriteIds.contains(repository.id)
    }
    
    func saveOrderedRepositories(_ repositories: [String]) {
        UserDefaults.standard.set(repositories, forKey: "repositories_ordered")
    }
}
