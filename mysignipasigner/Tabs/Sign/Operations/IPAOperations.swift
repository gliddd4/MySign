//
//  IPAOperations.swift
//  mysignipasigner
//
//  Created by gliddd4 eee
//

import Foundation
import ZIPFoundation

class IPAOperations {
    static let shared = IPAOperations()
    
    private init() {}
    
    func copyIPAToAppContainer(url: URL) async -> URL? {
        return await Task.detached(priority: .userInitiated) {
            guard let importedIPAsDirectory = await DirectoryManager.shared.getURL(for: .importedIPAs) else {
                return nil
            }
            
            if url.deletingLastPathComponent().standardized.path == importedIPAsDirectory.standardized.path {
                return url
            }
            
            let destinationURL = importedIPAsDirectory.appendingPathComponent(url.lastPathComponent)
            
            do {
                let isAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if isAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                return destinationURL
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to copy IPA file: \(error.localizedDescription)")
                }
                return nil
            }
        }.value
    }
    
    func parseIPAInfo(url: URL) async throws -> (appName: String, bundleID: String, version: String) {
        return try await Task.detached(priority: .userInitiated) {
            guard let archive = try? Archive(url: url, accessMode: .read, pathEncoding: .utf8) else {
                throw NSError(domain: "IPAParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read IPA file"])
            }
            
            await MainActor.run {
                ToastManager.shared.showToast.silentWarning("IPA contains \(archive.makeIterator().underestimatedCount) files")
            }
            
            let mainPlistEntries = archive.filter { entry in
                let path = entry.path
                let components = path.components(separatedBy: "/")
                
                return components.count == 3 &&
                components[0] == "Payload" &&
                components[1].hasSuffix(".app") &&
                components[2] == "Info.plist"
            }
            
            await MainActor.run {
                ToastManager.shared.showToast.silentWarning("Found \(mainPlistEntries.count) main app Info.plist files")
            }
            
            guard let mainPlistEntry = mainPlistEntries.first else {
                throw NSError(domain: "IPAParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "Main app Info.plist not found. Expected format: Payload/AppName.app/Info.plist"])
            }
            
            await MainActor.run {
                ToastManager.shared.showToast.silentSuccess("Using main app Info.plist at: \(mainPlistEntry.path)")
            }
            
            var plistData = Data()
            _ = try archive.extract(mainPlistEntry) { data in
                plistData.append(data)
            }
            
            guard let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                throw NSError(domain: "IPAParser", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid Info.plist format"])
            }
            
            let appName: String
            if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                appName = displayName
            } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
                appName = bundleName
            } else {
                let pathComponents = mainPlistEntry.path.components(separatedBy: "/")
                if let appComponent = pathComponents.first(where: { $0.hasSuffix(".app") }) {
                    appName = String(appComponent.dropLast(4))
                } else {
                    appName = url.deletingPathExtension().lastPathComponent
                }
            }
            
            let bundleID = plist["CFBundleIdentifier"] as? String ?? ""
            let version = plist["CFBundleVersion"] as? String ?? ""
            
            return (appName, bundleID, version)
        }.value
    }
}