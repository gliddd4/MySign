//
//  NewsView.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import SwiftUI

struct NewsView: View {
    @StateObject private var newsViewModel = NewsViewModel.shared
    @ObservedObject private var themeManager = Theme.shared
    @ObservedObject private var iconManager = IconManager.shared
    
    var body: some View {
        Group {
            if newsViewModel.allNews.isEmpty && !newsViewModel.isLoading {
                emptyStateView
            } else {
                newsListView
            }
        }
        .background(Color(UIColor.systemBackground))
        .tint(themeManager.accentColor)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 20)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .refreshable {
            await newsViewModel.refreshNews()
        }
        .onAppear {
            // Trigger background refresh only if no news is loaded
            if newsViewModel.allNews.isEmpty {
                Task {
                    await newsViewModel.refreshNews()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No News Available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("News will appear here when repositories are added")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var newsListView: some View {
        List {
            if newsViewModel.isLoading && newsViewModel.allNews.isEmpty {
                loadingSection
            }
            
            ForEach(newsViewModel.allNews) { newsItem in
                NewsItemRow(
                    newsItem: newsItem,
                    repository: newsViewModel.getRepositoryForNewsItem(newsItem),
                    themeManager: themeManager,
                    iconManager: iconManager
                )
                .id(newsItem.identifier)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var loadingSection: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading news...")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct NewsItemRow: View {
    let newsItem: NewsItem
    let repository: NewsRepository?
    @ObservedObject var themeManager: Theme
    @ObservedObject var iconManager: IconManager
    
    @State private var newsImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Icons and Metadata
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 6) {
                    if repository != nil {
                        IconManager.RepositoryIconView(repository: repositoryAsRepositoryFormat)
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                    }
                    if let imageURL = newsItem.imageURL, !imageURL.isEmpty {
                        newsImageView
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let repoName = repository?.repositoryName {
                        Text(repoName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    if let formattedDate = newsItem.formattedDate {
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Bottom Row: Title and Caption
            VStack(alignment: .leading, spacing: 4) {
                Text(newsItem.title)
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.white)

                if let caption = newsItem.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            handleNewsItemTap()
        }
        .task {
            // Use task instead of onAppear for better performance
            await loadNewsImageIfNeeded()
        }
    }
    
    private var repositoryAsRepositoryFormat: RepositoryFormat {
        return RepositoryFormat(
            name: repository?.repositoryName ?? "Unknown",
            identifier: repository?.repositoryIdentifier ?? "unknown",
            iconURL: repository?.repositoryIconURL,
            tintColor: nil,
            apps: [],
            news: nil
        )
    }
    
    @ViewBuilder
    private var newsImageView: some View {
        if let newsImage = newsImage {
            Image(uiImage: newsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else if isLoadingImage {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .tertiarySystemBackground))
        } else {
            Rectangle()
                .fill(Color(uiColor: .tertiarySystemBackground))
        }
    }
    
    private var newsItemTintColor: Color {
        if let tintColorString = newsItem.tintColor {
            let cleanHex = tintColorString.hasPrefix("#") ? String(tintColorString.dropFirst()) : tintColorString
            return Color(hex: cleanHex)
        }
        return themeManager.accentColor
    }
    
    private func loadNewsImageIfNeeded() async {
        guard let imageURL = newsItem.imageURL,
              !imageURL.isEmpty,
              newsImage == nil,
              !isLoadingImage else { return }
        
        await MainActor.run {
            isLoadingImage = true
        }
        
        do {
            guard let url = URL(string: imageURL) else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.newsImage = uiImage
                    self.isLoadingImage = false
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingImage = false
            }
        }
    }
    
    private func handleNewsItemTap() {
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Clicked news item: \(newsItem.title)")
        
        // Handle different types of news items
        if let appID = newsItem.appID {
            // Find and show app details if this news item is linked to an app
            ToastManager.shared.showToast.log("News linked to app: \(appID)")
        } else if let urlString = newsItem.url, let webURL = URL(string: urlString) {
            // Open external URL
            UIApplication.shared.open(webURL)
            ToastManager.shared.showToast.log("Opening news URL: \(urlString)")
        } else {
            // Just show the news item was tapped
            ToastManager.shared.showToast.log("Tapped: \(newsItem.title)")
        }
    }
}
