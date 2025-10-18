import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var themeAccent: Theme
    @EnvironmentObject var tabSelectionManager: TabSelectionManager
    @Environment(\.colorScheme) var colorScheme
    
    // Status Bar Settings
    @StateObject private var statusBarManager = StatusBarManager.shared
    
    @StateObject private var cacheManager = RepositoryCacheManager.shared
    @State private var cacheStatistics = CacheStatistics()
    @State private var isLoadingCacheStats = false
    @State private var showClearCacheConfirmation = false
    
    // Dock Settings
    @AppStorage("dock_hideInLandscape") private var hideInLandscape = true
    @AppStorage("dock_hideWithKeyboard") private var hideWithKeyboard = true
    @AppStorage("dock_useAccentColor") private var useAccentDockColor = true
    @AppStorage("dock_unifiedColor") private var unifiedDockData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    
    @AppStorage("app_hideDescriptions") private var hideAppDescriptions = false
    @AppStorage("browse_disableTintColorExtraction") private var disableTintColorExtraction = false
    @AppStorage("browse_disableAppIconFallbacks") private var disableAppIconFallbacks = false
    @AppStorage("browse_hideRepositoryAppCounts") private var hideRepositoryAppCounts = false
    @AppStorage("browse_hideRepositorySectionCounts") private var hideRepositorySectionCounts = false
    @AppStorage("browse_useFullYearFormat") private var useFullYearFormat = false
    @AppStorage("browse_hideClockIcon") private var hideClockIcon = false
    @AppStorage("ui_hideTabBarBlur") private var hideTabBarBlur = false
    @AppStorage("ui_hideNavigationBarBlur") private var hideNavigationBarBlur = false
    
    @State private var isDockSectionExpanded = false
    @State private var showDefaultTabDialog = false
    @State private var toastMessage = ""
    @FocusState private var isToastFieldFocused: Bool
    
    @AppStorage("files_disableImagePreviews") private var disableImagePreviews = false
    
    @State private var showLogsSheet = false
    @State private var showButtonStyleSheet = false
    
    @State private var selectedTabOption: TabOption?
    
    // Wallpaper Settings
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    struct TabOption: Identifiable, Equatable {
        let id: Int
        let name: String
        let symbol: String
    }
    
    let tabOptions: [TabOption] = [
        .init(id: 0, name: "Sign", symbol: "signature"),
        .init(id: 1, name: "Files", symbol: "folder"),
        .init(id: 2, name: "Browse", symbol: "sparkle.magnifyingglass"),
        .init(id: 3, name: "Downloads", symbol: "arrow.down.app"),
        .init(id: 4, name: "Settings", symbol: "gear")
    ]
    
    @StateObject private var iconProvider = SettingsIconProvider()
    
    private let discordRepo = RepositoryFormat(
        name: "Discord",
        identifier: "discord",
        iconURL: "https://raw.githubusercontent.com/Gliddd4/MySign/refs/heads/main/discord_128_128.png",
        website: nil, unlockURL: nil, patreonURL: nil,
        subtitle: nil, description: nil, tintColor: nil,
        featuredApps: nil, apps: []
    )
    
    private let developerRepo = RepositoryFormat(
        name: "Developer",
        identifier: "developer",
        iconURL: "https://raw.githubusercontent.com/Gliddd4/MySign/refs/heads/main/gliddd4.png",
        website: nil, unlockURL: nil, patreonURL: nil,
        subtitle: nil, description: nil, tintColor: nil,
        featuredApps: nil, apps: []
    )
    
    @AppStorage("dev_showPaddingDebugging") private var showPaddingDebugging = false

    @State private var showExperimentalSettings = false
    @State private var showFilesSettings = false
    @State private var showBrowseSettings = false
    @State private var showCacheSettings = false
    @State private var showThemingSettings = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        
                        // MAIN SETTINGS SECTIONS
                        VStack(spacing: 6) {
                            HStack {
                                Text("MAIN SETTINGS")
                                    .secondaryHeader()
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Using FourSplitMainButton with larger icons and proper actions
                            FourSplitMainButton(
                                left: (title: "Files", icon: "folder", action: {
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Clicked Files Settings")
                                    showFilesSettings = true
                                }),
                                middle1: (title: "Browse", icon: "sparkle.magnifyingglass", action: {
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Clicked Browse Settings")
                                    showBrowseSettings = true
                                }),
                                middle2: (title: "Cache", icon: "arrow.clockwise", action: {
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Clicked Cache Management Settings")
                                    showCacheSettings = true
                                }),
                                right: (title: "Theme", icon: "paintbrush", action: {
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Clicked Theming Settings")
                                    showThemingSettings = true
                                })
                            )
                            .padding(.horizontal)
                        }
                        
                        // OTHER Section
                        VStack(spacing: 6) {
                            HStack {
                                Text("OTHER")
                                    .secondaryHeader()
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ConnectedLabelGroup {
                                ConnectedUniversalLabel("Discord Server")
                                    .withIcon("message.circle")
                                    .withButton(UniversalButton.ButtonContent.icon("arrow.up.right"), action: {
                                        HapticManager.shared.medium()
                                        ToastManager.shared.showToast.log("Clicked Discord Server")
                                        openURL("https://discord.gg/hUK5m9MGFc")
                                    })
                                
                                ConnectedUniversalLabel("Developed by @gliddd4")
                                    .withIcon("wrench.adjustable")
                                    .lastConnectedItem()
                            }
                            .environmentObject(themeAccent)
                            .padding(.horizontal)
                        }
                        
                        // CREDITS Section
                        VStack(spacing: 6) {
                            HStack {
                                Text("CREDITS")
                                    .secondaryHeader()
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ConnectedLabelGroup {
                                ConnectedUniversalLabel("AppInstaller for Circlefy")
                                    .withIcon("app.dashed")
                                    .withButton(UniversalButton.ButtonContent.icon("arrow.up.right"), action: {
                                        HapticManager.shared.medium()
                                        ToastManager.shared.showToast.log("Clicked Circlefy link")
                                        openURL("https://github.com/AppInstalleriOSGH/Circlefy")
                                    })
                                
                                ConnectedUniversalLabel("Nabz Clan for ArkSigning")
                                    .withIcon("signature")
                                    .withButton(UniversalButton.ButtonContent.icon("arrow.up.right"), action: {
                                        HapticManager.shared.medium()
                                        ToastManager.shared.showToast.log("Clicked ArkSigning link")
                                        openURL("https://github.com/nabzclan-reborn/ArkSigning")
                                    })
                                
                                ConnectedUniversalLabel("khcrysalis for eSign repo parsing")
                                    .withIcon("square.and.arrow.down")
                                    .withButton(UniversalButton.ButtonContent.icon("arrow.up.right"), action: {
                                        ToastManager.shared.showToast.log("Clicked Feather link")
                                        openURL("https://github.com/khcrysalis/Feather/blob/main/AltSourceKit/Sources/AltSourceKit/Utilities/Key/EsignSourceKey.swift")
                                    })
                                
                                ConnectedUniversalLabel("NSAntoine for System Files Explorer")
                                    .withIcon("folder")
                                    .withButton(UniversalButton.ButtonContent.icon("arrow.up.right"), action: {
                                        HapticManager.shared.medium()
                                        ToastManager.shared.showToast.log("Clicked Santander link")
                                        openURL("https://github.com/NSAntoine/Santander")
                                    })
                                    .lastConnectedItem()
                            }
                            .environmentObject(themeAccent)
                            .padding(.horizontal)
                        }
                        
                        // EXPERIMENTAL Section
                        VStack(spacing: 6) {
                            HStack {
                                Text("EXPERIMENTAL")
                                    .secondaryHeader()
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Using SplitMainButton to combine two related actions
                            SplitMainButton(
                                left: (title: "Onboarding", icon: "hand.wave", action: {
                                    ToastManager.shared.showToast.log("Clicked Onboarding Popup")
                                    NewInstall.shared.resetInstallState()
                                }),
                                right: (title: "Styles", icon: "button.horizontal.top.press", action: {
                                    ToastManager.shared.showToast.log("Clicked Button Style Showcase")
                                    showButtonStyleSheet = true
                                })
                            )
                            .padding(.horizontal)
                            
                            ConnectedLabelGroup {
                                ConnectedUniversalLabel("Toast")
                                    .withIcon("bell")
                                    .withTextInput($toastMessage, placeholder: "Enter message")
                                    .withButton(UniversalButton.ButtonContent.icon("paperplane"), action: {
                                        if !toastMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            HapticManager.shared.medium()
                                            ToastManager.shared.showToast.log("Clicked Send Toast and sent \(toastMessage)")
                                            ToastManager.shared.showToast.warning(toastMessage)
                                            isToastFieldFocused = false
                                        }
                                    })
                                    .lastConnectedItem()
                            }
                            .environmentObject(themeAccent)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(red: 20/255, green: 20/255, blue: 20/255))
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 20)
            }
            
            NavigationManager.settingsNavigation(showLogsAction: {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.log("Clicked Logs (toolbar) in Settings")
                showLogsSheet = true
            })
            .environmentObject(tabSelectionManager)
            .environmentObject(themeAccent)
            .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .sheet(isPresented: $showLogsSheet) {
            LogsView()
                .environmentObject(themeAccent)
        }
        .sheet(isPresented: $showButtonStyleSheet) {
            ButtonStyleShowcase()
                .environmentObject(themeAccent)
        }
        .background(
            Group {
                NavigationLink(
                    destination: SettingsFilesWrapper(disableImagePreviews: $disableImagePreviews),
                    isActive: $showFilesSettings,
                    label: { EmptyView() }
                )
                NavigationLink(
                    destination: SettingsBrowseWrapper(
                        hideAppDescriptions: $hideAppDescriptions,
                        hideRepositoryAppCounts: $hideRepositoryAppCounts,
                        hideRepositorySectionCounts: $hideRepositorySectionCounts,
                        hideClockIcon: $hideClockIcon,
                        disableTintColorExtraction: $disableTintColorExtraction,
                        disableAppIconFallbacks: $disableAppIconFallbacks,
                        useFullYearFormat: $useFullYearFormat
                    ),
                    isActive: $showBrowseSettings,
                    label: { EmptyView() }
                )
                NavigationLink(
                    destination: CacheSettingsView(
                        cacheManager: cacheManager,
                        cacheStatistics: $cacheStatistics,
                        isLoadingCacheStats: $isLoadingCacheStats,
                        showClearCacheConfirmation: $showClearCacheConfirmation
                    ),
                    isActive: $showCacheSettings,
                    label: { EmptyView() }
                )
                NavigationLink(
                    destination: ThemingSettingsView(
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
                    ),
                    isActive: $showThemingSettings,
                    label: { EmptyView() }
                )
            }
        )
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllCache()
            }
        } message: {
            Text("This will clear all cached repository data and recently updated apps. The cache will be rebuilt when you next refresh repositories.")
        }
        .onAppear {
            refreshCacheStatistics()
        }
    }
    
    private func refreshCacheStatistics() {
        isLoadingCacheStats = true
        
        Task {
            let stats = cacheManager.getCacheStatistics()
            
            await MainActor.run {
                cacheStatistics = stats
                isLoadingCacheStats = false
                ToastManager.shared.showToast.log("Refreshed cache statistics: \(stats.formattedSize), \(stats.fileCount) files")
            }
        }
    }
    
    private func refreshRepositoryCache() {
        Task {
            // Force refresh repositories which will regenerate cache
            await RepositoryViewModel.shared.fetchRepositories()
            
            await MainActor.run {
                ToastManager.shared.showToast.success("Repository cache refreshed")
                refreshCacheStatistics()
            }
        }
    }
    
    private func clearAllCache() {
        Task {
            await MainActor.run {
                cacheManager.clearCache()
                ToastManager.shared.showToast.success("All cache cleared")
                refreshCacheStatistics()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func colorFromData(_ data: Data) -> Color {
        if let components = try? JSONDecoder().decode([CGFloat].self, from: data),
           components.count >= 4
        {
            return Color(.sRGB,
                         red: Double(components[0]),
                         green: Double(components[1]),
                         blue: Double(components[2]),
                         opacity: Double(components[3]))
        }
        return .white
    }
    
    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
    
    private func deviceTypeString() -> String {
        switch getDeviceType() {
        case .iPhoneHomeButton:
            return "iPhone (Home Button)"
        case .iPhoneNotch:
            return "iPhone (Notch)"
        case .iPhoneDynamicIsland:
            return "iPhone (Dynamic Island)"
        case .iPadHomeButton:
            return "iPad (Home Button)"
        case .iPadNoHomeButton:
            return "iPad (No Home Button)"
        case .unknown:
            return "Unknown Device"
        }
    }
}
