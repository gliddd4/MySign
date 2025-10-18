//
//  NewInstall.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import Security
import Combine

enum AppInstallState {
    case newInstall
    case update
    case reinstall
    case none
}

final class NewInstall: ObservableObject {
    static let shared = NewInstall()
    @Published var currentState: AppInstallState = .none
    
    private init() {
        // Ensure we're on the main thread for initialization
        if Thread.isMainThread {
            determineInstallState()
        } else {
            DispatchQueue.main.sync {
                determineInstallState()
            }
        }
    }

    private func determineInstallState() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: "app_lastVersion")
        let hasPreviousInstall = checkKeychainForInstallationID()
        
        if !hasPreviousInstall && lastVersion == nil {
            currentState = .newInstall
        } else if let lastVersion = lastVersion, lastVersion != currentVersion {
            currentState = .update
        } else if hasPreviousInstall && lastVersion == nil {
            currentState = .reinstall
        } else {
            currentState = .none
        }
        
        // Force a state update
        objectWillChange.send()
        
        // Save the installation info after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.saveInstallationIDToKeychain()
            UserDefaults.standard.set(currentVersion, forKey: "app_lastVersion")
        }
    }

    // For testing - call this method to simulate a new install
    func resetInstallState() {
        // Remove from keychain
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "appInstallIdentifier"
        ]
        SecItemDelete(query as CFDictionary)
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: "app_lastVersion")
        
        // Re-determine state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.determineInstallState()
        }
    }

    private func checkKeychainForInstallationID() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "appInstallIdentifier",
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        return status == errSecSuccess
    }
    
    private func saveInstallationIDToKeychain() {
        if checkKeychainForInstallationID() { return }
        
        guard let idData = UUID().uuidString.data(using: .utf8) else { return }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "appInstallIdentifier",
            kSecValueData: idData
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
}
