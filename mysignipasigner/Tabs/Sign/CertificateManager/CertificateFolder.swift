//
//  CertificateFolder.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

struct CertificateFolder {
    let teamName: String
    let folderURL: URL
    let p12URL: URL?
    let mobileProvisionURL: URL?
    let esigncertURL: URL?
    let isValid: Bool
    
    init(teamName: String, folderURL: URL) {
        self.teamName = teamName
        self.folderURL = folderURL
        
        // Scan for certificate files in the folder
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            self.p12URL = files.first(where: { $0.pathExtension.lowercased() == "p12" })
            self.mobileProvisionURL = files.first(where: { $0.pathExtension.lowercased() == "mobileprovision" })
            self.esigncertURL = files.first(where: { $0.pathExtension.lowercased() == "esigncert" })
            self.isValid = p12URL != nil && mobileProvisionURL != nil
        } catch {
            self.p12URL = nil
            self.mobileProvisionURL = nil
            self.esigncertURL = nil
            self.isValid = false
        }
    }
}