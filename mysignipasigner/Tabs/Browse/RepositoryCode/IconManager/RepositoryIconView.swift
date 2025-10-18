//
//  RepositoryIconView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Nuke

extension IconManager {
    struct RepositoryIconView: View {
        let repository: RepositoryFormat
        @ObservedObject private var iconManager = IconManager.shared
        @State private var fallbackAppIcon: UIImage?
        @State private var hasLoggedIcon = false
        
        var body: some View {
            ZStack {
                // Show cached icon if available
                if let cachedIcon = iconManager.getCachedIcon(for: repository.name) {
                    Image(uiImage: cachedIcon)
                        .resizable()
                        .interpolation(.low)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .onAppear {
                            if !hasLoggedIcon {
                                hasLoggedIcon = true
                                ToastManager.shared.showToast.log("Displaying icon for '\(repository.name)' from Repository Icons folder")
                            }
                        }
                } else if let fallbackIcon = fallbackAppIcon {
                    // Fallback to first app icon if repository has no cached icon
                    Image(uiImage: fallbackIcon)
                        .resizable()
                        .interpolation(.low)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .onAppear {
                            if !hasLoggedIcon {
                                hasLoggedIcon = true
                                ToastManager.shared.showToast.log("Using fallback app icon for repository '\(repository.name)' (no cached icon found)")
                            }
                        }
                } else {
                    // Final fallback to placeholder
                    placeholderImage
                        .onAppear {
                            if !hasLoggedIcon {
                                hasLoggedIcon = true
                                ToastManager.shared.showToast.log("Using placeholder icon for repository '\(repository.name)' (no cached or fallback icon available)")
                            }
                        }
                }
            }
            .onAppear {
                // Only load fallback icon if no cached icon exists
                if iconManager.getCachedIcon(for: repository.name) == nil {
                    Task {
                        await loadFallbackIconIfNeeded()
                    }
                }
            }
        }
        
        private var placeholderImage: some View {
            Image("unknowndark")
                .resizable()
                .interpolation(.low)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        
        private func loadFallbackIconIfNeeded() async {
            // Only attempt fallback if repository has no cached icon and has apps
            guard iconManager.getCachedIcon(for: repository.name) == nil,
                  !repository.apps.isEmpty else {
                return
            }
            
            // Try to load icon from first app (quick fallback only)
            guard let firstApp = repository.apps.first,
                  let appIconURLString = firstApp.iconURL,
                  !appIconURLString.isEmpty,
                  let appIconURL = URL(string: appIconURLString) else {
                return
            }
            
            do {
                var request = URLRequest(url: appIconURL)
                request.timeoutInterval = 3.0 // Quick timeout
                request.cachePolicy = .returnCacheDataElseLoad
                
                let (data, _) = try await URLSession.shared.data(for: request)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.fallbackAppIcon = image
                    }
                }
            } catch {
                // Silent failure - fallback will show placeholder
            }
        }
    }
}
