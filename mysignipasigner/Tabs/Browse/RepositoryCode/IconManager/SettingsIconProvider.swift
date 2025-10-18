//  SettingsIconProvider.swift
//  mysignipasigner
//
//  Created by gliddd4

import Foundation
import UIKit
import SwiftUI

/// Loads the Discord & Developer icons used only in `SettingsView`.
@MainActor
final class SettingsIconProvider: ObservableObject {
    // MARK: - Published
    @Published var discordIcon: UIImage?
    @Published var developerIcon: UIImage?
    
    // MARK: - Constants
    private let discordURL = "https://raw.githubusercontent.com/Gliddd4/MySign/refs/heads/main/discord_128_128.png"
    private let developerURL = "https://raw.githubusercontent.com/Gliddd4/MySign/refs/heads/main/gliddd4.png"
    
    // MARK: - Init
    init() {
        Task { await loadIcons() }
    }
    
    // MARK: - Private helpers
    private func loadIcons() async {
        async let discordData = fetchImageData(from: discordURL)
        async let developerData = fetchImageData(from: developerURL)
        
        if let data = await discordData { discordIcon = UIImage(data: data) }
        if let data = await developerData { developerIcon = UIImage(data: data) }
    }
    
    private func fetchImageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
}
