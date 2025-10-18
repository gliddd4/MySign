//
//  RepositoryViewModel.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import os.log
import Foundation
import UIKit

@MainActor
class RepositoryViewModel: ObservableObject {
    static let shared = RepositoryViewModel()
    
    @Published var repositories: [RepositoryFormat] = []
    @Published var progress: Float = 0
    @Published var isLoading: Bool = false
    @Published var hasCompletedInitialFetch: Bool = false
    private var identifierToURLMap: [String: String] = [:]
    private var repositoryURLs: [String] {
        get { RepositoryURLManager.shared.repositoryURLs }
        set { RepositoryURLManager.shared.repositoryURLs = newValue }
    }
    private let iconManager = IconManager.shared
    private let cacheManager = RepositoryCacheManager.shared
    
    private var fetchTask: Task<Void, Never>?
    private let maxConcurrentRequests = 4
    private var repositoryCache: [String: RepositoryFormat] = [:]
    private let cacheExpirationInterval: TimeInterval = 86400
    private var cacheTimestamps: [String: Date] = [:]
    
    private var bulkOperationInProgress = false
    private let progressUpdateQueue = DispatchQueue(label: "progress-updates", qos: .utility)
    
    private init() {
        loadSavedRepositories()
        loadCachedRepositories()
        
        Task {
            await removeDuplicatesOnLaunch()
        }
    }
    
    private func loadCachedRepositories() {
        if let (cachedFromDisk, timestampsFromDisk) = cacheManager.loadFullRepositoriesFromDisk() {
            let now = Date()
            let validCached = cachedFromDisk.filter { repo in
                if let timestamp = timestampsFromDisk[repo.identifier],
                   now.timeIntervalSince(timestamp) < cacheExpirationInterval {
                    repositoryCache[repo.identifier] = repo // This is an in-memory cache
                    cacheTimestamps[repo.identifier] = timestamp
                    return true
                }
                return false
            }

            if !validCached.isEmpty {
                // Remove duplicates before setting repositories
                let uniqueCached = filterOutDuplicates(from: validCached)
                repositories = uniqueCached
                
                if uniqueCached.count < validCached.count {
                    ToastManager.shared.showToast.log("Filtered out \(validCached.count - uniqueCached.count) duplicates from cached repositories")
                }
                
                Task {
                    await rebuildIdentifierToURLMapping()
                    await downloadMissingIcons(for: uniqueCached)
                    await clearFallbackIconsIfDisabled()
                }
                ToastManager.shared.showToast.log("Loaded \(uniqueCached.count) unique repositories from disk cache")
                _ = cacheManager.getRecentlyUpdatedApps(from: uniqueCached)
                return
            } else {
                ToastManager.shared.showToast.log("Disk cache for full repositories was empty or all entries were expired.")
            }
        } else {
            ToastManager.shared.showToast.log("No data found in disk cache for full repositories.")
        }

        // Fallback to UserDefaults (legacy, for one-time migration)
        if let data = UserDefaults.standard.data(forKey: "cached_repositories"),
           let cachedFromUserDefaults = try? JSONDecoder().decode([RepositoryFormat].self, from: data),
           let timestampsFromUserDefaults = UserDefaults.standard.object(forKey: "cache_timestamps") as? [String: Date] {
            
            ToastManager.shared.showToast.log("Found legacy repository data in UserDefaults. Attempting migration.")
            let now = Date()
            let validCachedUserDefaults = cachedFromUserDefaults.filter { repo in
                if let timestamp = timestampsFromUserDefaults[repo.identifier],
                   now.timeIntervalSince(timestamp) < cacheExpirationInterval {
                    repositoryCache[repo.identifier] = repo
                    cacheTimestamps[repo.identifier] = timestamp
                    return true
                }
                return false
            }
            
            if !validCachedUserDefaults.isEmpty {
                // Remove duplicates before setting repositories
                let uniqueCachedUserDefaults = filterOutDuplicates(from: validCachedUserDefaults)
                repositories = uniqueCachedUserDefaults
                
                if uniqueCachedUserDefaults.count < validCachedUserDefaults.count {
                    ToastManager.shared.showToast.log("Filtered out \(validCachedUserDefaults.count - uniqueCachedUserDefaults.count) duplicates from legacy cache")
                }
                
                Task {
                    await rebuildIdentifierToURLMapping()
                    await downloadMissingIcons(for: uniqueCachedUserDefaults)
                    await clearFallbackIconsIfDisabled()
                }
                ToastManager.shared.showToast.log("Loaded \(uniqueCachedUserDefaults.count) unique repositories from UserDefaults cache (legacy). Migrating to disk cache.")
                _ = cacheManager.getRecentlyUpdatedApps(from: uniqueCachedUserDefaults)
                
                cacheManager.saveFullRepositoriesToDisk(repositories: uniqueCachedUserDefaults, timestamps: cacheTimestamps)
                UserDefaults.standard.removeObject(forKey: "cached_repositories")
                UserDefaults.standard.removeObject(forKey: "cache_timestamps")
                UserDefaults.standard.synchronize()
                ToastManager.shared.showToast.log("Successfully migrated and cleared legacy UserDefaults repository cache.")
                return
            } else {
                 ToastManager.shared.showToast.log("Legacy UserDefaults repository data was empty or expired. Clearing it.")
                 UserDefaults.standard.removeObject(forKey: "cached_repositories")
                 UserDefaults.standard.removeObject(forKey: "cache_timestamps")
                 UserDefaults.standard.synchronize()
            }
        }
        
        // If no cached repositories, create placeholders from icon files for instant display
        let placeholderRepositories = iconManager.createPlaceholderRepositories()
        if !placeholderRepositories.isEmpty {
            // Remove duplicates from placeholders too
            let uniquePlaceholders = filterOutDuplicates(from: placeholderRepositories)
            repositories = uniquePlaceholders
            
            if uniquePlaceholders.count < placeholderRepositories.count {
                ToastManager.shared.showToast.log("Filtered out \(placeholderRepositories.count - uniquePlaceholders.count) duplicates from placeholders")
            }
            
            ToastManager.shared.showToast.log("Created \(uniquePlaceholders.count) unique placeholder repositories from cached icons for instant display")
            
            // Start fetching actual repository data in the background
            Task {
                await fetchRepositories()
            }
        } else {
            ToastManager.shared.showToast.log("No cached repositories or icons found, will fetch fresh data")
            Task {
                await fetchRepositories()
            }
        }
    }
    
    private func saveCachedRepositories() {
        Task.detached(priority: .background) {
            let currentRepositories = await self.repositories
            let currentTimestamps = await self.cacheTimestamps
            await MainActor.run {
                self.cacheManager.saveFullRepositoriesToDisk(repositories: currentRepositories, timestamps: currentTimestamps)
            }
        }
    }

    private func loadSavedRepositories() {
        // Load the identifier to URL mapping from saved data
        if UserDefaults.standard.stringArray(forKey: "saved_repository_urls") != nil {
            // This is legacy data - we should migrate it but not use it for URL management
            ToastManager.shared.showToast.log("Found legacy saved repository URLs, but using RepositoryURLManager for consistency")
        }
    }
    
    func updateIdentifierURLMapping(_ repository: RepositoryFormat, url: String) {
        identifierToURLMap[repository.identifier] = url
        // Don't save URLs here - they're managed by RepositoryURLManager
    }

    func getRepositoryURL(for identifier: String) -> String? {
        return identifierToURLMap[identifier]
    }
    
    private func filterOutDuplicates(from newRepositories: [RepositoryFormat]) -> [RepositoryFormat] {
        return newRepositories.filter { newRepo in
            // Check if this new repository would be a duplicate of existing ones
            !repositories.contains { existing in
                newRepo.isDuplicateOf(existing)
            }
        }
    }
    
    func addRepositories(urls: [String]) async {
        bulkOperationInProgress = true
        defer { bulkOperationInProgress = false }
        
        var currentURLs = repositoryURLs
        
        let existingURLs = Set(repositories.compactMap { getRepositoryURL(for: $0.identifier) })
        
        // Filter out URLs that already exist
        let newUrls = urls.filter { url in
            !currentURLs.contains(url) && !existingURLs.contains(url)
        }
        
        guard !newUrls.isEmpty else {
            let duplicateCount = urls.count - newUrls.count
            if duplicateCount > 0 {
                ToastManager.shared.showToast.log("Filtered out \(duplicateCount) duplicate URL\(duplicateCount == 1 ? "" : "s") during import")
            }
            return
        }
        
        currentURLs.append(contentsOf: newUrls)
        repositoryURLs = currentURLs
        
        let placeholders: [RepositoryFormat] = newUrls.map { url in
            RepositoryFormat(
                name: "Loading...",
                identifier: UUID().uuidString,
                iconURL: nil,
                website: nil,
                unlockURL: nil,
                patreonURL: nil,
                subtitle: nil,
                description: url,
                tintColor: nil,
                featuredApps: nil,
                apps: []
            )
        }
        
        repositories.append(contentsOf: placeholders)
        
        for (placeholder, url) in zip(placeholders, newUrls) {
            updateIdentifierURLMapping(placeholder, url: url)
        }
        
        let batches = Array(zip(placeholders, newUrls)).chunked(into: 2)
        
        for batch in batches {
            await withTaskGroup(of: Void.self) { group in
                for (placeholder, url) in batch {
                    group.addTask {
                        await self.fetchAndReplacePlaceholder(repository: placeholder, url: url)
                    }
                }
            }
        }
        _ = removeDuplicateRepositories()
    }
    
    func addRepository(url: String) {
        Task {
            await addRepositories(urls: [url])
        }
    }
    
    func removeRepository(at index: Int) {
        guard index < repositories.count else {
            ToastManager.shared.showToast.log("Invalid index \(index) for repository removal")
            return
        }
        
        let repositoryToRemove = repositories[index]
        let repositoryName = repositoryToRemove.name
        
        // Remove from URL mapping and cleanup
        if let url = getRepositoryURL(for: repositoryToRemove.identifier) {
            var currentURLs = repositoryURLs
            currentURLs.removeAll { $0 == url }
            repositoryURLs = currentURLs
            ToastManager.shared.showToast.log("Removed URL \(url) from repository URLs")
        }
        
        // Clean up all mappings and caches
        let repoId = repositoryToRemove.identifier
        identifierToURLMap.removeValue(forKey: repoId)
        repositoryCache.removeValue(forKey: repoId)
        cacheTimestamps.removeValue(forKey: repoId)
        
        // Remove repository icon
        iconManager.removeIcon(for: repositoryName)
        
        // Remove from repositories array
        repositories.remove(at: index)
        
        // Save changes
        saveCachedRepositories()
        
        // Update cache in background
        Task.detached(priority: .background) {
            let repos = await self.repositories
            await MainActor.run {
                _ = self.cacheManager.getRecentlyUpdatedApps(from: repos)
                ToastManager.shared.showToast.log("Updated recently updated apps cache after removing \(repositoryName)")
            }
        }
        
        ToastManager.shared.showToast.log("Successfully removed repository \(repositoryName) at index \(index)")
    }
    
    func removeDuplicateRepositories() -> Int {
        guard !repositories.isEmpty else { return 0 }

        var uniqueRepositories: [RepositoryFormat] = []
        var seenIdentifiers: Set<String> = []
        var seenNames: Set<String> = []
        var indicesToRemove: [Int] = []

        // Iterate through the repositories with their indices to identify duplicates
        for (index, repository) in repositories.enumerated() {
            let repoIdentifier = repository.identifier
            let repoName = repository.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if we've seen this identifier or name before
            if seenIdentifiers.contains(repoIdentifier) || seenNames.contains(repoName) {
                // This is a duplicate; mark for removal
                indicesToRemove.append(index)
            } else {
                // First time seeing this repository; keep it
                seenIdentifiers.insert(repoIdentifier)
                seenNames.insert(repoName)
                uniqueRepositories.append(repository)
            }
        }

        // Remove identified duplicates in reverse order to maintain correct indices during removal
        for index in indicesToRemove.sorted(by: >) {
            let repositoryToRemove = repositories[index]
            ToastManager.shared.showToast.log("Removing duplicate repository: \(repositoryToRemove.name) (ID: \(repositoryToRemove.identifier))")
            removeRepository(at: index)
        }

        if !indicesToRemove.isEmpty {
            ToastManager.shared.showToast.log("Removed \(indicesToRemove.count) duplicate repositories based on name and identifier.")
        }
        
        return indicesToRemove.count
    }

    private func removeDuplicatesOnLaunch() async {
        // Remove the delay - run immediately
        let removedCount = removeDuplicateRepositories()
        
        if removedCount > 0 {
            ToastManager.shared.showToast.log("Automatically removed \(removedCount) duplicate \(removedCount == 1 ? "repository" : "repositories") on app launch")
        }
        
        await clearFallbackIconsIfDisabled()
    }
    
    func fetchRepositories() async {
        fetchTask?.cancel()
        
        fetchTask = Task {
            bulkOperationInProgress = true
            defer { bulkOperationInProgress = false }
            
            isLoading = true
            repositories = []
            progress = 0
            
            let totalURLs = Float(repositoryURLs.count)
            var completedURLs: Float = 0
            var successfulURLs: [String] = []
            var failedURLs: [String] = []
            
            var fetchedRepositories: [RepositoryFormat] = []
            
            let batchSize = 2
            let batches = repositoryURLs.chunked(into: batchSize)
            
            for batch in batches {
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                
                await withTaskGroup(of: (RepositoryFormat?, String, Data?).self) { group in
                    for url in batch {
                        group.addTask(priority: .userInitiated) {
                            let cached = await self.repositoryCache[url]
                            let timestamp = await self.cacheTimestamps[url]
                            let expirationInterval = self.cacheExpirationInterval
                            
                            if let cached = cached,
                               let timestamp = timestamp,
                               Date().timeIntervalSince(timestamp) < expirationInterval {
                                return (cached, url, nil)
                            }
                            
                            let isBulkOperation = await MainActor.run { self.bulkOperationInProgress }
                            
                            do {
                                if !isBulkOperation {
                                    Task { @MainActor in
                                        ToastManager.shared.showToast.log("Fetching repository from \(url)")
                                    }
                                }
                                
                                var request = URLRequest(url: URL(string: url)!)
                                request.timeoutInterval = 8.0
                                request.cachePolicy = .returnCacheDataElseLoad
                                
                                let (data, _) = try await URLSession.shared.data(for: request)
                                let repository = try JSONDecoder().decode(RepositoryFormat.self, from: data)
                                
                                await MainActor.run {
                                    self.repositoryCache[repository.identifier] = repository
                                    self.cacheTimestamps[repository.identifier] = Date()
                                }
                                
                                if !isBulkOperation {
                                    Task { @MainActor in
                                        ToastManager.shared.showToast.log("Successfully fetched repository \(repository.name) from \(url)")
                                    }
                                }
                                return (repository, url, data)
                            } catch {
                                if !isBulkOperation {
                                    Task { @MainActor in
                                        ToastManager.shared.showToast.error("Error fetching repository \(url): \(error.localizedDescription)")
                                    }
                                }
                                return (nil, url, nil)
                            }
                        }
                    }
                    
                    for await (repository, url, _) in group {
                        guard !Task.isCancelled else {
                            isLoading = false
                            return
                        }
                        
                        if let repository = repository {
                            updateIdentifierURLMapping(repository, url: url)
                            successfulURLs.append(url)
                            
                            fetchedRepositories.append(repository)
                            
                            if let iconURL = repository.iconURL, !iconURL.isEmpty, let iconURL = URL(string: iconURL) {
                                let cachedIcon = iconManager.getCachedIcon(for: repository.name)
                                if cachedIcon == nil {
                                    Task(priority: .userInitiated) {
                                        await iconManager.saveIconInBackground(from: iconURL, name: repository.name)
                                        ToastManager.shared.showToast.log("Downloaded icon for repository \(repository.name)")
                                    }
                                }
                            }
                        } else {
                            failedURLs.append(url)
                        }
                        
                        completedURLs += 1
                        
                        await MainActor.run {
                            progress = completedURLs / totalURLs
                        }
                    }
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            await MainActor.run {
                // Remove duplicates before setting final repositories
                let uniqueRepositories = filterOutDuplicates(from: fetchedRepositories)
                repositories = uniqueRepositories
                
                if uniqueRepositories.count < fetchedRepositories.count {
                    ToastManager.shared.showToast.log("Filtered out \(fetchedRepositories.count - uniqueRepositories.count) duplicates from fetched repositories")
                }
                
                saveCachedRepositories()
                isLoading = false
                hasCompletedInitialFetch = true
                
                // Clean up orphaned icons
                let activeRepositoryNames = uniqueRepositories.map(\.name)
                iconManager.cleanupOrphanedIcons(activeRepositoryNames: activeRepositoryNames)
                
                // Run one final duplicate removal check
                _ = self.removeDuplicateRepositories()
            }
            
            // Clear fallback icons if disabled (outside MainActor.run since it's async)
            await clearFallbackIconsIfDisabled()
            
            if !successfulURLs.isEmpty {
                let count = successfulURLs.count
                ToastManager.shared.showToast.success("Fetched \(count) \(count == 1 ? "repository" : "repositories") successfully")
                
                Task.detached(priority: .background) {
                    let repos = await self.repositories
                    await MainActor.run {
                        _ = self.cacheManager.getRecentlyUpdatedApps(from: repos)
                        ToastManager.shared.showToast.log("Updated recently updated apps cache with latest repository data")
                    }
                }
            }
            
            if !failedURLs.isEmpty {
                let count = failedURLs.count
                ToastManager.shared.showToast.error("Failed to fetch \(count) \(count == 1 ? "repository" : "repositories")")
            }
        }
        
        await fetchTask?.value
    }
    
    func fetchRepositoryJSON(for repository: RepositoryFormat) async throws -> String {
        guard let url = getRepositoryURL(for: repository.identifier) else { return "" }
        let fetcher = RepositoryFetcher()
        return try await fetcher.fetchRepositoryJSON(from: url)
    }
    
    func fetchAndReplacePlaceholder(repository: RepositoryFormat, url: String) async {
        do {
            if !bulkOperationInProgress {
                Task { @MainActor in
                    ToastManager.shared.showToast.silentWarning("Fetching placeholder repository from \(url)")
                }
            }
            
            var request = URLRequest(url: URL(string: url)!)
            request.timeoutInterval = 8.0
            request.cachePolicy = .returnCacheDataElseLoad
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let newRepository = try JSONDecoder().decode(RepositoryFormat.self, from: data)
            
            await MainActor.run {
                if let index = repositories.firstIndex(where: { $0.identifier == repository.identifier }) {
                    repositories[index] = newRepository
                }
                repositoryCache[newRepository.identifier] = newRepository
                cacheTimestamps[newRepository.identifier] = Date()
            }
            
            Task.detached(priority: .background) {
                let repos = await self.repositories
                await MainActor.run {
                    _ = self.cacheManager.getRecentlyUpdatedApps(from: repos)
                }
            }
            
            if let iconURL = newRepository.iconURL, !iconURL.isEmpty {
                let cachedIcon = iconManager.getCachedIcon(for: newRepository.name)
                if cachedIcon == nil {
                    Task(priority: .userInitiated) {
                        await iconManager.saveIconInBackground(from: URL(string: iconURL), name: newRepository.name)
                        ToastManager.shared.showToast.log("Downloaded icon for repository \(newRepository.name)")
                    }
                }
            }
            
            if !bulkOperationInProgress {
                Task { @MainActor in
                    ToastManager.shared.showToast.silentSuccess("Successfully loaded repository \(newRepository.name)")
                }
            }
        } catch {
            if !bulkOperationInProgress {
                Task { @MainActor in
                    ToastManager.shared.showToast.error("Error fetching repository \(url): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func rebuildIdentifierToURLMapping() async {
        identifierToURLMap.removeAll()
        
        let currentURLs = repositoryURLs
        
        await withTaskGroup(of: Void.self) { group in
            for url in currentURLs {
                group.addTask {
                    do {
                        var request = URLRequest(url: URL(string: url)!)
                        request.timeoutInterval = 5.0
                        request.cachePolicy = .returnCacheDataElseLoad
                        
                        let (data, _) = try await URLSession.shared.data(for: request)
                        let fetchedRepo = try JSONDecoder().decode(RepositoryFormat.self, from: data)
                        
                        await MainActor.run {
                            if let matchingRepo = self.repositories.first(where: {
                                $0.identifier == fetchedRepo.identifier || $0.name == fetchedRepo.name
                            }) {
                                self.identifierToURLMap[matchingRepo.identifier] = url
                                ToastManager.shared.showToast.log("Mapped cached repository \(matchingRepo.name) to URL \(url)")
                            }
                        }
                    } catch {
                        await MainActor.run {
                            ToastManager.shared.showToast.log("Failed to rebuild mapping for URL \(url): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func downloadMissingIcons(for repositories: [RepositoryFormat]) async {
        let repositoriesNeedingIcons = repositories.filter { repo in
            iconManager.getCachedIcon(for: repo.name) == nil && 
            repo.iconURL != nil && 
            !repo.iconURL!.isEmpty
        }
        
        guard !repositoriesNeedingIcons.isEmpty else { return }
        
        let repositoryNames = repositoriesNeedingIcons.map(\.name)
        iconManager.refreshMissingIconsFromDisk(for: repositoryNames)
        
        // Filter again after disk refresh to only download truly missing icons
        let stillMissingIcons = repositoriesNeedingIcons.filter { repo in
            iconManager.getCachedIcon(for: repo.name) == nil
        }
        
        guard !stillMissingIcons.isEmpty else {
            ToastManager.shared.showToast.log("All missing icons were found on disk, no downloads needed")
            return
        }
        
        ToastManager.shared.showToast.log("Downloading \(stillMissingIcons.count) missing repository icons")
        
        await withTaskGroup(of: Void.self) { group in
            for repository in stillMissingIcons {
                group.addTask(priority: .userInitiated) {
                    await self.iconManager.downloadIconIfNeeded(for: repository)
                }
            }
        }
        
        ToastManager.shared.showToast.log("Completed downloading missing repository icons")
    }
    
    func clearFallbackIconsIfDisabled() async {
        // Check if app icon fallbacks are disabled
        if UserDefaults.standard.bool(forKey: "browse_disableAppIconFallbacks") {
            await MainActor.run {
                iconManager.clearFallbackIcons(for: repositories)
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}