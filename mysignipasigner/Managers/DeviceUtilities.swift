//
//  DeviceUtilities.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

/// A cached value for the device model identifier, to avoid repeated computation.
private let deviceModelIdentifier: String = {
    #if targetEnvironment(simulator)
    // In the Simulator, uname just returns "x86_64", "arm64", etc.
    // Apple exposes the real model identifier through an env-var.
    if let simIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
        return simIdentifier         // e.g. "iPhone12,8"
    }
    #endif

    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier               // e.g. "iPhone12,8" on real hardware
}()

class DeviceViewModel: ObservableObject {
    @Published var deviceModel: String?

    init() {
        fetchDeviceModel()
    }

    func fetchDeviceModel() {
        deviceModel = getDeviceModel()
    }
}

func getDeviceModel() -> String {
    return deviceModelIdentifier
}

func hasHomeButton() -> Bool {
    let deviceModel = getDeviceModel()
    
    // Home-button devices that support iOS 15+
    let homeButtonDevices: Set<String> = [
        // iPhone (iOS 15+ compatible)
        "iPhone10,4", "iPhone10,5",  // iPhone 8/8 Plus
        "iPhone12,8",                // iPhone SE 2
        "iPhone14,6",                // iPhone SE 3

        // iPad (iOS 15+ compatible)
        "iPad7,11", "iPad7,12",      // iPad 7th gen
        "iPad11,6", "iPad11,7",      // iPad 8th gen
        "iPad12,1", "iPad12,2",      // iPad 9th gen
        "iPad13,18", "iPad13,19",    // iPad 10th gen

        // iPod (iOS 15+ compatible)
        "iPod9,1"                    // iPod touch 7th gen
    ]

    return homeButtonDevices.contains(deviceModel)
}

func hasNotch() -> Bool {
    let deviceModel = getDeviceModel()
    
    // iPhone devices with notch
    let notchDevices: Set<String> = [
        "iPhone10,3", "iPhone10,6",  // iPhone X
        "iPhone11,2",                // iPhone XS
        "iPhone11,4", "iPhone11,6",  // iPhone XS Max
        "iPhone11,8",                // iPhone XR
        "iPhone12,1",                // iPhone 11
        "iPhone12,3",                // iPhone 11 Pro
        "iPhone12,5",                // iPhone 11 Pro Max
        "iPhone13,1",                // iPhone 12 mini
        "iPhone13,2",                // iPhone 12
        "iPhone13,3",                // iPhone 12 Pro
        "iPhone13,4",                // iPhone 12 Pro Max
        "iPhone14,4",                // iPhone 13 mini
        "iPhone14,5",                // iPhone 13
        "iPhone14,2",                // iPhone 13 Pro
        "iPhone14,3",                // iPhone 13 Pro Max
        "iPhone14,7",                // iPhone 14
        "iPhone14,8",                // iPhone 14 Plus
        "iPhone17,5"                 // iPhone 16e
    ]
    
    return notchDevices.contains(deviceModel)
}

func hasDynamicIsland() -> Bool {
    let deviceModel = getDeviceModel()
    
    // iPhone devices with Dynamic Island
    let dynamicIslandDevices: Set<String> = [
        "iPhone15,2",                // iPhone 14 Pro
        "iPhone15,3",                // iPhone 14 Pro Max
        "iPhone15,4",                // iPhone 15
        "iPhone15,5",                // iPhone 15 Plus
        "iPhone16,1",                // iPhone 15 Pro
        "iPhone16,2",                // iPhone 15 Pro Max
        "iPhone17,1",                // iPhone 16
        "iPhone17,2",                // iPhone 16 Plus
        "iPhone17,3",                // iPhone 16 Pro
        "iPhone17,4"                 // iPhone 16 Pro Max
    ]
    
    return dynamicIslandDevices.contains(deviceModel)
}

func isIPadWithHomeButton() -> Bool {
    let deviceModel = getDeviceModel()
    
    // iPad devices with home button (iOS 15+ compatible)
    let iPadHomeButtonDevices: Set<String> = [
        "iPad7,11", "iPad7,12",      // iPad 7th gen
        "iPad11,6", "iPad11,7",      // iPad 8th gen
        "iPad12,1", "iPad12,2",      // iPad 9th gen
        "iPad13,18", "iPad13,19",    // iPad 10th gen
    ]
    
    return iPadHomeButtonDevices.contains(deviceModel)
}

enum DeviceType: Int, CaseIterable {
    case iPhoneHomeButton = 0
    case iPhoneNotch = 1
    case iPhoneDynamicIsland = 2
    case iPadHomeButton = 3
    case iPadNoHomeButton = 4
    case unknown = 5
    
    var displayName: String {
        switch self {
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

func getDeviceType() -> DeviceType {
    // Check if user has overridden the device type
    if let overrideRawValue = UserDefaults.standard.object(forKey: "deviceTypeOverride") as? Int,
       let overrideType = DeviceType(rawValue: overrideRawValue) {
        return overrideType
    }
    
    // Use actual device detection
    
    if UIDevice.current.userInterfaceIdiom == .pad {
        return isIPadWithHomeButton() ? .iPadHomeButton : .iPadNoHomeButton
    } else if UIDevice.current.userInterfaceIdiom == .phone {
        if hasHomeButton() {
            return .iPhoneHomeButton
        } else if hasNotch() {
            return .iPhoneNotch
        } else if hasDynamicIsland() {
            return .iPhoneDynamicIsland
        }
    }
    
    return .unknown
}

func getActualDeviceType() -> DeviceType {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return isIPadWithHomeButton() ? .iPadHomeButton : .iPadNoHomeButton
    } else if UIDevice.current.userInterfaceIdiom == .phone {
        if hasHomeButton() {
            return .iPhoneHomeButton
        } else if hasNotch() {
            return .iPhoneNotch
        } else if hasDynamicIsland() {
            return .iPhoneDynamicIsland
        }
    }
    
    return .unknown
}

func setDeviceTypeOverride(_ deviceType: DeviceType?) {
    if let deviceType = deviceType {
        UserDefaults.standard.set(deviceType.rawValue, forKey: "deviceTypeOverride")
    } else {
        UserDefaults.standard.removeObject(forKey: "deviceTypeOverride")
    }
}

func getDeviceTypeOverride() -> DeviceType? {
    if let overrideRawValue = UserDefaults.standard.object(forKey: "deviceTypeOverride") as? Int,
       let overrideType = DeviceType(rawValue: overrideRawValue) {
        return overrideType
    }
    return nil
}

class PaddingManager: ObservableObject {
    static let shared = PaddingManager()
    
    @Published var clockXPadding: CGFloat
    @Published var clockYPadding: CGFloat
    @Published var clockScale: CGFloat
    
    private init() {
        self.clockXPadding = ClockPadding.xPadding()
        self.clockYPadding = ClockPadding.yPadding()
        self.clockScale = ClockScale.scale()
    }
    
    func updateClockXPadding(_ value: CGFloat) {
        ClockPadding.setXPadding(value)
        clockXPadding = value
    }
    
    func updateClockYPadding(_ value: CGFloat) {
        ClockPadding.setYPadding(value)
        clockYPadding = value
    }
    
    func updateClockScale(_ value: CGFloat) {
        ClockScale.setScale(value)
        clockScale = value
    }
    
    func refreshValues() {
        let deviceModel = getDeviceModel()
        
        if UserDefaults.standard.object(forKey: "clock_xPadding_\(deviceModel)") != nil {
            clockXPadding = CGFloat(UserDefaults.standard.float(forKey: "clock_xPadding_\(deviceModel)"))
        } else {
            clockXPadding = ClockPadding.xPadding()
        }
        
        if UserDefaults.standard.object(forKey: "clock_yPadding_\(deviceModel)") != nil {
            clockYPadding = CGFloat(UserDefaults.standard.float(forKey: "clock_yPadding_\(deviceModel)"))
        } else {
            clockYPadding = ClockPadding.yPadding()
        }
        
        if UserDefaults.standard.object(forKey: "clock_scale_\(deviceModel)") != nil {
            clockScale = CGFloat(UserDefaults.standard.float(forKey: "clock_scale_\(deviceModel)"))
        } else {
            clockScale = ClockScale.scale()
        }
    }
}

struct ClockPadding {
    // Positive values move RIGHT, negative values move LEFT
    static func xPadding() -> CGFloat {
        let deviceModel = getDeviceModel()
        let key = "clock_xPadding_\(deviceModel)"
        
        if UserDefaults.standard.object(forKey: key) != nil {
            return CGFloat(UserDefaults.standard.float(forKey: key))
        }
        
        // Default values
        let deviceType = getDeviceType()
        switch deviceType {
        case .iPhoneHomeButton:
            return 41
        case .iPhoneNotch:
            return 37
        case .iPhoneDynamicIsland:
            return 41
        case .iPadHomeButton:
            return -15
        case .iPadNoHomeButton:
            return -6
        case .unknown:
            return 41
        }
    }
    
    static func setXPadding(_ value: CGFloat) {
        let deviceModel = getDeviceModel()
        let key = "clock_xPadding_\(deviceModel)"
        UserDefaults.standard.set(Float(value), forKey: key)
    }
    
    // Positive values move DOWN, negative values move UP
    static func yPadding() -> CGFloat {
        let deviceModel = getDeviceModel()
        let key = "clock_yPadding_\(deviceModel)"
        
        if UserDefaults.standard.object(forKey: key) != nil {
            return CGFloat(UserDefaults.standard.float(forKey: key))
        }
        
        // Default values
        let deviceType = getDeviceType()
        switch deviceType {
        case .iPhoneHomeButton:
            return 22
        case .iPhoneNotch:
            return 12
        case .iPhoneDynamicIsland:
            return 22
        case .iPadHomeButton:
            return -1
        case .iPadNoHomeButton:
            return 2
        case .unknown:
            return 22
        }
    }
    
    static func setYPadding(_ value: CGFloat) {
        let deviceModel = getDeviceModel()
        let key = "clock_yPadding_\(deviceModel)"
        UserDefaults.standard.set(Float(value), forKey: key)
    }
}

struct ClockScale {
    // Positive values make LARGER, values less than 1.0 make SMALLER
    static func scale() -> CGFloat {
        let deviceModel = getDeviceModel()
        let key = "clock_scale_\(deviceModel)"
        
        if UserDefaults.standard.object(forKey: key) != nil {
            return CGFloat(UserDefaults.standard.float(forKey: key))
        }
        
        // Default values
        let deviceType = getDeviceType()
        switch deviceType {
        case .iPhoneHomeButton:
            return 1.0
        case .iPhoneNotch:
            return 1.0
        case .iPhoneDynamicIsland:
            return 1.0
        case .iPadHomeButton:
            return 0.7
        case .iPadNoHomeButton:
            return 0.7
        case .unknown:
            return 1.0
        }
    }
    
    static func setScale(_ value: CGFloat) {
        let deviceModel = getDeviceModel()
        let key = "clock_scale_\(deviceModel)"
        UserDefaults.standard.set(Float(value), forKey: key)
    }
}