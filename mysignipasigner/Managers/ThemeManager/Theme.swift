import Combine
import SwiftUI
import UIKit

@MainActor
public class Theme: ObservableObject {
    public static let shared = Theme()

    // MARK: - Public Properties

    @Published public var accentColor: Color = .blue {
        didSet {
            saveAccentColor()
        }
    }

    @Published public var labelBackgroundColor: Color = Color(red: 45/255, green: 45/255, blue: 45/255)
    @Published public var labelOutlineColor: Color = Color(red: 60/255, green: 60/255, blue: 60/255)

    @Published public var isTransitioning: Bool = false
    @Published public var transitionBlurRadius: CGFloat = 0
    
    @Published public var enableWideToggles: Bool = false {
        didSet {
            UserDefaults.standard.set(enableWideToggles, forKey: "ui_enableWideToggles")
        }
    }

    public var accentUIColor: UIColor {
        UIColor(accentColor)
    }

    private var transitionTimer: Timer?

    // MARK: - Public Methods
    public init() {
        // Initialize default settings
        DefaultSettings.initialize()
        
        if UserDefaults.standard.data(forKey: "accentColor") == nil {
            accentColor = Color(hex: "00C466")
            saveAccentColor()
        } else {
            loadAccentColor()
        }
        
        // Load enableWideToggles setting
        enableWideToggles = UserDefaults.standard.bool(forKey: "ui_enableWideToggles")

        if !UserDefaults.standard.bool(forKey: "hasInitializedDockColor") {
            UserDefaults.standard.set(true, forKey: "dock_useAccentColor")
            UserDefaults.standard.set(false, forKey: "useUnifiedDockColor")
            UserDefaults.standard.set(true, forKey: "hasInitializedDockColor")
            UserDefaults.standard.synchronize()
        }
    }

    public func showToast(_ message: String, isError: Bool = false) {
        if isError {
            ToastManager.shared.showToast.error(message)
        } else {
            ToastManager.shared.showToast.success(message)
        }
    }
    
    public func showExtendedToast(_ message: String, isError: Bool = false, duration: TimeInterval = 8.0) {
        if isError {
            ToastManager.shared.showExtendedToast(message, type: .error, duration: duration)
        } else {
            ToastManager.shared.showExtendedToast(message, type: .success, duration: duration)
        }
    }

    public func performTabTransition() {
        isTransitioning = true
        transitionBlurRadius = 10

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            withAnimation(.easeOut(duration: 0.1)) {
                self?.transitionBlurRadius = 0
                self?.isTransitioning = false
            }
        }
    }

    // MARK: - Private Methods
    private func saveAccentColor() {
        let uiColor = accentUIColor
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "accentColor")
        }
    }

    private func loadAccentColor() {
        if let data = UserDefaults.standard.data(forKey: "accentColor"),
           let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
        {
            accentColor = Color(uiColor)
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}