//
//  WallpaperSectionView.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import SwiftUI
import BezelKit

struct WallpaperSectionView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    let accentColor: Color
    
    var body: some View {
        if wallpaperManager.isWallpaperEnabled {
            Section {
                DragAndDropBox { url in
                    handleWallpaperSelection(from: url)
                }
                .frame(height: 120)
                .padding(.vertical, 8)
            }
        }
    }
    
    private func handleWallpaperSelection(from url: URL) {
        Task { @MainActor in
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    ToastManager.shared.showToast.error("Cannot access selected file")
                    return
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                let data = try Data(contentsOf: url)
                guard let image = UIImage(data: data) else {
                    ToastManager.shared.showToast.error("Invalid image file")
                    return
                }
                
                wallpaperManager.setWallpaper(image)
                
            } catch {
                ToastManager.shared.showToast.error("Failed to load image: \(error.localizedDescription)")
            }
        }
    }
}