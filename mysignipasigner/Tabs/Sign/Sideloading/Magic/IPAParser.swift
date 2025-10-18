//
//  IPAParser.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import ZIPFoundation

@MainActor
class IPAParser {
    static func extractBundleId(fromPayloadFolder payloadFolderPath: String) async -> String {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let payloadURL = URL(fileURLWithPath: payloadFolderPath, isDirectory: true)
            
            guard let enumerator = fileManager.enumerator(at: payloadURL, includingPropertiesForKeys: nil, options: [], errorHandler: nil) else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("App bundle not found")
                }
                return "Error: .app folder not found"
            }
            
            let appFolderURL = enumerator.allObjects.compactMap { $0 as? URL }
                .first { url in
                    url.pathExtension == "app" &&
                    !url.path.contains("/Frameworks/") &&
                    !url.path.contains("/PlugIns/") &&
                    !url.path.contains("/Watch/")
                }
            
            guard let mainAppURL = appFolderURL else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Main app bundle not found")
                }
                return "Error: Main .app folder not found"
            }
            
            let infoPlistURL = mainAppURL.appendingPathComponent("Info.plist")
            
            guard fileManager.fileExists(atPath: infoPlistURL.path) else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("App configuration file not found")
                }
                return "Error: Info.plist not found"
            }
            
            guard let infoPlistData = try? Data(contentsOf: infoPlistURL),
                  let infoPlist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
                  let bundleID = infoPlist["CFBundleIdentifier"] as? String else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Could not read app bundle identifier")
                }
                return "Error: Bundle ID not found"
            }
            
            return bundleID
        }.value
    }
    
    static func extractBundleVersion(fromPayloadFolder payloadFolderPath: String) async -> String {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let payloadURL = URL(fileURLWithPath: payloadFolderPath, isDirectory: true)
            
            guard let enumerator = fileManager.enumerator(at: payloadURL, includingPropertiesForKeys: nil, options: [], errorHandler: nil) else {
                return "Error: .app folder not found"
            }
            
            let appFolderURL = enumerator.allObjects.compactMap { $0 as? URL }
                .first { url in
                    url.pathExtension == "app" &&
                    !url.path.contains("/Frameworks/") &&
                    !url.path.contains("/PlugIns/") &&
                    !url.path.contains("/Watch/")
                }
            
            guard let mainAppURL = appFolderURL else {
                return "Error: Main .app folder not found"
            }
            
            let infoPlistURL = mainAppURL.appendingPathComponent("Info.plist")
            
            guard fileManager.fileExists(atPath: infoPlistURL.path),
                  let infoPlistData = try? Data(contentsOf: infoPlistURL),
                  let infoPlist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
                  let bundleVersion = infoPlist["CFBundleVersion"] as? String else {
                return "1" // Default version fallback
            }
            
            return bundleVersion
        }.value
    }
    
    static func extractAppIcon(fromPayloadFolder payloadFolderPath: String) async -> String? {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let payloadURL = URL(fileURLWithPath: payloadFolderPath, isDirectory: true)
            
            guard let enumerator = fileManager.enumerator(at: payloadURL, includingPropertiesForKeys: nil, options: [], errorHandler: nil),
                  let appFolderURL = (enumerator.allObjects.first { ($0 as? URL)?.pathExtension == "app" }) as? URL,
                  let appBundleContents = try? fileManager.contentsOfDirectory(at: appFolderURL, includingPropertiesForKeys: nil, options: []) else {
                return nil
            }
            
            let iconFiles = appBundleContents.filter { $0.lastPathComponent.hasPrefix("AppIcon") }
            
            let sortedIconFiles = iconFiles.sorted { (url1, url2) -> Bool in
                let resolution1 = url1.lastPathComponent.components(separatedBy: "-").last?.components(separatedBy: "x").first.flatMap { Int($0) } ?? 0
                let resolution2 = url2.lastPathComponent.components(separatedBy: "x").last?.components(separatedBy: "x").first.flatMap { Int($0) } ?? 0
                return resolution1 > resolution2
            }
            
            guard let iconFileURL = sortedIconFiles.first,
                  fileManager.fileExists(atPath: iconFileURL.path) else {
                return nil
            }
            
            return iconFileURL.path
        }.value
    }
    
    static func extractAppName(fromPayloadFolder payloadFolderPath: String) async -> String {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let payloadURL = URL(fileURLWithPath: payloadFolderPath, isDirectory: true)
            
            guard let enumerator = fileManager.enumerator(at: payloadURL, includingPropertiesForKeys: nil, options: [], errorHandler: nil) else {
                return "Unknown App"
            }
            
            let appFolderURL = enumerator.allObjects.compactMap { $0 as? URL }
                .first { url in
                    url.pathExtension == "app" &&
                    !url.path.contains("/Frameworks/") &&
                    !url.path.contains("/PlugIns/") &&
                    !url.path.contains("/Watch/")
                }
            
            guard let mainAppURL = appFolderURL else {
                return "Unknown App"
            }
            
            let infoPlistURL = mainAppURL.appendingPathComponent("Info.plist")
            
            guard fileManager.fileExists(atPath: infoPlistURL.path),
                  let infoPlistData = try? Data(contentsOf: infoPlistURL),
                  let infoPlist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any] else {
                // Fallback to app folder name if plist reading fails
                return mainAppURL.deletingPathExtension().lastPathComponent
            }
            
            if let displayName = infoPlist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                return displayName
            } else if let bundleName = infoPlist["CFBundleName"] as? String, !bundleName.isEmpty {
                return bundleName
            } else {
                // Fallback to app folder name
                return mainAppURL.deletingPathExtension().lastPathComponent
            }
        }.value
    }

    static func createIPAFromAppBundle(appURL: URL, destinationDirectory: URL) async throws -> URL {
        let fileManager = FileManager.default
        
        guard let tempBase = DirectoryManager.shared.getURL(for: .temporaryFiles) else {
            Task { @MainActor in
                ToastManager.shared.showToast.error("Could not access temporary directory")
            }
            throw NSError(domain: "IPAParser", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Could not access temporary directory"])
        }
        
        let tempDir = tempBase.appendingPathComponent("PayloadTemp")
        
        try await Task.detached(priority: .background) {
            if fileManager.fileExists(atPath: tempDir.path) {
                try fileManager.removeItem(at: tempDir)
            }
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Create Payload directory
            let payloadDir = tempDir.appendingPathComponent("Payload")
            try fileManager.createDirectory(at: payloadDir, withIntermediateDirectories: true)
            
            // Copy .app to Payload directory
            let appInPayload = payloadDir.appendingPathComponent(appURL.lastPathComponent)
            try fileManager.copyItem(at: appURL, to: appInPayload)
        }.value
        
        // Create IPA (zip the Payload directory)
        let ipaName = appURL.deletingPathExtension().lastPathComponent + ".ipa"
        let ipaURL = destinationDirectory.appendingPathComponent(ipaName)
        
        // Remove existing IPA if it exists
        if fileManager.fileExists(atPath: ipaURL.path) {
            try await Task.detached(priority: .background) {
                try fileManager.removeItem(at: ipaURL)
            }.value
        }
        
        try await Task.detached(priority: .background) {
            try fileManager.zipItem(at: tempDir, to: ipaURL)
        }.value
        
        // Clean up temporary directory
        try? await Task.detached(priority: .background) {
            try fileManager.removeItem(at: tempDir)
        }.value
        
        await MainActor.run {
            ToastManager.shared.showToast.success("IPA created successfully")
        }
        
        return ipaURL
    }
    
    static func extractAppNameFromZIP(fileURL: URL) async throws -> String {
        return try await Task.detached(priority: .userInitiated) {
            guard let archive = try? Archive(url: fileURL, accessMode: .read, pathEncoding: .utf8) else {
                throw NSError(domain: "IPAParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read IPA file"])
            }
            
            let appEntries = archive.filter { entry in
                let path = entry.path
                let components = path.components(separatedBy: "/")
                
                // Must be exactly: Payload/AppName.app/Info.plist
                return components.count == 3 &&
                components[0] == "Payload" &&
                components[1].hasSuffix(".app") &&
                components[2] == "Info.plist" &&
                !components[1].contains("Frameworks") // Exclude frameworks
            }
            
            guard let appEntry = appEntries.first else {
                throw NSError(domain: "IPAParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "Main app Info.plist not found in IPA"])
            }
            
            var plistData = Data()
            _ = try archive.extract(appEntry) { data in
                plistData.append(data)
            }
            
            guard let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                throw NSError(domain: "IPAParser", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid Info.plist format"])
            }
            
            if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                return displayName
            } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
                return bundleName
            }
            
            // Fallback to extracting app name from path
            let appPath = appEntry.path.components(separatedBy: "/")[1] // Get the .app folder name
            let appName = appPath.components(separatedBy: ".app")[0]
            return appName.isEmpty ? "Unknown App" : appName
        }.value
    }
}