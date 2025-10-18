import SwiftUI

// MARK: - Individual Settings View Wrappers

struct SettingsFilesWrapper: View {
    @Binding var disableImagePreviews: Bool
    
    var body: some View {
        FilesSettingsView(disableImagePreviews: $disableImagePreviews)
            .onAppear {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.log("Opened Files Settings")
            }
    }
}

struct SettingsBrowseWrapper: View {
    @Binding var hideAppDescriptions: Bool
    @Binding var hideRepositoryAppCounts: Bool
    @Binding var hideRepositorySectionCounts: Bool
    @Binding var hideClockIcon: Bool
    @Binding var disableTintColorExtraction: Bool
    @Binding var disableAppIconFallbacks: Bool
    @Binding var useFullYearFormat: Bool
    
    var body: some View {
        BrowseSettingsView(
            hideAppDescriptions: $hideAppDescriptions,
            hideRepositoryAppCounts: $hideRepositoryAppCounts,
            hideRepositorySectionCounts: $hideRepositorySectionCounts,
            hideClockIcon: $hideClockIcon,
            disableTintColorExtraction: $disableTintColorExtraction,
            disableAppIconFallbacks: $disableAppIconFallbacks,
            useFullYearFormat: $useFullYearFormat
        )
        .onAppear {
            HapticManager.shared.medium()
            ToastManager.shared.showToast.log("Opened Browse Settings")
        }
    }
}

struct SettingsCacheWrapper: View {
    @ObservedObject var cacheManager: RepositoryCacheManager
    @Binding var cacheStatistics: CacheStatistics
    @Binding var isLoadingCacheStats: Bool
    @Binding var showClearCacheConfirmation: Bool
    
    var body: some View {
        CacheSettingsView(
            cacheManager: cacheManager,
            cacheStatistics: $cacheStatistics,
            isLoadingCacheStats: $isLoadingCacheStats,
            showClearCacheConfirmation: $showClearCacheConfirmation
        )
        .onAppear {
            HapticManager.shared.medium()
            ToastManager.shared.showToast.log("Opened Cache Management Settings")
        }
    }
}

struct SettingsThemingWrapper: View {
    @ObservedObject var tabSelectionManager: TabSelectionManager
    @ObservedObject var wallpaperManager: WallpaperManager
    @ObservedObject var statusBarManager: StatusBarManager
    let tabOptions: [SettingsView.TabOption]
    @Binding var selectedTabOption: SettingsView.TabOption?
    @Binding var showDefaultTabDialog: Bool
    @Binding var hideTabBarBlur: Bool
    @Binding var hideNavigationBarBlur: Bool
    @Binding var hideInLandscape: Bool
    @Binding var useAccentDockColor: Bool
    @Binding var unifiedDockData: Data
    
    var body: some View {
        ThemingSettingsView(
            tabSelectionManager: tabSelectionManager,
            wallpaperManager: wallpaperManager,
            statusBarManager: statusBarManager,
            tabOptions: tabOptions,
            selectedTabOption: $selectedTabOption,
            showDefaultTabDialog: $showDefaultTabDialog,
            hideTabBarBlur: $hideTabBarBlur,
            hideNavigationBarBlur: $hideNavigationBarBlur,
            hideInLandscape: $hideInLandscape,
            useAccentDockColor: $useAccentDockColor,
            unifiedDockData: $unifiedDockData
        )
        .onAppear {
            HapticManager.shared.medium()
            ToastManager.shared.showToast.log("Opened Theming Settings")
        }
    }
}