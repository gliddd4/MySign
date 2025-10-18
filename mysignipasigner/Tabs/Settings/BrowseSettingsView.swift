import SwiftUI

struct BrowseSettingsView: View {
    @EnvironmentObject var themeAccent: Theme
    @Binding var hideAppDescriptions: Bool
    @Binding var hideRepositoryAppCounts: Bool
    @Binding var hideRepositorySectionCounts: Bool
    @Binding var hideClockIcon: Bool
    @Binding var disableTintColorExtraction: Bool
    @Binding var disableAppIconFallbacks: Bool
    @Binding var useFullYearFormat: Bool
    @State private var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Hide app descriptions")
                                .withIcon("text.below.photo")
                                .withDescription("Hides the descriptions under an app's icon")
                                .withToggle($hideAppDescriptions)
                            
                            ConnectedUniversalLabel("Hide total app count")
                                .withIcon("number")
                                .withDescription("Hides the total number of apps to the right of a repository name")
                                .withToggle($hideRepositoryAppCounts)
                            
                            ConnectedUniversalLabel("Hide total repo count")
                                .withIcon("number")
                                .withDescription("Hides the total number of repositories at the top of the Browse tab")
                                .withToggle($hideRepositorySectionCounts)
                            
                            ConnectedUniversalLabel("Hide time icon")
                                .withIcon("clock.arrow.circlepath")
                                .withDescription("Hides the time icon to the right of an app's release date")
                                .withToggle($hideClockIcon)
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Disable tintColor fallback")
                                .withIcon("chevron.right")
                                .withDescription("Disables repository color generation for repositories that don't have a tintColor value")
                                .withToggle($disableTintColorExtraction)
                            
                            ConnectedUniversalLabel("Disable iconURL fallback")
                                .withIcon("photo")
                                .withDescription("Disables fetching the first app's iconURL if the repository doesn't include an iconURL value or has an iconURL value that doesn't link to an image")
                                .withToggle(Binding(
                                    get: { disableAppIconFallbacks },
                                    set: { newValue in
                                        disableAppIconFallbacks = newValue
                                        HapticManager.shared.medium()
                                        ToastManager.shared.showToast.log("Toggled Disable App Icon Fallbacks to \(newValue)")
                                        
                                        if newValue {
                                            Task {
                                                await RepositoryViewModel.shared.clearFallbackIconsIfDisabled()
                                                ToastManager.shared.showToast.success("Cleared fallback icons")
                                            }
                                        }
                                    }
                                ))
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Use 1 year instead of 1yr")
                                .withIcon("calendar")
                                .withDescription("Shows full year format for an app's release date")
                                .withToggle($useFullYearFormat)
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
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
                        ToastManager.shared.showToast.log("Clicked Back (navigation) in Browse Settings")
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
                    Text("Browse")
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
            ToastManager.shared.showToast.log("Opened Browse Settings")
            
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
    }
}
