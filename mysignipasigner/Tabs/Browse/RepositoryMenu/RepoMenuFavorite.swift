//
//  RepoMenuFavorite.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct MenuFavorite: View {
    let repository: RepositoryFormat
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var themeManager: Theme
    @ObservedObject var viewModel: RepositoryViewModel
    @Binding var orderedRepositories: [String]
    
    var body: some View {
        Button {
            // Let FavoritesManager handle all orderedRepositories modifications
            favoritesManager.toggleFavorite(for: repository, orderedRepositories: &orderedRepositories)
        } label: {
            Label(favoritesManager.isFavorite(repository) ? "Unfavorite" : "Favorite",
                  systemImage: favoritesManager.isFavorite(repository) ? "star.fill" : "star")
        }
        .foregroundColor(themeManager.accentColor)
    }
}
