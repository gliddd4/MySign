//
//  RepositoryFetcher.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

class RepositoryFetcher {
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        
        // Configure cache
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024,    // 10 MB memory cache
                           diskCapacity: 50 * 1024 * 1024,         // 50 MB disk cache
                           directory: nil)
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        
        self.session = URLSession(configuration: configuration)
    }
    
    func fetchRepository(from urlString: String) async throws -> RepositoryFormat {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        // Set cache control headers
        request.setValue("max-age=3600", forHTTPHeaderField: "Cache-Control") // Cache for 1 hour
        
        let (fetchedData, fetchedResponse) = try await session.data(for: request)
        
        guard let httpResponse = fetchedResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        if let repository = try? JSONDecoder().decode(RepositoryFormat.self, from: fetchedData) {
            // Store in cache if not already cached
            if session.configuration.urlCache?.cachedResponse(for: request) == nil {
                let cachedResponse = CachedURLResponse(
                    response: httpResponse,
                    data: fetchedData,
                    userInfo: nil,
                    storagePolicy: .allowed
                )
                session.configuration.urlCache?.storeCachedResponse(cachedResponse, for: request)
            }
            return repository
        } else {
            return RepositoryFormat(
                name: URL(string: urlString)?.host ?? urlString,
                identifier: urlString,
                iconURL: nil,
                website: urlString,
                unlockURL: nil,
                patreonURL: nil,
                subtitle: nil,
                description: nil,
                tintColor: nil,
                featuredApps: nil,
                apps: []
            )
        }
    }
    
    func fetchRepositoryJSON(from url: String) async throws -> String {
        guard let requestURL = URL(string: url) else { return "" }
        
        var request = URLRequest(url: requestURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("max-age=3600", forHTTPHeaderField: "Cache-Control")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { return "" }
        
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
}
