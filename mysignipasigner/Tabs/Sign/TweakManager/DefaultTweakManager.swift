//
//  DefaultTweakManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

@MainActor
class DefaultTweakManager: ObservableObject {
    static let shared = DefaultTweakManager()
    
    private let defaultTweaksKey = "DefaultTweakNames"
    
    @Published var defaultTweakNames: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(defaultTweakNames), forKey: defaultTweaksKey)
        }
    }
    
    private init() {
        if let savedTweaks = UserDefaults.standard.array(forKey: defaultTweaksKey) as? [String] {
            self.defaultTweakNames = Set(savedTweaks)
        }
    }
    
    func addDefaultTweak(_ tweakName: String) {
        defaultTweakNames.insert(tweakName)
        ToastManager.shared.showToast.success("Added '\(tweakName)' to default tweaks")
    }
    
    func removeDefaultTweak(_ tweakName: String) {
        defaultTweakNames.remove(tweakName)
        ToastManager.shared.showToast.success("Removed '\(tweakName)' from default tweaks")
    }
    
    func isDefaultTweak(_ tweakName: String) -> Bool {
        return defaultTweakNames.contains(tweakName)
    }
    
    func getDefaultTweaks() -> Set<String> {
        return defaultTweakNames
    }
    
    func hasDefaultTweaks() -> Bool {
        return !defaultTweakNames.isEmpty
    }
    
    func clearAllDefaultTweaks() {
        let count = defaultTweakNames.count
        defaultTweakNames.removeAll()
        ToastManager.shared.showToast.success("Cleared \(count) default tweaks")
    }
    
    func toggleDefaultTweak(_ tweakName: String) {
        if isDefaultTweak(tweakName) {
            removeDefaultTweak(tweakName)
        } else {
            addDefaultTweak(tweakName)
        }
    }
}