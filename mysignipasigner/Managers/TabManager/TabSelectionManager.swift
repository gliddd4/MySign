//
//  TabSelectionManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Combine

@MainActor
class TabSelectionManager: ObservableObject {
    static let shared = TabSelectionManager()
    
    private(set) var selectedTab: Int {
        didSet {
            if selectedTab != oldValue && !isInitializing {
                objectWillChange.send()
                UserDefaults.standard.set(selectedTab, forKey: "tab_selected")
                
                // Don't record drag handle interaction for tab selection
                // The drag handle should only respond to its own interactions
            }
        }
    }
    
    private(set) var defaultTab: Int {
        didSet {
            if defaultTab != oldValue {
                objectWillChange.send()
                UserDefaults.standard.set(defaultTab, forKey: "tab_default")
                if !isInitializing {
                    selectedTab = defaultTab
                }
            }
        }
    }
    
    // MARK: - Rapid Click Detection
    private var clickCount = 0
    private var lastClickTime: Date = Date()
    private let rapidClickThreshold: TimeInterval = 0.8 // 800ms window for rapid clicks
    private let requiredClickCount = 10
    
    var isInitializing: Bool = true
    nonisolated let objectWillChange = ObservableObjectPublisher()
    
    init() {
        let storedDefault = UserDefaults.standard.integer(forKey: "tab_default")
        defaultTab = (0..<TabItem.defaultItems.count).contains(storedDefault) ? storedDefault : 0
        selectedTab = defaultTab
        UserDefaults.standard.removeObject(forKey: "tab_selected")
        
        Task { @MainActor in
            self.isInitializing = false
            // Auto-hide timer disabled per user request
        }
    }
    
    func setDefaultTab(_ tab: Int) {
        guard tab >= 0 && tab < TabItem.defaultItems.count else { return }
        defaultTab = tab
    }
    
    func selectTab(_ tab: Int) {
        guard tab >= 0 && tab < TabItem.defaultItems.count else { return }
        guard tab != selectedTab && !isInitializing else { 
            // Even if it's the same tab, track the click for rapid detection
            trackTabClick()
            return 
        }
        
        selectedTab = tab
        trackTabClick()
        
        let tabName = TabItem.defaultItems[tab].name
        ToastManager.shared.showToast.log("Switched tab to \(tabName)")
    }
    
    private func trackTabClick() {
        let currentTime = Date()
        let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
        
        if timeSinceLastClick <= rapidClickThreshold {
            clickCount += 1
        } else {
            clickCount = 1 // Reset count if too much time has passed
        }
        
        lastClickTime = currentTime
        
        // Check if we've reached the required click count
        if clickCount >= requiredClickCount {
            triggerBoomSound()
            clickCount = 0 // Reset after triggering
        }
    }
    
    private func triggerBoomSound() {
        HapticManager.shared.heavy() // Extra strong haptic for special event
        AudioManager.shared.playBoomSound(times: 1)
        ToastManager.shared.showToast.log("🎉 BOOM! Easter egg activated!")
    }
    
    var selectedTabName: String {
        guard selectedTab >= 0 && selectedTab < TabItem.defaultItems.count else {
            return "App"
        }
        return TabItem.defaultItems[selectedTab].name
    }
}