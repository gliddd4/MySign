import Foundation
import UIKit
import SwiftUI
import Nuke
import CoreImage

private extension Image {
    func iconStyle() -> some View {
        self
            .resizable()
            .interpolation(.low)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
    }
}

@MainActor
class IconManager: ObservableObject {
    static let shared = IconManager()
    
    private var iconsDirectory: URL {
        guard let url = DirectoryManager.shared.getURL(for: .repositoryIcons) else {
            fatalError("Could not access icons directory")
        }
        return url
    }
    
    @Published private var iconCache: [String: UIImage] = [:]
    @Published private var extractedTintColors: [String: UIColor] = [:]
    
    init() {
        Task(priority: .high) {
            await loadAllCachedIcons()
        }
    }
    
    // MARK: - Load All Cached Icons on Launch
    private func loadAllCachedIcons() async {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: iconsDirectory, includingPropertiesForKeys: nil)
            
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for url in fileURLs where url.pathExtension == "png" {
                    group.addTask {
                        let name = url.deletingPathExtension().lastPathComponent
                            .replacingOccurrences(of: "-", with: "/")
                            .replacingOccurrences(of: "\\", with: "/")
                        
                        let image = UIImage(contentsOfFile: url.path)
                        return (name, image)
                    }
                }
                
                for await (name, image) in group {
                    if let image = image {
                        iconCache[name] = image
                    }
                }
            }
            
            ToastManager.shared.showToast.log("Loaded \(iconCache.count) repository icons from cache")
        } catch {
            ToastManager.shared.showToast.log("Failed to load cached icons: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get Cached Repository Names for Placeholder Creation
    func getCachedRepositoryNames() -> [String] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: iconsDirectory, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "png" }
                .map { url in
                    url.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: "-", with: "/")
                        .replacingOccurrences(of: "\\", with: "/")
                }
        } catch {
            return []
        }
    }
    
    // MARK: - Create Instant Placeholder Repositories with Icons
    func createPlaceholderRepositories() -> [RepositoryFormat] {
        let cachedNames = getCachedRepositoryNames()
        ToastManager.shared.showToast.log("Creating \(cachedNames.count) placeholder repositories from cached icons")
        
        return cachedNames.map { name in
            RepositoryFormat(
                name: name,
                identifier: UUID().uuidString,
                iconURL: nil, // Icon is already cached locally
                website: nil,
                unlockURL: nil,
                patreonURL: nil,
                subtitle: "Loading apps...",
                description: "Repository data loading from cache",
                tintColor: nil,
                featuredApps: nil,
                apps: [] // Will be populated when actual repository data loads
            )
        }
    }
    
    // MARK: - Get Cached Icon (Main API)
    func getCachedIcon(for name: String) -> UIImage? {
        if let icon = iconCache[name] {
            return icon
        }
        return nil
    }
    
    func needsIconDownload(for repository: RepositoryFormat) -> Bool {
        return iconCache[repository.name] == nil && repository.iconURL != nil && !repository.iconURL!.isEmpty
    }
    
    func downloadIconIfNeeded(for repository: RepositoryFormat, priority: TaskPriority = .userInitiated) async {
        guard needsIconDownload(for: repository),
              let iconURLString = repository.iconURL,
              let iconURL = URL(string: iconURLString) else {
            return
        }
        
        await saveIconInBackground(from: iconURL, name: repository.name)
    }
    
    // MARK: - Background Icon Saving with Fallback (For New Repositories and Menu Actions)
    func saveIconInBackground(from url: URL?, name: String) async {
        guard let iconURL = url else { return }
        
        if iconCache[name] != nil {
            return
        }
        
        let sanitizedName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let destination = iconsDirectory.appendingPathComponent("\(sanitizedName).png")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: iconURL)
            if let image = UIImage(data: data) {
                try data.write(to: destination)
                await MainActor.run {
                    iconCache[name] = image
                    objectWillChange.send()
                }
                ToastManager.shared.showToast.log("Saved icon for repository: \(name)")
            }
        } catch {
            ToastManager.shared.showToast.log("Failed to save icon for \(name): \(error.localizedDescription)")
        }
    }
    
    func saveIconWithFallback(for repository: RepositoryFormat) async {
        if iconCache[repository.name] != nil {
            return
        }
        
        let sanitizedName = repository.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let destination = iconsDirectory.appendingPathComponent("\(sanitizedName).png")
        
        // First try repository iconURL if it exists
        if let iconURLString = repository.iconURL, 
           !iconURLString.isEmpty, 
           let iconURL = URL(string: iconURLString) {
            
            do {
                let (data, _) = try await URLSession.shared.data(from: iconURL)
                if let image = UIImage(data: data) {
                    try data.write(to: destination)
                    await MainActor.run {
                        iconCache[repository.name] = image
                        objectWillChange.send()
                    }
                    ToastManager.shared.showToast.log("Saved repository icon for: \(repository.name)")
                    return
                }
            } catch {
                ToastManager.shared.showToast.log("Repository icon failed for \(repository.name): \(error.localizedDescription)")
                
                // If app icon fallbacks are disabled, don't try app icons
                if UserDefaults.standard.bool(forKey: "browse_disableAppIconFallbacks") {
                    ToastManager.shared.showToast.log("App icon fallbacks disabled, skipping fallback attempts for \(repository.name)")
                    return
                }
                
                ToastManager.shared.showToast.log("App icon fallbacks enabled, trying app icons for \(repository.name)")
            }
        } else {
            // If app icon fallbacks are disabled, don't try app icons when no repository icon exists
            if UserDefaults.standard.bool(forKey: "browse_disableAppIconFallbacks") {
                ToastManager.shared.showToast.log("No repository icon URL and app icon fallbacks disabled for \(repository.name)")
                return
            }
            
            ToastManager.shared.showToast.log("No repository icon URL, trying app icons as fallback for \(repository.name)")
        }
        
        // Try up to 5 app icons as fallbacks (only if fallbacks are not disabled)
        let maxFallbackApps = min(5, repository.apps.count)
        for i in 0..<maxFallbackApps {
            let app = repository.apps[i]
            let appPosition = i == 0 ? "first" : i == 1 ? "second" : i == 2 ? "third" : i == 3 ? "fourth" : "fifth"
            
            if let iconURLString = app.iconURL,
               !iconURLString.isEmpty,
               let iconURL = URL(string: iconURLString) {
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: iconURL)
                    if let image = UIImage(data: data) {
                        try data.write(to: destination)
                        await MainActor.run {
                            iconCache[repository.name] = image
                            objectWillChange.send()
                        }
                        ToastManager.shared.showToast.log("Saved \(appPosition) app fallback icon for repository: \(repository.name)")
                        return
                    } else {
                        ToastManager.shared.showToast.log("Failed to create image from \(appPosition) app icon data for: \(repository.name)")
                    }
                } catch {
                    let nextPosition = i == 0 ? "second" : i == 1 ? "third" : i == 2 ? "fourth" : i == 3 ? "fifth" : "no more"
                    if i < maxFallbackApps - 1 {
                        ToastManager.shared.showToast.log("\(appPosition.capitalized) app icon failed for \(repository.name), trying \(nextPosition) app icon: \(error.localizedDescription)")
                    } else {
                        ToastManager.shared.showToast.log("\(appPosition.capitalized) app icon also failed for \(repository.name): \(error.localizedDescription)")
                    }
                }
            } else {
                let nextPosition = i == 0 ? "second" : i == 1 ? "third" : i == 2 ? "fourth" : i == 3 ? "fifth" : "no more"
                if i < maxFallbackApps - 1 {
                    ToastManager.shared.showToast.log("\(appPosition.capitalized) app has no valid icon URL for \(repository.name), trying \(nextPosition) app")
                } else {
                    ToastManager.shared.showToast.log("\(appPosition.capitalized) app has no valid icon URL for \(repository.name)")
                }
            }
        }
        
        if repository.apps.isEmpty {
            ToastManager.shared.showToast.log("No apps available for fallback icon for repository: \(repository.name)")
        } else {
            ToastManager.shared.showToast.log("All fallback attempts failed for repository: \(repository.name)")
        }
    }
    
    // MARK: - Manual Icon Reload (Context Menu Action)
    @MainActor
    func reloadImage(for url: String, name: String?, repository: RepositoryFormat? = nil) async -> Bool {
        guard let name = name else { return false }
        
        iconCache.removeValue(forKey: name)
        // Also clear the extracted tint color so it gets re-extracted
        extractedTintColors.removeValue(forKey: name)
        objectWillChange.send()
        
        let sanitizedName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let iconPath = iconsDirectory.appendingPathComponent("\(sanitizedName).png")
        try? FileManager.default.removeItem(at: iconPath)
        
        // If repository is provided, use the fallback method
        if let repository = repository {
            await saveIconWithFallback(for: repository)
            // Extract and cache tint color for the new icon
            _ = await extractAndCacheTintColor(for: name)
            return iconCache[name] != nil
        }
        
        // Original single URL reload logic (for backward compatibility)
        guard let iconURL = URL(string: url) else { return false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: iconURL)
            guard let image = UIImage(data: data) else { return false }
            
            try data.write(to: iconPath)
            iconCache[name] = image
            
            // Extract and cache tint color for the new icon
            _ = await extractAndCacheTintColor(for: name)
            
            objectWillChange.send()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Legacy Compatibility (Remove Network Loading)
    func loadIcon(for repository: RepositoryFormat) async {
        // NO-OP: Icons are loaded from cache only
        // This method is kept for compatibility but does nothing
        // All icons should be pre-indexed in Repository Icons folder
    }
    
    func preloadIcons(for repositories: [RepositoryFormat]) {
        // NO-OP: Icons are loaded from cache only
        // This method is kept for compatibility but does nothing
    }
    
    func isIconInvalid(_ name: String) -> Bool {
        return iconCache[name] == nil
    }
    
    // MARK: - Utility Methods
    func getLocalIconPath(for name: String) -> URL? {
        let sanitizedName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let iconPath = iconsDirectory.appendingPathComponent("\(sanitizedName).png")
        return FileManager.default.fileExists(atPath: iconPath.path) ? iconPath : nil
    }
    
    func refreshIconFromDisk(for name: String) -> Bool {
        guard iconCache[name] == nil else { return false } // Already cached
        
        let sanitizedName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let iconPath = iconsDirectory.appendingPathComponent("\(sanitizedName).png")
        
        if let image = UIImage(contentsOfFile: iconPath.path) {
            iconCache[name] = image
            objectWillChange.send()
            ToastManager.shared.showToast.log("Loaded missing icon for '\(name)' from disk")
            return true
        }
        return false
    }
    
    func refreshMissingIconsFromDisk(for repositoryNames: [String]) {
        var refreshedCount = 0
        for name in repositoryNames {
            if refreshIconFromDisk(for: name) {
                refreshedCount += 1
            }
        }
        if refreshedCount > 0 {
            ToastManager.shared.showToast.log("Refreshed \(refreshedCount) repository icons from disk cache")
        }
    }
    
    // MARK: - Icon Cleanup
    func removeIcon(for repositoryName: String) {
        let sanitizedName = repositoryName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let iconPath = iconsDirectory.appendingPathComponent("\(sanitizedName).png")
        
        iconCache.removeValue(forKey: repositoryName)
        
        if FileManager.default.fileExists(atPath: iconPath.path) {
            do {
                try FileManager.default.removeItem(at: iconPath)
                ToastManager.shared.showToast.log("Removed icon file for repository: \(repositoryName)")
                objectWillChange.send()
            } catch {
                ToastManager.shared.showToast.log("Failed to remove icon file for \(repositoryName): \(error.localizedDescription)")
            }
        }
    }
    
    func removeIcons(for repositoryNames: [String]) {
        for name in repositoryNames {
            removeIcon(for: name)
        }
        ToastManager.shared.showToast.log("Cleaned up \(repositoryNames.count) repository icon\(repositoryNames.count == 1 ? "" : "s")")
    }
    
    func cleanupOrphanedIcons(activeRepositoryNames: [String]) {
        let activeNamesSet = Set(activeRepositoryNames)
        let orphanedIcons = iconCache.keys.filter { !activeNamesSet.contains($0) }
        
        if !orphanedIcons.isEmpty {
            removeIcons(for: Array(orphanedIcons))
            ToastManager.shared.showToast.log("Cleaned up \(orphanedIcons.count) orphaned repository icon\(orphanedIcons.count == 1 ? "" : "s")")
        }
    }
    
    func clearFallbackIcons(for repositories: [RepositoryFormat]) {
        let repositoriesWithoutIconURL = repositories.filter { repo in
            repo.iconURL == nil || repo.iconURL!.isEmpty
        }
        
        let repositoryNamesWithFallbacks = repositoriesWithoutIconURL.compactMap { repo in
            // Only clear if we have a cached icon (which would be a fallback)
            iconCache[repo.name] != nil ? repo.name : nil
        }
        
        if !repositoryNamesWithFallbacks.isEmpty {
            removeIcons(for: repositoryNamesWithFallbacks)
            ToastManager.shared.showToast.log("Cleared \(repositoryNamesWithFallbacks.count) fallback icon\(repositoryNamesWithFallbacks.count == 1 ? "" : "s")")
        }
    }
    
    // MARK: - Color Extraction from Icons
    func getExtractedTintColor(for repositoryName: String) -> UIColor? {
        // Check if tint color extraction is disabled
        if UserDefaults.standard.bool(forKey: "browse_disableTintColorExtraction") {
            return nil
        }
        return extractedTintColors[repositoryName]
    }
    
    func extractAndCacheTintColor(for repositoryName: String) async -> UIColor? {
        // Check if tint color extraction is disabled
        if UserDefaults.standard.bool(forKey: "browse_disableTintColorExtraction") {
            return nil
        }
        
        guard let image = getCachedIcon(for: repositoryName) else { return nil }
        
        if let color = await extractDominantColor(from: image) {
            await MainActor.run {
                extractedTintColors[repositoryName] = color
                objectWillChange.send()
            }
            return color
        }
        return nil
    }
    
    func extractDominantColor(from image: UIImage) async -> UIColor? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                guard let inputImage = CIImage(image: image) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // First, resize the image to a smaller size for faster processing
                let resizeFilter = CIFilter(name: "CILanczosScaleTransform")!
                let targetSize: CGFloat = 50 // Small size for faster processing
                let scale = targetSize / max(inputImage.extent.width, inputImage.extent.height)
                resizeFilter.setValue(inputImage, forKey: kCIInputImageKey)
                resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
                
                guard let resizedImage = resizeFilter.outputImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let context = CIContext()
                let extent = resizedImage.extent
                
                // Convert to bitmap data
                let width = Int(extent.width)
                let height = Int(extent.height)
                let bytesPerPixel = 4
                let bytesPerRow = width * bytesPerPixel
                var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
                
                context.render(resizedImage,
                              toBitmap: &pixelData,
                              rowBytes: bytesPerRow,
                              bounds: extent,
                              format: .RGBA8,
                              colorSpace: nil)
                
                // Filter out black and white pixels and calculate average
                var redSum: UInt64 = 0
                var greenSum: UInt64 = 0
                var blueSum: UInt64 = 0
                var validPixelCount: UInt64 = 0
                
                // Define thresholds for what we consider "black" and "white"
                let blackThreshold: UInt8 = 30  // Pixels below this are considered black
                let whiteThreshold: UInt8 = 225 // Pixels above this are considered white
                
                for i in stride(from: 0, to: pixelData.count, by: 4) {
                    let red = pixelData[i]
                    let green = pixelData[i + 1]
                    let blue = pixelData[i + 2]
                    let alpha = pixelData[i + 3]
                    
                    // Skip pixels that are mostly transparent
                    guard alpha > 50 else { continue }
                    
                    // Skip pixels that are too close to black
                    let isBlack = red <= blackThreshold && green <= blackThreshold && blue <= blackThreshold
                    
                    // Skip pixels that are too close to white
                    let isWhite = red >= whiteThreshold && green >= whiteThreshold && blue >= whiteThreshold
                    
                    // Skip pure black (#000000) and pure white (#FFFFFF)
                    let isPureBlack = red == 0 && green == 0 && blue == 0
                    let isPureWhite = red == 255 && green == 255 && blue == 255
                    
                    if !isBlack && !isWhite && !isPureBlack && !isPureWhite {
                        redSum += UInt64(red)
                        greenSum += UInt64(green)
                        blueSum += UInt64(blue)
                        validPixelCount += 1
                    }
                }
                
                // If we don't have enough valid pixels, fall back to the original method
                guard validPixelCount > 0 else {
                    // Fallback to original CIAreaAverage method
                    let filter = CIFilter(name: "CIAreaAverage")!
                    filter.setValue(inputImage, forKey: kCIInputImageKey)
                    filter.setValue(CIVector(cgRect: inputImage.extent), forKey: kCIInputExtentKey)
                    
                    guard let outputImage = filter.outputImage else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    var bitmap = [UInt8](repeating: 0, count: 4)
                    context.render(outputImage,
                                  toBitmap: &bitmap,
                                  rowBytes: 4,
                                  bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                  format: .RGBA8,
                                  colorSpace: nil)
                    
                    let avgColor = UIColor(red: CGFloat(bitmap[0]) / 255.0,
                                          green: CGFloat(bitmap[1]) / 255.0,
                                          blue: CGFloat(bitmap[2]) / 255.0,
                                          alpha: CGFloat(bitmap[3]) / 255.0)
                    
                    let enhancedColor = self.enhanceColorForTinting(avgColor)
                    continuation.resume(returning: enhancedColor)
                    return
                }
                
                // Calculate average from filtered pixels
                let avgRed = CGFloat(redSum) / CGFloat(validPixelCount) / 255.0
                let avgGreen = CGFloat(greenSum) / CGFloat(validPixelCount) / 255.0
                let avgBlue = CGFloat(blueSum) / CGFloat(validPixelCount) / 255.0
                
                let filteredColor = UIColor(red: avgRed, green: avgGreen, blue: avgBlue, alpha: 1.0)
                let enhancedColor = self.enhanceColorForTinting(filteredColor)
                continuation.resume(returning: enhancedColor)
            }
        }
    }
    
    private func enhanceColorForTinting(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Increase saturation to make the color more vibrant
        let enhancedSaturation = min(saturation * 1.5, 1.0)
        // Adjust brightness to ensure good visibility
        let enhancedBrightness = max(min(brightness * 1.2, 0.9), 0.4)
        
        return UIColor(hue: hue, saturation: enhancedSaturation, brightness: enhancedBrightness, alpha: alpha)
    }
}