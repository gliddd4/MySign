//
//  NewsViewModel.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import SwiftUI
import Foundation
import Combine

@MainActor
class NewsViewModel: ObservableObject {
    static let shared = NewsViewModel()
    
    @Published var allNews: [NewsItem] = []
    @Published var newsRepositories: [NewsRepository] = []
    @Published var isLoading: Bool = false
    
    private let repositoryViewModel = RepositoryViewModel.shared
    private var cancellables: Set<AnyCancellable> = []
    private var lastUpdateTime: Date = Date.distantPast
    private let updateThreshold: TimeInterval = 2.0 // Debounce updates
    
    // Cache for fetched news to avoid redundant network requests
    private var newsCache: [String: (news: [NewsItem], timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {
        // Load cached news immediately (non-blocking)
        loadCachedNews()
        
        // Listen to repository changes with debouncing
        repositoryViewModel.$repositories
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] repositories in
                self?.handleRepositoriesUpdate(repositories)
            }
            .store(in: &cancellables)
    }
    
    private func loadCachedNews() {
        // Load previously cached news from UserDefaults for immediate display
        if let cachedData = UserDefaults.standard.data(forKey: "cached_news_data"),
           let cachedNews = try? JSONDecoder().decode([NewsItem].self, from: cachedData) {
            self.allNews = cachedNews
        }
    }
    
    private func handleRepositoriesUpdate(_ repositories: [RepositoryFormat]) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > updateThreshold else {
            return // Skip if updated too recently
        }
        lastUpdateTime = now
        
        Task {
            await loadNewsFromRepositories(repositories)
        }
    }
    
    private func loadNewsFromRepositories(_ repositories: [RepositoryFormat]) async {
        var newsRepos: [NewsRepository] = []
        var combinedNews: [NewsItem] = []
        
        // First, collect news that's already available in repository data (fast)
        for repository in repositories {
            if let news = repository.news, !news.isEmpty {
                let newsRepo = NewsRepository(
                    repositoryName: repository.name,
                    repositoryIdentifier: repository.identifier,
                    repositoryIconURL: repository.iconURL,
                    news: news
                )
                newsRepos.append(newsRepo)
                combinedNews.append(contentsOf: news)
            }
        }
        
        await MainActor.run {
            // Update UI immediately with available data
            self.newsRepositories = newsRepos
            self.allNews = sortNews(combinedNews)
            self.cacheNews(self.allNews)
        }
        
        // Then fetch additional news from repository URLs in background (slower)
        await withTaskGroup(of: Void.self) { group in
            for repository in repositories {
                if repository.news?.isEmpty != false { // Only fetch if no news already available
                    group.addTask {
                        await self.fetchNewsFromRepositoryURL(
                            url: self.repositoryViewModel.getRepositoryURL(for: repository.identifier) ?? "",
                            repository: repository
                        )
                    }
                }
            }
        }
    }
    
    private func sortNews(_ news: [NewsItem]) -> [NewsItem] {
        return news.sorted { item1, item2 in
            guard let date1 = item1.parsedDate, let date2 = item2.parsedDate else {
                if item1.parsedDate != nil { return true }
                if item2.parsedDate != nil { return false }
                return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
            }
            return date1 > date2
        }
    }
    
    private func cacheNews(_ news: [NewsItem]) {
        // Cache news to UserDefaults for quick loading next time
        if let encoded = try? JSONEncoder().encode(news) {
            UserDefaults.standard.set(encoded, forKey: "cached_news_data")
        }
    }
    
    private func fetchNewsFromRepositoryURL(url: String, repository: RepositoryFormat) async {
        guard !url.isEmpty else { return }
        
        // Check cache first
        let now = Date()
        if let cached = newsCache[repository.identifier],
           now.timeIntervalSince(cached.timestamp) < cacheTimeout {
            await MainActor.run {
                self.updateNewsForRepository(repository, news: cached.news)
            }
            return
        }
        
        do {
            var request = URLRequest(url: URL(string: url)!)
            request.timeoutInterval = 5.0 // Reduced timeout for faster response
            request.cachePolicy = .returnCacheDataElseLoad
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newsArray = json["news"] as? [[String: Any]] {
                
                let news = newsArray.compactMap { newsDict -> NewsItem? in
                    guard let title = newsDict["title"] as? String,
                          let identifier = newsDict["identifier"] as? String else {
                        return nil
                    }
                    
                    return NewsItem(
                        title: title,
                        identifier: identifier,
                        caption: newsDict["caption"] as? String,
                        tintColor: newsDict["tintColor"] as? String,
                        imageURL: newsDict["imageURL"] as? String,
                        appID: newsDict["appID"] as? String,
                        date: newsDict["date"] as? String,
                        url: newsDict["url"] as? String,
                        notify: newsDict["notify"] as? Bool
                    )
                }
                
                // Cache the fetched news
                newsCache[repository.identifier] = (news: news, timestamp: now)
                
                await MainActor.run {
                    self.updateNewsForRepository(repository, news: news)
                }
            }
        } catch {
            // Silently handle errors to avoid blocking UI
        }
    }
    
    private func updateNewsForRepository(_ repository: RepositoryFormat, news: [NewsItem]) {
        guard !news.isEmpty else { return }
        
        let newsRepo = NewsRepository(
            repositoryName: repository.name,
            repositoryIdentifier: repository.identifier,
            repositoryIconURL: repository.iconURL,
            news: news
        )
        
        // Update the newsRepositories array
        if let existingIndex = newsRepositories.firstIndex(where: { $0.repositoryIdentifier == repository.identifier }) {
            newsRepositories[existingIndex] = newsRepo
        } else {
            newsRepositories.append(newsRepo)
        }
        
        // Rebuild all news efficiently
        var combinedNews: [NewsItem] = []
        for newsRepo in newsRepositories {
            combinedNews.append(contentsOf: newsRepo.news)
        }
        
        self.allNews = sortNews(combinedNews)
        self.cacheNews(self.allNews)
    }
    
    func refreshNews() async {
        isLoading = true
        defer { isLoading = false }
        
        // Clear cache to force fresh fetch
        newsCache.removeAll()
        
        // Refetch news from all repositories
        await withTaskGroup(of: Void.self) { group in
            for repository in repositoryViewModel.repositories {
                group.addTask {
                    await self.fetchNewsFromRepositoryURL(
                        url: self.repositoryViewModel.getRepositoryURL(for: repository.identifier) ?? "",
                        repository: repository
                    )
                }
            }
        }
    }
    
    func getNewsForRepository(_ repositoryIdentifier: String) -> [NewsItem] {
        return newsRepositories.first(where: { $0.repositoryIdentifier == repositoryIdentifier })?.news ?? []
    }
    
    func getRepositoryForNewsItem(_ newsItem: NewsItem) -> NewsRepository? {
        return newsRepositories.first { newsRepo in
            newsRepo.news.contains { $0.identifier == newsItem.identifier }
        }
    }
}