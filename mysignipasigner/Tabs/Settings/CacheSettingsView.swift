import SwiftUI

struct CacheSettingsView: View {
    @EnvironmentObject var themeAccent: Theme
    @ObservedObject var cacheManager: RepositoryCacheManager
    @Binding var cacheStatistics: CacheStatistics
    @Binding var isLoadingCacheStats: Bool
    @Binding var showClearCacheConfirmation: Bool
    @State private var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Cache Size")
                                .withIcon("arrow.down.document.fill")
                                .withValue(isLoadingCacheStats ? "Loading..." : cacheStatistics.formattedSize)
                            
                            ConnectedUniversalLabel("Cache Files")
                                .withIcon("document")
                                .withValue("\(cacheStatistics.fileCount)")
                            
                            ConnectedUniversalLabel("Last Updated")
                                .withIcon("clock.arrow.circlepath")
                                .withValue(formatDate(cacheStatistics.lastUpdated))
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)

                        MainButtonView("Refresh Cache Statistics", icon: "chart.bar.horizontal.page") {
                            ToastManager.shared.showToast.log("Clicked Refresh Cache Statistics")
                            refreshCacheStatistics()
                        }
                        .padding(.horizontal)
                        .disabled(isLoadingCacheStats)
                        
                        MainButtonView("Refresh Repository Cache", icon: "shippingbox") {
                            ToastManager.shared.showToast.log("Clicked Refresh Repository Cache")
                            refreshRepositoryCache()
                        }
                        .padding(.horizontal)
                        
                        MainButtonView("Clear All Cache", icon: "windshield.front.and.wiper") {
                            ToastManager.shared.showToast.log("Clicked Clear All Cache")
                            showClearCacheConfirmation = true
                        }
                        .padding(.horizontal)
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
            
            NavigationManager.customNavigation(
                title: "",
                leadingItems: [
                    NavigationItem(icon: "chevron.left", name: "Back", action: {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Clicked Back (navigation) in Cache Management")
                        // Navigate back
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let navigationController = window.rootViewController as? UINavigationController ??
                           window.rootViewController?.children.first as? UINavigationController {
                            navigationController.popViewController(animated: true)
                        }
                    })
                ]
            ) {
                HStack(spacing: 8) {
                    Text("Cache Management")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .environmentObject(themeAccent)
            .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .navigationBarHidden(true)
        .onAppear {
            ToastManager.shared.showToast.log("Opened Cache Management")
            
            // Re-enable the interactive pop gesture
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController as? UINavigationController ??
               window.rootViewController?.children.first as? UINavigationController {
                self.originalPopGestureDelegate = navigationController.interactivePopGestureRecognizer?.delegate
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
        }
        .onDisappear {
            // Restore the original pop gesture delegate
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController as? UINavigationController ??
               window.rootViewController?.children.first as? UINavigationController {
                navigationController.interactivePopGestureRecognizer?.delegate = self.originalPopGestureDelegate
            }
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllCache()
            }
        } message: {
            Text("This will clear all cached repository data and recently updated apps. The cache will be rebuilt when you next refresh repositories.")
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
}
