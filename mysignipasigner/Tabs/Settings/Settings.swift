//
//  DefaultSettings.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Foundation
import Combine

struct DefaultSettings {
    private static let defaultColorHex = "00C466"
    private static let defaultTabIndex = 2
    
    static func initialize() {
        if !UserDefaults.standard.bool(forKey: "hasInitializedSettings") {
            setDefaultValues()
            UserDefaults.standard.set(true, forKey: "hasInitializedSettings")
            UserDefaults.standard.synchronize()
        }
    }
    
    static func resetToDefaults() {
        setDefaultValues()
        UserDefaults.standard.synchronize()
    }
    
    private static func setDefaultValues() {
        // Theming settings
        setDefaultAccentColor()
        setDefaultDockColor()
        
        // Tab settings
        UserDefaults.standard.set(defaultTabIndex, forKey: "tab_default")
        UserDefaults.standard.set(defaultTabIndex, forKey: "tab_selected")
        
        // Status Bar settings
        UserDefaults.standard.set(true, forKey: "statusBar_colorfulClock")
        UserDefaults.standard.set(true, forKey: "statusBar_hideAMPM")
        UserDefaults.standard.set(false, forKey: "statusBar_show24HourTime")
        
        // Dock settings
        UserDefaults.standard.set(true, forKey: "dock_hideInLandscape")
        UserDefaults.standard.set(true, forKey: "dock_hideWithKeyboard")
        UserDefaults.standard.set(true, forKey: "dock_useAccentColor")
        UserDefaults.standard.set(false, forKey: "dock_useCustomColor")
    }
    
    private static func setDefaultAccentColor() {
        if UserDefaults.standard.data(forKey: "accentColor") == nil {
            let defaultColor = UIColor(Color(hex: defaultColorHex))
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: defaultColor, requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "accentColor")
            }
        }
    }
    
    private static func setDefaultDockColor() {
        let defaultColor = UIColor(Color(hex: defaultColorHex))
        if let components = defaultColor.cgColor.components,
           let data = try? JSONEncoder().encode(components) {
            UserDefaults.standard.set(data, forKey: "dock_unifiedColor")
        }
    }
}

struct SettingsConstants {
    // Color Constants
    static let defaultColors: [(name: String, hex: String, color: Color)] = [
        ("Green", "#02c466", Color(hex: "02c466")),
        ("Blue", "#0884ff", Color(hex: "0884ff")),
        ("Red", "#ff443a", Color(hex: "ff443a")),
        ("Yellow", "#ffd60a", Color(hex: "ffd60a"))
    ]
    
    // UserDefaults Keys
    enum UserDefaultsKeys {
        static let accentColor = "accentColor"
        static let defaultTab = "tab_default"
        static let selectedTab = "tab_selected"
        static let statusBarColorful = "statusBar_colorfulClock"
        static let statusBarHideAMPM = "statusBar_hideAMPM"
        static let statusBar24Hour = "statusBar_show24HourTime"
        static let dockHideInLandscape = "dock_hideInLandscape"
        static let dockHideWithKeyboard = "dock_hideWithKeyboard"
        static let dockUseAccentColor = "dock_useAccentColor"
        static let dockUseCustomColor = "dock_useCustomColor"
        static let dockUnifiedColor = "dock_unifiedColor"
        static let hideAppDescriptions = "app_hideDescriptions"
        static let hasInitializedSettings = "hasInitializedSettings"
    }
    
    // UI Constants
    enum UI {
        static let cardCornerRadius: CGFloat = 12
        static let rowSpacing: CGFloat = 16
        static let colorCircleSize: CGFloat = 28
        static let toggleSize = CGSize(width: 51, height: 31)
        static let animationDuration: Double = 0.2
    }
    
    // URLs
    enum URLs {
        static let discordServer = "https://discord.gg/hUK5m9MGFc"
        static let circlefy = "https://github.com/AppInstalleriOSGH/Circlefy"
        static let arkSigning = "https://github.com/nabzclan-reborn/ArkSigning"
        static let eSignRepo = "https://github.com/khcrysalis/Feather/blob/main/AtlSourceKit/Sources/AtlSourceKit/Utilities/Key/EsignSourceKey.swift"
        static let santander = "https://github.com/NSAntoine/Santander"
    }
}

@MainActor
class SettingsStore: ObservableObject {
    // Published Properties
    @Published var localAccentColor: Color = .blue
    @Published var showColorOptions = false
    @Published var hexInput: String = ""
    @Published var localDockColor = Color.white
    @Published var showDefaultTabDialog = false
    @Published var selectedTabOption: SettingsView.TabOption?
    @Published var toastMessage = ""
    @Published var showLogsSheet = false
    @Published var showFontStylesPopover = false
    
    // AppStorage Properties
    @AppStorage(SettingsConstants.UserDefaultsKeys.hideAppDescriptions)
    var hideAppDescriptions = false
    
    @AppStorage(SettingsConstants.UserDefaultsKeys.dockHideInLandscape)
    var hideInLandscape = true
    
    @AppStorage(SettingsConstants.UserDefaultsKeys.dockHideWithKeyboard)
    var hideWithKeyboard = true
    
    @AppStorage(SettingsConstants.UserDefaultsKeys.dockUseAccentColor)
    var useAccentDockColor = true
    
    @AppStorage(SettingsConstants.UserDefaultsKeys.dockUseCustomColor)
    var useUnifiedDockColor = false
    
    @AppStorage(SettingsConstants.UserDefaultsKeys.dockUnifiedColor)
    var unifiedDockData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    
    // Methods
    func initializeColors(themeAccent: Theme) {
        localAccentColor = themeAccent.accentColor
        hexInput = localAccentColor.toHex() ?? "#0884ff"
        localDockColor = colorFromData(unifiedDockData)
    }
    
    func applyHexColor(themeAccent: Theme) -> Bool {
        if let color = Color(hexOptional: hexInput) {
            localAccentColor = color
            themeAccent.accentColor = color
            return true
        }
        return false
    }
    
    func colorFromData(_ data: Data) -> Color {
        if let components = try? JSONDecoder().decode([CGFloat].self, from: data),
           components.count >= 4 {
            return Color(.sRGB,
                        red: Double(components[0]),
                        green: Double(components[1]),
                        blue: Double(components[2]),
                        opacity: Double(components[3]))
        }
        return .white
    }
    
    func saveDockColor() {
        if let data = try? JSONEncoder().encode(UIColor(localDockColor).cgColor.components) {
            unifiedDockData = data
        }
    }
    
    func sendToast() {
        let trimmedMessage = toastMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Clicked Send Toast and sent \(trimmedMessage)")
        ToastManager.shared.showToast.warning(trimmedMessage)
    }
}

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format: "#%06x", rgb)
    }

    private func adjust(by amount: CGFloat) -> UIColor {
        var r: CGFloat = .zero, g: CGFloat = .zero, b: CGFloat = .zero, a: CGFloat = .zero
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        return UIColor(red: max(min(r + amount, 1), 0),
                       green: max(min(g + amount, 1), 0),
                       blue: max(min(b + amount, 1), 0),
                       alpha: a)
    }
    
    func lighter(by amount: CGFloat = 0.2) -> UIColor {
        adjust(by: abs(amount))
    }
    
    func darker(by amount: CGFloat = 0.2) -> UIColor {
        adjust(by: -abs(amount))
    }
}
