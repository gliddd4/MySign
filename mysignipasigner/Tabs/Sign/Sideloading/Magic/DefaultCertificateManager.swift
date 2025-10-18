//
//  DefaultCertificateManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

@MainActor
class DefaultCertificateManager: ObservableObject {
    static let shared = DefaultCertificateManager()
    
    private let defaultCertificateKey = "DefaultCertificateTeamName"
    
    @Published var defaultCertificateTeamName: String? {
        didSet {
            if let teamName = defaultCertificateTeamName {
                UserDefaults.standard.set(teamName, forKey: defaultCertificateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultCertificateKey)
            }
        }
    }
    
    private init() {
        self.defaultCertificateTeamName = UserDefaults.standard.string(forKey: defaultCertificateKey)
    }
    
    func setDefaultCertificate(_ teamName: String) {
        defaultCertificateTeamName = teamName
        ToastManager.shared.showToast.success("Set '\(teamName)' as default certificate")
    }
    
    func removeDefaultCertificate() {
        if let currentDefault = defaultCertificateTeamName {
            defaultCertificateTeamName = nil
            ToastManager.shared.showToast.success("Removed '\(currentDefault)' as default certificate")
        }
    }
    
    func hasDefaultCertificate() -> Bool {
        return defaultCertificateTeamName != nil
    }
    
    func isDefaultCertificate(_ teamName: String) -> Bool {
        return defaultCertificateTeamName == teamName
    }
    
    func getDefaultCertificate() -> String? {
        return defaultCertificateTeamName
    }
    
    func autoSetFirstCertificateAsDefault(_ teamName: String) {
        if !hasDefaultCertificate() {
            setDefaultCertificate(teamName)
            ToastManager.shared.showToast.warning("Automatically set '\(teamName)' as your default certificate")
        }
    }
}
