//
//  WallpaperView.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import SwiftUI
import UIKit

struct WallpaperView: View {
    @ObservedObject var wallpaperManager = WallpaperManager.shared
    
    var body: some View {
        ZStack {
            if wallpaperManager.shouldShowWallpaper,
               let wallpaperImage = wallpaperManager.wallpaperImage {
                
                GeometryReader { geometry in
                    Image(uiImage: wallpaperImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                
            } else {
                // Default background when no wallpaper
                Color.black
                    .ignoresSafeArea()
            }
        }
    }
}

struct WallpaperView_Previews: PreviewProvider {
    static var previews: some View {
        WallpaperView()
    }
}