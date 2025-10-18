//
//  ThemeColor.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit

// MARK: - Color Extensions extension color init hex to hex
public extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
    
    init?(hexOptional: String) {
        let hex = hexOptional.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        // Validate hex string length (should be 3 or 6 characters)
        guard hex.count == 3 || hex.count == 6 else { return nil }
        
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let r, g, b: Double
        if hex.count == 3 {
            // Handle 3-character hex (e.g., "F0A" -> "FF00AA")
            r = Double((int >> 8) & 0xF) / 15.0
            g = Double((int >> 4) & 0xF) / 15.0
            b = Double(int & 0xF) / 15.0
        } else {
            // Handle 6-character hex
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
    
    func toHex() -> String? {
        return self.uiColor.toHexString()
    }
    
    // MARK: - Color Manipulation for FluidGradient
    func lighter(by percentage: Double = 0.3) -> Color {
        let uiColor = self.uiColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = min(brightness + CGFloat(percentage), 1.0)
        let newSaturation = max(saturation - CGFloat(percentage * 0.3), 0.0)
        
        return Color(UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha))
    }
    
    func darker(by percentage: Double = 0.4) -> Color {
        let uiColor = self.uiColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = max(brightness - CGFloat(percentage), 0.0)
        let newSaturation = min(saturation + CGFloat(percentage * 0.2), 1.0)
        
        return Color(UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha))
    }
    
    func withOpacity(_ opacity: Double) -> Color {
        return self.opacity(opacity)
    }
}

extension UserDefaults {
    func color(forKey key: String) -> UIColor? {
        guard let colorData = data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)
        } catch {
            Task { @MainActor in
                ToastManager.shared.showToast.error("Error retrieving color: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    func set(_ color: UIColor?, forKey key: String) {
        guard let color = color else { return }
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
            set(colorData, forKey: key)
        } catch {
            Task { @MainActor in
                ToastManager.shared.showToast.error("Error saving color: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - View Extension for Color Conversion
extension View {
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
    
    var signColorDefaultData: Data {
        (try? JSONEncoder().encode(UIColor.white.cgColor.components)) ?? Data()
    }
}