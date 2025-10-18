//
//  WallpaperManager.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import SwiftUI
import UIKit
import Foundation

@MainActor
class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    @Published var wallpaperImage: UIImage?
    @Published var isWallpaperEnabled: Bool = false
    
    private let wallpaperKey = "wallpaper_image_data"
    private let wallpaperEnabledKey = "wallpaper_enabled"
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private init() {
        loadWallpaperSettings()
    }
    
    private func loadWallpaperSettings() {
        // Load wallpaper enabled state
        isWallpaperEnabled = UserDefaults.standard.bool(forKey: wallpaperEnabledKey)
        
        // Load wallpaper image
        if let imageData = UserDefaults.standard.data(forKey: wallpaperKey),
           let image = UIImage(data: imageData) {
            wallpaperImage = image
        }
    }
    
    func setWallpaper(_ image: UIImage) {
        wallpaperImage = image
        isWallpaperEnabled = true
        
        // Save to UserDefaults
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(imageData, forKey: wallpaperKey)
        }
        UserDefaults.standard.set(true, forKey: wallpaperEnabledKey)
        
        ToastManager.shared.showToast.success("Wallpaper updated")
        ToastManager.shared.showToast.log("Set new wallpaper")
    }
    
    func toggleWallpaper() {
        isWallpaperEnabled.toggle()
        UserDefaults.standard.set(isWallpaperEnabled, forKey: wallpaperEnabledKey)
        
        let status = isWallpaperEnabled ? "enabled" : "disabled"
        ToastManager.shared.showToast.success("Wallpaper \(status)")
        ToastManager.shared.showToast.log("Toggled wallpaper to \(status)")
    }
    
    func removeWallpaper() {
        wallpaperImage = nil
        isWallpaperEnabled = false
        
        UserDefaults.standard.removeObject(forKey: wallpaperKey)
        UserDefaults.standard.set(false, forKey: wallpaperEnabledKey)
        
        ToastManager.shared.showToast.success("Wallpaper removed")
        ToastManager.shared.showToast.log("Removed wallpaper")
    }
    
    var hasWallpaper: Bool {
        return wallpaperImage != nil
    }
    
    var shouldShowWallpaper: Bool {
        return isWallpaperEnabled && wallpaperImage != nil
    }
}