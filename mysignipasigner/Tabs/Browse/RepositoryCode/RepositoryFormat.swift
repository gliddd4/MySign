//
//  RepositoryFormat.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct RepositoryFormat: Codable, Identifiable, Hashable {
    let name: String
    let identifier: String
    let iconURL: String?    // From "sourceicon"
    let website: String?    // From "sourceURL"
    let unlockURL: String?  // Direct mapping
    let patreonURL: String? // From "payURL"
    let subtitle: String?   // From "message"
    let description: String?
    let tintColor: String?
    let featuredApps: [String]?
    let apps: [App]
    let news: [NewsItem]?   // Add news property

    var id: String { identifier }

    private enum CodingKeys: String, CodingKey {
        case name
        case identifier
        case iconURL = "sourceicon"
        case _iconURL = "iconURL"
        case website = "sourceURL"
        case unlockURL
        case patreonURL = "payURL"
        case subtitle = "message"
        case description
        case tintColor
        case featuredApps
        case apps
        case news
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        identifier = try container.decode(String.self, forKey: .identifier)
        // Try sourceicon first, then iconURL
        if let sourceIcon = try container.decodeIfPresent(String.self, forKey: .iconURL) {
            iconURL = sourceIcon
        } else {
            iconURL = try container.decodeIfPresent(String.self, forKey: ._iconURL)
        }
        website = try container.decodeIfPresent(String.self, forKey: .website)
        unlockURL = try container.decodeIfPresent(String.self, forKey: .unlockURL)
        patreonURL = try container.decodeIfPresent(String.self, forKey: .patreonURL)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        tintColor = try container.decodeIfPresent(String.self, forKey: .tintColor)
        featuredApps = try container.decodeIfPresent([String].self, forKey: .featuredApps)
        apps = try container.decode([App].self, forKey: .apps)
        news = try container.decodeIfPresent([NewsItem].self, forKey: .news)
    }
    
    init(name: String,
         identifier: String,
         iconURL: String? = nil,
         website: String? = nil,
         unlockURL: String? = nil,
         patreonURL: String? = nil,
         subtitle: String? = nil,
         description: String? = nil,
         tintColor: String? = nil,
         featuredApps: [String]? = nil,
         apps: [App] = [],
         news: [NewsItem]? = nil) {
        self.name = name
        self.identifier = identifier
        self.iconURL = iconURL
        self.website = website
        self.unlockURL = unlockURL
        self.patreonURL = patreonURL
        self.subtitle = subtitle
        self.description = description
        self.tintColor = tintColor
        self.featuredApps = featuredApps
        self.apps = apps
        self.news = news
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)  // Encode to sourceicon
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(unlockURL, forKey: .unlockURL)
        try container.encodeIfPresent(patreonURL, forKey: .patreonURL)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(tintColor, forKey: .tintColor)
        try container.encodeIfPresent(featuredApps, forKey: .featuredApps)
        try container.encode(apps, forKey: .apps)
        try container.encodeIfPresent(news, forKey: .news)
    }

    func appsWithRepositoryID() -> [App] {
        apps.map { app in
            var mutableApp = app
            mutableApp._repositoryIdentifier = self.identifier
            return mutableApp
        }
    }

    func isDuplicateOf(_ other: RepositoryFormat) -> Bool {
        // Primary check: Same name (case-insensitive)
        let namesMatch = self.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ==
                        other.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Secondary check: Same identifier
        let identifiersMatch = self.identifier == other.identifier
        
        // Tertiary check: IconURL comparison with enhanced logic
        let iconURLsMatch = compareIconURLs(self.iconURL, other.iconURL)
        
        // Repository is considered duplicate if:
        // 1. Names match, OR
        // 2. Identifiers match, OR
        // 3. Names are similar AND iconURLs match (when both have valid iconURLs)
        return namesMatch ||
               identifiersMatch ||
               (areSimilarNames(self.name, other.name) && iconURLsMatch && bothHaveValidIconURLs(self.iconURL, other.iconURL))
    }
    
    private func bothHaveValidIconURLs(_ url1: String?, _ url2: String?) -> Bool {
        guard let url1 = url1, let url2 = url2 else { return false }
        
        // Basic validation that the URLs aren't empty and look like valid URLs
        let cleanUrl1 = url1.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUrl2 = url2.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !cleanUrl1.isEmpty &&
               !cleanUrl2.isEmpty &&
               (cleanUrl1.hasPrefix("http://") || cleanUrl1.hasPrefix("https://")) &&
               (cleanUrl2.hasPrefix("http://") || cleanUrl2.hasPrefix("https://"))
    }
    
    private func compareIconURLs(_ url1: String?, _ url2: String?) -> Bool {
        switch (url1, url2) {
        case (nil, nil):
            return true
        case (let url1?, let url2?):
            // Normalize URLs for comparison
            let normalizedUrl1 = normalizeIconURL(url1)
            let normalizedUrl2 = normalizeIconURL(url2)
            return normalizedUrl1 == normalizedUrl2
        default:
            return false
        }
    }
    
    private func normalizeIconURL(_ url: String) -> String {
        return url.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "https://") // Normalize protocol
    }
    
    private func areSimilarNames(_ name1: String, _ name2: String) -> Bool {
        let clean1 = name1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let clean2 = name2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for exact match
        if clean1 == clean2 { return true }
        
        // Check for substring match (one contains the other) - but only if the difference isn't too small
        if clean1.contains(clean2) && clean2.count > 3 { return true }
        if clean2.contains(clean1) && clean1.count > 3 { return true }
        
        // Check for similar names with common variations
        let variations = [
            (clean1.replacingOccurrences(of: " ", with: ""), clean2.replacingOccurrences(of: " ", with: "")),
            (clean1.replacingOccurrences(of: "-", with: ""), clean2.replacingOccurrences(of: "-", with: "")),
            (clean1.replacingOccurrences(of: "_", with: ""), clean2.replacingOccurrences(of: "_", with: ""))
        ]
        
        for (var1, var2) in variations {
            if var1 == var2 && var1.count > 3 { return true }
        }
        
        return false
    }
    
    static func findDuplicates(in repositories: [RepositoryFormat],
                              urlMapping: [String: String] = [:]) -> [RepositoryFormat] {
        var duplicates: [RepositoryFormat] = []
        var seenURLs: Set<String> = []
        
        for (index, repository) in repositories.enumerated() {
            var isDuplicate = false
            
            // Check against previous repositories for content duplication
            for previousIndex in 0..<index {
                if repository.isDuplicateOf(repositories[previousIndex]) {
                    duplicates.append(repository)
                    isDuplicate = true
                    break
                }
            }
            
            // If not already marked as duplicate, check for URL duplication
            if !isDuplicate, let repositoryId = repository.identifier as String? {
                if let url = urlMapping[repositoryId] {
                    if seenURLs.contains(url) {
                        duplicates.append(repository)
                        isDuplicate = true
                    } else {
                        seenURLs.insert(url)
                    }
                }
            }
        }
        
        return duplicates
    }
    
    static func removeDuplicates(from repositories: [RepositoryFormat]) -> [RepositoryFormat] {
        var uniqueRepositories: [RepositoryFormat] = []
        var seenIdentifiers: Set<String> = []
        var seenNames: Set<String> = []
        
        for repository in repositories {
            let repoIdentifier = repository.identifier
            let repoName = repository.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !seenIdentifiers.contains(repoIdentifier) && !seenNames.contains(repoName) {
                uniqueRepositories.append(repository)
                seenIdentifiers.insert(repoIdentifier)
                seenNames.insert(repoName)
            }
        }
        
        return uniqueRepositories
    }
}

struct App: Codable, Identifiable, Hashable {
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let version: String?
    let versionDate: String?
    let versionDescription: String?
    let downloadURL: String?
    let localizedDescription: String?
    let iconURL: String?
    let tintColor: String?
    let subtitle: String?
    let description: String?
    let category: String?
    let title: String?
    let url: String?
    let beta: Bool?
    let size: Double?
    let versions: [AppVersion]?
    let screenshotURLs: [String]?
    let isLanZouCloud: Int?
    let type: Int?

    var _repositoryIdentifier: String?
    var id: String { "\(_repositoryIdentifier ?? "unknown")_\(bundleIdentifier)" }

    var displayDescription: String? {
        description ?? localizedDescription
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case bundleIdentifier
        case developerName
        case version
        case versionDate
        case versionDescription
        case downloadURL
        case localizedDescription
        case iconURL
        case tintColor
        case subtitle
        case description
        case category
        case title
        case url
        case beta
        case size
        case versions
        case screenshotURLs
        case isLanZouCloud
        case type
        // Note: _repositoryIdentifier is not included as it's set after decoding
    }
}

struct AppVersion: Codable, Hashable {
    let version: String
    let date: String?
    let downloadURL: String?
    let size: Int?
    let versionDescription: String?
    let localizedDescription: String?
    
    private enum CodingKeys: String, CodingKey {
        case version
        case date
        case downloadURL
        case size
        case versionDescription
        case localizedDescription
    }
}