import SwiftUI

struct PaddingSettingsView: View {
    @EnvironmentObject var themeAccent: Theme
    @ObservedObject private var paddingManager = PaddingManager.shared
    
    @State private var showPaddingImportDialog = false
    @State private var paddingImportText = ""
    @State private var showDeviceTypeOverrideDialog = false
    @State private var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        deviceInfoSection
                        paddingControlsSection
                        automaticPositioningSection
                        actionButtonsSection
                        resetButtonSection
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
            
            navigationBar
                .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .navigationBarHidden(true)
        .onAppear {
            ToastManager.shared.showToast.log("Opened Padding Settings")
            setupPopGesture()
        }
        .onDisappear {
            restorePopGesture()
        }
        .confirmationDialog("Select Device Type Override",
                          isPresented: $showDeviceTypeOverrideDialog,
                          titleVisibility: .visible) {
            deviceTypeOverrideButtons
        }
        .alert("Import Padding Values", isPresented: $showPaddingImportDialog) {
            importPaddingAlert
        } message: {
            Text("Paste the copied padding values to import them. Format: clockX:X,clockY:X,scale:X.X")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var deviceInfoSection: some View {
        ConnectedLabelGroup {
            ConnectedUniversalLabel("Current Device")
                .withIcon("iphone")
                .withValue(getDeviceModel())
            
            ConnectedUniversalLabel("Actual Device Type")
                .withIcon("iphone")
                .withValue(getActualDeviceType().displayName)
            
            ConnectedUniversalLabel("Override Device Type")
                .withIcon("iphone")
                .withButton(UniversalButton.ButtonContent.text(
                    getDeviceTypeOverride()?.displayName ?? "Automatic"
                ), action: {
                    HapticManager.shared.medium()
                    showDeviceTypeOverrideDialog = true
                })
            
            ConnectedUniversalLabel("Effective Device Type")
                .withIcon("iphone")
                .withValue(deviceTypeString())
                .lastConnectedItem()
        }
        .environmentObject(themeAccent)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var paddingControlsSection: some View {
        ConnectedLabelGroup {
            PaddingControlView(
                title: "Clock X Position",
                currentValue: paddingManager.clockXPadding,
                range: -20...500,
                onValueChange: { newValue in
                    paddingManager.updateClockXPadding(newValue)
                },
                accentColor: themeAccent.accentColor,
                defaultValue: getDefaultClockXPadding()
            )
            .connectedLabelItem()

            PaddingControlView(
                title: "Clock Y Position",
                currentValue: paddingManager.clockYPadding,
                range: -20...200,
                onValueChange: { newValue in
                    paddingManager.updateClockYPadding(newValue)
                },
                accentColor: themeAccent.accentColor,
                defaultValue: getDefaultClockYPadding()
            )
            .connectedLabelItem()

            ScaleControlView(
                title: "Clock Scale",
                currentValue: paddingManager.clockScale,
                range: 0.5...3.0,
                onValueChange: { newValue in
                    paddingManager.updateClockScale(newValue)
                },
                accentColor: themeAccent.accentColor,
                defaultValue: getDefaultClockScale()
            )
            .connectedLabelItem()
        }
        .environmentObject(themeAccent)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var automaticPositioningSection: some View {
        ConnectedLabelGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text("Navigation & Dock Positioning")
                .foregroundColor(.gray)
                .font(.caption)
                
                Text("Now uses device safe areas automatically")
                    .foregroundColor(.green)
                    .font(.caption2)
                    .italic()
                
                HStack {
                    Text("Top Safe Area:")
                        .foregroundColor(.white)
                    Spacer()
                    Text("Auto")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                HStack {
                    Text("Bottom Safe Area:")
                        .foregroundColor(.white)
                    Spacer()
                    Text("Auto")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .connectedLabelItem()
        }
        .environmentObject(themeAccent)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("Copy Values") {
                HapticManager.shared.medium()
                copyPaddingValues()
                ToastManager.shared.showToast.log("Copied clock positioning values to clipboard")
            }
            .foregroundColor(themeAccent.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(themeAccent.accentColor.opacity(0.1))
            .cornerRadius(8)
            
            Button("Import Values") {
                HapticManager.shared.medium()
                showPaddingImportDialog = true
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var resetButtonSection: some View {
        Button("Reset All to Defaults") {
            let deviceModel = getDeviceModel()
            UserDefaults.standard.removeObject(forKey: "clock_xPadding_\(deviceModel)")
            UserDefaults.standard.removeObject(forKey: "clock_yPadding_\(deviceModel)")
            UserDefaults.standard.removeObject(forKey: "clock_scale_\(deviceModel)")
            paddingManager.refreshValues()
            ToastManager.shared.showToast.log("Reset clock positioning to defaults")
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var navigationBar: some View {
        NavigationManager.customNavigation(
            title: "",
            leadingItems: [
                NavigationItem(icon: "chevron.left", name: "Back", action: {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Back (navigation) in Padding Settings")
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
                Text("Padding Settings")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .environmentObject(themeAccent)
        .zIndex(1)
    }
    
    @ViewBuilder
    private var deviceTypeOverrideButtons: some View {
        Button("Automatic (Recommended)") {
            setDeviceTypeOverride(nil)
            paddingManager.refreshValues()
            ToastManager.shared.showToast.log("Set device type to automatic")
        }
        
        ForEach(DeviceType.allCases, id: \.self) { deviceType in
            Button(deviceType.displayName) {
                setDeviceTypeOverride(deviceType)
                paddingManager.refreshValues()
                ToastManager.shared.showToast.log("Overrode device type to \(deviceType.displayName)")
            }
        }
        
        Button("Cancel", role: .cancel) {
            showDeviceTypeOverrideDialog = false
        }
    }
    
    @ViewBuilder
    private var importPaddingAlert: some View {
        TextField("Paste values here", text: $paddingImportText)
        Button("Import") {
            importPaddingValues(paddingImportText)
        }
        Button("Cancel", role: .cancel) {
            paddingImportText = ""
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupPopGesture() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController as? UINavigationController ??
           window.rootViewController?.children.first as? UINavigationController {
            self.originalPopGestureDelegate = navigationController.interactivePopGestureRecognizer?.delegate
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
    
    private func restorePopGesture() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController as? UINavigationController ??
           window.rootViewController?.children.first as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.delegate = self.originalPopGestureDelegate
        }
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
    
    private func copyPaddingValues() {
        let paddingManager = self.paddingManager
        let values = "clockX:\(Int(paddingManager.clockXPadding)),clockY:\(Int(paddingManager.clockYPadding)),scale:\(String(format: "%.1f", paddingManager.clockScale))"
        
        UIPasteboard.general.string = values
        ToastManager.shared.showToast.success("Copied: \(values)")
    }
    
    private func importPaddingValues(_ importString: String) {
        let components = importString.components(separatedBy: ",")
        var imported = false
        
        for component in components {
            let parts = component.components(separatedBy: ":")
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let valueString = parts[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "clockX":
                if let value = Double(valueString) {
                    paddingManager.updateClockXPadding(value)
                    imported = true
                }
            case "clockY":
                if let value = Double(valueString) {
                    paddingManager.updateClockYPadding(value)
                    imported = true
                }
            case "scale":
                if let value = Double(valueString) {
                    paddingManager.updateClockScale(value)
                    imported = true
                }
            default:
                continue
            }
        }
        
        if imported {
            ToastManager.shared.showToast.success("Successfully imported clock positioning values")
            ToastManager.shared.showToast.log("Imported clock positioning values: \(importString)")
        } else {
            ToastManager.shared.showToast.error("Failed to import - check format")
        }
        
        paddingImportText = ""
    }
    
    func getDefaultClockXPadding() -> Double {
        return Double(ClockPadding.xPadding())
    }
    
    func getDefaultClockYPadding() -> Double {
        return Double(ClockPadding.yPadding())
    }
    
    func getDefaultClockScale() -> Double {
        return Double(ClockScale.scale())
    }
}
