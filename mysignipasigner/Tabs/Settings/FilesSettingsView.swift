import SwiftUI

struct FilesSettingsView: View {
    @EnvironmentObject var themeAccent: Theme
    @Binding var disableImagePreviews: Bool
    @AppStorage("ui_verticalTabBarBlur") private var verticalTabBarBlur: Double = 1.0
    @State private var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ConnectedLabelGroup {
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "slider.horizontal.3")
                                                .foregroundColor(themeAccent.accentColor)
                                                .frame(width: 24)
                                            
                                            Text("Vertical Tab Bar Blur")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .medium))
                                        }
                                        
                                        Text("Controls the gaussian blur behind the vertical tab bar")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                            .padding(.leading, 32)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1f", verticalTabBarBlur))
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(minWidth: 30)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                Slider(
                                    value: $verticalTabBarBlur,
                                    in: 0...10,
                                    step: 0.1
                                ) {
                                    Text("Blur Amount")
                                }
                                .accentColor(themeAccent.accentColor)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                            .background(Color(red: 28/255, green: 28/255, blue: 30/255))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Disable image previews")
                                .withIcon("folder")
                                .withDescription("Disables preview thumbnails for image files")
                                .withToggle($disableImagePreviews)
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
                        ToastManager.shared.showToast.log("Clicked Back (navigation) in Files Settings")
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
                    Text("Files")
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
            ToastManager.shared.showToast.log("Opened Files Settings")
            
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
