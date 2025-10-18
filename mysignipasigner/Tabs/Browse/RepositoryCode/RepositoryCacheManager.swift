//
//  RepositoryCacheManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

@MainActor
class RepositoryCacheManager: ObservableObject {
    static let shared = RepositoryCacheManager()
    
    // MARK: - Lightweight Cache
    private var lastProcessedRepositories: [RepositoryFormat] = []
    private var cachedRecentlyUpdated: [AppWithRepository] = []
    private var lastUpdateTime: Date?
    
    private init() {}
    
    // MARK: - Smart Caching (Only Update When Needed)
    
    /// Returns cached apps or computes them if repositories changed
    func getRecentlyUpdatedApps(from repositories: [RepositoryFormat]) -> [AppWithRepository] {
        // Check if repositories actually changed
        if repositoriesChanged(repositories) {
            // Only recompute if data actually changed
            cachedRecentlyUpdated = computeRecentlyUpdatedApps(from: repositories)
            lastProcessedRepositories = repositories
            lastUpdateTime = Date()
            
            // Save to disk in background (non-blocking)
            Task.detached(priority: .background) {
                await self.saveCacheToDisk()
            }
        }
        
        return cachedRecentlyUpdated
    }
    
    /// Lightweight check if repositories actually changed
    private func repositoriesChanged(_ repositories: [RepositoryFormat]) -> Bool {
        guard repositories.count == lastProcessedRepositories.count else { return true }
        
        // Quick hash-based comparison
        let newHash = repositories.map { "\($0.identifier):\($0.apps.count)" }.joined()
        let oldHash = lastProcessedRepositories.map { "\($0.identifier):\($0.apps.count)" }.joined()
        
        return newHash != oldHash
    }
    
    /// Fast computation without async overhead
    private func computeRecentlyUpdatedApps(from repositories: [RepositoryFormat]) -> [AppWithRepository] {
        var uniqueApps: [String: AppWithRepository] = [:]
        
        // Simple deduplication
        for repository in repositories {
            for app in repository.apps {
                let identifier = app.downloadURL ?? app.bundleIdentifier
                let appWithRepo = AppWithRepository(
                    app: app,
                    repositoryIdentifier: repository.identifier,
                    repositoryName: repository.name
                )
                
                // Keep first occurrence (faster than date comparison)
                if uniqueApps[identifier] == nil {
                    uniqueApps[identifier] = appWithRepo
                }
            }
        }
        
        // Simple sorting by date (only for apps with dates)
        let appsWithDates = Array(uniqueApps.values).compactMap { appWithRepo -> (AppWithRepository, Date)? in
            guard let dateString = appWithRepo.app.versionDate,
                  let date = parseAppDate(dateString) else { return nil }
            return (appWithRepo, date)
        }
        
        return appsWithDates
            .sorted { $0.1 > $1.1 }  // Sort by date descending
            .map { $0.0 }            // Extract apps
    }
    
    private func parseAppDate(_ dateString: String) -> Date? {
        // Optimized date parsing - try most common format first
        let formatter = DateFormatter()
        
        // Try yyyy-MM-dd first (most common)
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) { return date }
        
        // Try other formats only if needed
        let fallbackFormats = ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd HH:mm:ss"]
        for format in fallbackFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) { return date }
        }
        
        return nil
    }
    
    // MARK: - Background Disk Operations
    
    private func saveCacheToDisk() async {
        guard let cacheURL = getCacheFileURL() else { return }
        
        let cacheData = CacheData(
            apps: await MainActor.run { cachedRecentlyUpdated },
            timestamp: await MainActor.run { lastUpdateTime ?? Date() }
        )
        
        do {
            let data = try JSONEncoder().encode(cacheData)
            try data.write(to: cacheURL)
        } catch {
            // Silent failure - disk cache is optional
        }
    }
    
    func loadCacheFromDisk() {
        guard let cacheURL = getCacheFileURL() else { return }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let cacheData = try JSONDecoder().decode(CacheData.self, from: data)
            
            // Use disk cache if less than 24 hours old
            if Date().timeIntervalSince(cacheData.timestamp) < 86400 {
                cachedRecentlyUpdated = cacheData.apps
                lastUpdateTime = cacheData.timestamp
            }
        } catch {
            // Silent failure - disk cache is optional
        }
    }
    
    private func getCacheFileURL() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("recently_updated_cache.json")
    }
    
    // MARK: - Disk Cache for Full Repositories
    
    private func getFullRepositoriesCacheFileURL() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("full_repositories_cache.json")
    }
    
    struct FullRepositoryCacheData: Codable {
        let repositories: [RepositoryFormat]
        let timestamps: [String: Date]
    }
    
    func saveFullRepositoriesToDisk(repositories: [RepositoryFormat], timestamps: [String: Date]) {
        guard let cacheURL = getFullRepositoriesCacheFileURL() else {
            ToastManager.shared.showToast.error("Failed to get cache file URL for full repositories.")
            return
        }
        
        let cacheData = FullRepositoryCacheData(repositories: repositories, timestamps: timestamps)
        
        do {
            let data = try JSONEncoder().encode(cacheData)
            try data.write(to: cacheURL, options: .atomic)
            // ToastManager.shared.showToast.log("Saved full repositories to disk.") // Optional: for debugging
        } catch {
            ToastManager.shared.showToast.error("Failed to save full repositories to disk: \(error.localizedDescription)")
        }
    }
    
    func loadFullRepositoriesFromDisk() -> (repositories: [RepositoryFormat], timestamps: [String: Date])? {
        guard let cacheURL = getFullRepositoriesCacheFileURL(),
              FileManager.default.fileExists(atPath: cacheURL.path) else {
            // ToastManager.shared.showToast.log("Full repositories cache file does not exist.") // Optional: for debugging
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decodedData = try JSONDecoder().decode(FullRepositoryCacheData.self, from: data)
            // ToastManager.shared.showToast.log("Loaded full repositories from disk.") // Optional: for debugging
            return (decodedData.repositories, decodedData.timestamps)
        } catch {
            ToastManager.shared.showToast.error("Failed to load or decode full repositories from disk: \(error.localizedDescription)")
            // Attempt to delete corrupted cache file
            try? FileManager.default.removeItem(at: cacheURL)
            ToastManager.shared.showToast.warning("Corrupted full repositories cache file deleted.")
            return nil
        }
    }
    
    // MARK: - Simple Cache Management
    
    func clearCache() {
        cachedRecentlyUpdated = []
        lastProcessedRepositories = []
        lastUpdateTime = nil
        
        Task.detached(priority: .background) {
            if let cacheURL = await self.getCacheFileURL() {
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }
    }
    
    func getCacheStatistics() -> CacheStatistics {
        let size: Int64
        if let cacheURL = getCacheFileURL(),
           let attributes = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let fileSize = attributes[.size] as? Int64 {
            size = fileSize
        } else {
            size = 0
        }
        
        return CacheStatistics(
            totalSizeBytes: size,
            fileCount: cachedRecentlyUpdated.isEmpty ? 0 : 1,
            lastUpdated: lastUpdateTime ?? Date()
        )
    }
    
    // MARK: - Legacy Compatibility (Simplified)
    
    @available(*, deprecated, message: "Use getRecentlyUpdatedApps(from:) instead")
    func updateRecentlyUpdatedCache(from repositories: [RepositoryFormat]) {
        _ = getRecentlyUpdatedApps(from: repositories)
    }
    
    @available(*, deprecated, message: "Use getRecentlyUpdatedApps(from:) instead")  
    func getRecentlyUpdatedApps() -> [AppWithRepository] {
        return cachedRecentlyUpdated
    }
}

// MARK: - Data Models (Simplified)

struct AppWithRepository: Codable, Identifiable {
    let app: App
    let repositoryIdentifier: String
    let repositoryName: String
    
    var id: String {
        "\(repositoryIdentifier)_\(app.bundleIdentifier)"
    }
}

struct CacheData: Codable {
    let apps: [AppWithRepository]
    let timestamp: Date
}

struct CacheStatistics {
    let totalSizeBytes: Int64
    let fileCount: Int
    let lastUpdated: Date
    
    init(totalSizeBytes: Int64 = 0, fileCount: Int = 0, lastUpdated: Date = Date()) {
        self.totalSizeBytes = totalSizeBytes
        self.fileCount = fileCount
        self.lastUpdated = lastUpdated
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}
