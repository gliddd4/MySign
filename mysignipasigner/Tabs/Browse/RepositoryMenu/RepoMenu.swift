//
//  RepoMenu.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI

struct RepoMenu: View {
    let repository: RepositoryFormat
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @ObservedObject var downloadManager: DownloadManager
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Binding var orderedRepositories: [String]
    
    var body: some View {
        Group {
            menuFavorite
            Divider()
            menuURL
            Divider()
            menuJSON
            Divider()
            MenuIcon(repository: repository, themeManager: themeManager)
            Divider()
            menuDelete
        }
    }
    
    private var menuURL: some View {
        MenuURL(
            repository: repository,
            viewModel: viewModel,
            themeManager: themeManager
        )
    }
    
    private var menuJSON: some View {
        MenuJSON(
            repository: repository,
            viewModel: viewModel,
            themeManager: themeManager,
            downloadManager: downloadManager
        )
    }
    
    private var menuFavorite: some View {
        MenuFavorite(
            repository: repository,
            favoritesManager: favoritesManager,
            themeManager: themeManager,
            viewModel: viewModel,
            orderedRepositories: $orderedRepositories
        )
    }
    
    private var menuDelete: some View {
        MenuDelete(
            repository: repository,
            viewModel: viewModel,
            themeManager: themeManager,
            orderedRepositories: $orderedRepositories
        )
    }
}