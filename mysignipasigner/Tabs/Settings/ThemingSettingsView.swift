import SwiftUI

struct ThemingSettingsView: View {
    @EnvironmentObject var themeAccent: Theme
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
    @State private var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ConnectedLabelGroup {
                            HStack {
                                Image(systemName: "paintbrush")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 20)
                                
                                Text("Accent Color")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                ColorPicker("", selection: accentColorBinding)
                                    .labelsHidden()
                                    .frame(width: 30, height: 30)
                            }
                            .padding(.horizontal)
                            .frame(height: 36)
                            .connectedLabelItem()

                            ConnectedUniversalLabel("Default Tab")
                                .withIcon("dock.arrow.down.rectangle")
                                .withButton(UniversalButton.ButtonContent.text(tabOptions[tabSelectionManager.defaultTab].name), action: {
                                    HapticManager.shared.medium()
                                    showDefaultTabDialog = true
                                    selectedTabOption = tabOptions.first(where: { $0.id == tabSelectionManager.defaultTab })
                                })
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Hide Tab Bar Blur")
                                .withIcon("menubar.rectangle")
                                .withDescription("Removes the blur effect from the tab bar background")
                                .withToggle($hideTabBarBlur)

                            ConnectedUniversalLabel("Hide Navigation Bar Blur")
                                .withIcon("dock.rectangle")
                                .withDescription("Removes the blur effect from the navigation bar background")
                                .withToggle($hideNavigationBarBlur)

                            ConnectedUniversalLabel("Enable Wide Toggles")
                                .withIcon("switch.2")
                                .withDescription("Makes toggle switches wider and more prominent")
                                .withToggle(enableWideTogglesBinding)

                            ConnectedUniversalLabel("Enable Wallpaper")
                                .withIcon("iphone")
                                .withDescription("Enables custom wallpaper backgrounds throughout the app")
                                .withToggle(wallpaperBinding)
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)

                        if wallpaperManager.isWallpaperEnabled {
                            WallpaperSectionView(
                                wallpaperManager: wallpaperManager,
                                accentColor: themeAccent.accentColor
                            )
                        }
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Current Device")
                                .withIcon("iphone")
                                .withValue(getDeviceModel())

                            ConnectedUniversalLabel("Device Type")
                                .withIcon("iphone")
                                .withValue(deviceTypeString())
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Colorful Clock")
                                .withIcon("clock")
                                .withDescription("Replaces the system status bar with a custom colorful clock")
                                .withToggle(colorfulClockBinding)
                                .disabledLabelStyle(hasHomeButton())
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Hide AM/PM")
                                .withIcon("sun.haze")
                                .withDescription("Hides the AM/PM indicator from the colorful clock")
                                .withToggle(hideAMPMBinding)
                                .disabledLabelStyle(!statusBarManager.colorfulClock || hasHomeButton())

                            ConnectedUniversalLabel("Show 24-Hour Time")
                                .withIcon("24.square")
                                .withDescription("Displays time in 24-hour format instead of 12-hour")
                                .withToggle(show24HourBinding)
                                .disabledLabelStyle(!statusBarManager.colorfulClock || hasHomeButton())
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        ConnectedLabelGroup {
                            ConnectedUniversalLabel("Hide in landscape")
                                .withIcon("eye.slash")
                                .withDescription("Hides the dock when the device is in landscape orientation")
                                .withToggle($hideInLandscape)

                            ConnectedUniversalLabel("Use Accent Color")
                                .withIcon("dock.rectangle")
                                .withDescription("Uses the app's accent color for the dock background")
                                .withToggle($useAccentDockColor)
                                .lastConnectedItem()
                        }
                        .environmentObject(themeAccent)
                        .padding(.horizontal)
                        
                        if !useAccentDockColor {
                            ConnectedLabelGroup {
                                HStack {
                                    Image(systemName: "paintbrush")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 20)
                                    
                                    Text("Custom Dock Color")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    ColorPicker("", selection: Binding(
                                        get: { colorFromData(unifiedDockData) },
                                        set: { newColor in
                                            HapticManager.shared.medium()
                                            if let data = try? JSONEncoder().encode(UIColor(newColor).cgColor.components) {
                                                unifiedDockData = data
                                                ToastManager.shared.showToast.log("Changed Custom Dock Color")
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 30, height: 30)
                                }
                                .padding(.horizontal)
                                .frame(height: 36)
                                .connectedLabelItem()
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
            
            NavigationManager.customNavigation(
                title: "",
                leadingItems: [
                    NavigationItem(icon: "chevron.left", name: "Back", action: {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Clicked Back (navigation) in Theming")
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
                    Text("Theming")
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
            ToastManager.shared.showToast.log("Opened Theming Settings")
            
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
        .confirmationDialog("Select Default Tab",
                            isPresented: $showDefaultTabDialog,
                            titleVisibility: .visible) {
            ForEach(tabOptions) { option in
                Button(option.name) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                        if option.id != tabSelectionManager.defaultTab {
                            HapticManager.shared.medium()
                            selectedTabOption = option
                            tabSelectionManager.setDefaultTab(option.id)
                            ToastManager.shared.showToast.log("Changed Default Tab to \(option.name)")
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                showDefaultTabDialog = false
            }
        }
    }
    
    // Helper functions for status bar
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
    
    // Helper function for dock
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
    
    // Computed properties to help the compiler
    private var accentColorBinding: Binding<Color> {
        Binding(
            get: { themeAccent.accentColor },
            set: { newValue in
                themeAccent.accentColor = newValue
                HapticManager.shared.medium()
                let hexColor = UIColor(newValue).toHexString()
                ToastManager.shared.showToast.log("Changed Accent Color to \(hexColor)")
            }
        )
    }
    
    private var wallpaperBinding: Binding<Bool> {
        Binding(
            get: { wallpaperManager.isWallpaperEnabled },
            set: { _ in
                HapticManager.shared.medium()
                wallpaperManager.toggleWallpaper()
            }
        )
    }
    
    private var enableWideTogglesBinding: Binding<Bool> {
        Binding(
            get: { themeAccent.enableWideToggles },
            set: { newValue in
                themeAccent.enableWideToggles = newValue
                HapticManager.shared.medium()
                ToastManager.shared.showToast.log("Toggled Enable Wide Toggles \(newValue ? "on" : "off")")
            }
        )
    }
    
    private var colorfulClockBinding: Binding<Bool> {
        Binding(
            get: { statusBarManager.colorfulClock },
            set: { newValue in
                statusBarManager.colorfulClock = newValue
                let statusText = newValue ? "Enabled colorful clock and hid system status bar" : "Disabled colorful clock and showed system status bar"
                ToastManager.shared.showToast.log(statusText)
            }
        )
    }
    
    private var hideAMPMBinding: Binding<Bool> {
        Binding(
            get: { statusBarManager.hideAMPM },
            set: { newValue in
                statusBarManager.hideAMPM = newValue
                ToastManager.shared.showToast.log("Toggled Hide AM/PM \(newValue ? "on" : "off")")
            }
        )
    }
    
    private var show24HourBinding: Binding<Bool> {
        Binding(
            get: { statusBarManager.show24HourTime },
            set: { newValue in
                statusBarManager.show24HourTime = newValue
                ToastManager.shared.showToast.log("Toggled Show 24-Hour Time \(newValue ? "on" : "off")")
            }
        )
    }
}
