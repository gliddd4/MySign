//
//  InstallationManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import Swifter
import UIKit

@MainActor
class InstallationManager {
    private var server = HttpServer()
    private let baseURL = "http://127.0.0.1:8080"
    
    func createPlistFile(bundleId: String, bundleVersion: String, appName: String, hasIcon: Bool = true) async throws -> String {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ToastManager.shared.showToast.error("Documents directory not found")
            throw NSError(domain: "InstallationManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Documents directory not found"])
        }

        let plistFilePath = documentsDirectory.appendingPathComponent("install.plist")
        
        var assetsArray = """
                            <dict>
                                <key>kind</key>
                                <string>software-package</string>
                                <key>url</key>
                                <string>\(baseURL)/debugger.ipa</string>
                            </dict>
        """
        
        if hasIcon {
            assetsArray += """
                            <dict>
                                <key>kind</key>
                                <string>display-image</string>
                                <key>needs-shine</key>
                                <false/>
                                <key>url</key>
                                <string>\(baseURL)/appIcon.png</string>
                            </dict>
                            <dict>
                                <key>kind</key>
                                <string>full-size-image</string>
                                <key>needs-shine</key>
                                <false/>
                                <key>url</key>
                                <string>\(baseURL)/appIcon.png</string>
                            </dict>
            """
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <dict>
                <key>items</key>
                <array>
                    <dict>
                        <key>assets</key>
                        <array>
                            \(assetsArray)
                        </array>
                        <key>metadata</key>
                        <dict>
                            <key>bundle-identifier</key>
                            <string>\(bundleId)</string>
                            <key>bundle-version</key>
                            <string>\(bundleVersion)</string>
                            <key>kind</key>
                            <string>software</string>
                            <key>title</key>
                            <string>\(appName)</string>
                        </dict>
                    </dict>
                </array>
            </dict>
        </plist>
        """
        
        guard let data = plistContent.data(using: .utf8) else {
            ToastManager.shared.showToast.error("Failed to encode installation manifest")
            throw NSError(domain: "InstallationManager", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode plist content"])
        }
        
        do {
            try data.write(to: plistFilePath, options: .atomic)
            return plistFilePath.path
        } catch {
            ToastManager.shared.showToast.error("Error writing installation manifest: \(error.localizedDescription)")
            throw error
        }
    }
    
    func createCirclefyPlistFile(bundleId: String, bundleVersion: String, appName: String, circlefyIPAPath: String, hasIcon: Bool = false) async throws -> String {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ToastManager.shared.showToast.error("Documents directory not found")
            throw NSError(domain: "InstallationManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Documents directory not found"])
        }

        let plistFilePath = documentsDirectory.appendingPathComponent("install.plist")
        
        var assetsArray = """
                            <dict>
                                <key>kind</key>
                                <string>software-package</string>
                                <key>url</key>
                                <string>\(baseURL)/debugger.ipa</string>
                            </dict>
        """
        
        if hasIcon {
            assetsArray += """
                            <dict>
                                <key>kind</key>
                                <string>display-image</string>
                                <key>needs-shine</key>
                                <false/>
                                <key>url</key>
                                <string>\(baseURL)/appIcon.png</string>
                            </dict>
                            <dict>
                                <key>kind</key>
                                <string>full-size-image</string>
                                <key>needs-shine</key>
                                <false/>
                                <key>url</key>
                                <string>\(baseURL)/appIcon.png</string>
                            </dict>
            """
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
            <dict>
                <key>items</key>
                <array>
                    <dict>
                        <key>assets</key>
                        <array>
                            \(assetsArray)
                        </array>
                        <key>metadata</key>
                        <dict>
                            <key>bundle-identifier</key>
                            <string>\(bundleId)</string>
                            <key>bundle-version</key>
                            <string>\(bundleVersion)</string>
                            <key>kind</key>
                            <string>software</string>
                            <key>title</key>
                            <string>\(appName) (Circlefy)</string>
                        </dict>
                    </dict>
                </array>
            </dict>
        </plist>
        """
        
        guard let data = plistContent.data(using: .utf8) else {
            ToastManager.shared.showToast.error("Failed to encode Circlefy installation manifest")
            throw NSError(domain: "InstallationManager", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode plist content"])
        }
        
        do {
            try data.write(to: plistFilePath, options: .atomic)
            ToastManager.shared.showToast.silentSuccess("Created Circlefy installation manifest")
            return plistFilePath.path
        } catch {
            ToastManager.shared.showToast.error("Error writing Circlefy installation manifest: \(error.localizedDescription)")
            throw error
        }
    }
    
    func startServer() async throws {
        stopServer()
        
        do {
            try server.start(8080)
        } catch {
            ToastManager.shared.showToast.error("Failed to start server: \(error.localizedDescription)")
            throw error
        }
    }
    
    func stopServer() {
        server.stop()
    }
    
    func setupFileRoutes(signedIPAPath: String, iconPath: String, plistPath: String) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: signedIPAPath) else {
            ToastManager.shared.showToast.error("IPA file not found")
            throw NSError(domain: "InstallationManager", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "IPA file not found"])
        }
        
        guard fileManager.fileExists(atPath: plistPath) else {
            ToastManager.shared.showToast.error("Plist file not found")
            throw NSError(domain: "InstallationManager", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Plist file not found"])
        }
        
        server["/debugger.ipa"] = shareFile(signedIPAPath)
        server["/install.plist"] = shareFile(plistPath)
        
        if !iconPath.isEmpty && fileManager.fileExists(atPath: iconPath) {
            server["/appIcon.png"] = shareFile(iconPath)
        } else {
            server["/appIcon.png"] = { _ in
                if let defaultIconData = self.createDefaultAppIcon() {
                    return .ok(.data(defaultIconData))
                } else {
                    return .notFound
                }
            }
        }
    }
    
    func setupCirclefyFileRoutes(circlefyIPAPath: String, iconPath: String, plistPath: String) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: circlefyIPAPath) else {
            ToastManager.shared.showToast.error("Circlefy IPA file not found")
            throw NSError(domain: "InstallationManager", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Circlefy IPA file not found"])
        }
        
        guard fileManager.fileExists(atPath: plistPath) else {
            ToastManager.shared.showToast.error("Circlefy Plist file not found")
            throw NSError(domain: "InstallationManager", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Circlefy Plist file not found"])
        }
        
        server["/debugger.ipa"] = shareFile(circlefyIPAPath)
        server["/install.plist"] = shareFile(plistPath)
        
        ToastManager.shared.showToast.silentSuccess("Updated server routes for Circlefy IPA")
        
        if !iconPath.isEmpty && fileManager.fileExists(atPath: iconPath) {
            server["/appIcon.png"] = shareFile(iconPath)
        } else {
            server["/appIcon.png"] = { _ in
                if let defaultIconData = self.createDefaultAppIcon() {
                    return .ok(.data(defaultIconData))
                } else {
                    return .notFound
                }
            }
        }
    }
    
    private func createDefaultAppIcon() -> Data? {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let rect = CGRect(x: 30, y: 30, width: 60, height: 60)
            UIColor.white.setFill()
            context.fill(rect)
            
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20)
            path.addClip()
        }
        
        return image.pngData()
    }
    
    private func shareFile(_ filePath: String) -> ((HttpRequest) -> HttpResponse) {
        return { _ in
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                return .ok(.data(data))
            } catch {
                return .notFound
            }
        }
    }
    
    func cleanupInstallationFiles() {
        Task {
            do {
                try await FileUtilities.clearTemporaryFiles(deleteCertificates: false)
            } catch {
                ToastManager.shared.showToast.error("Error cleaning up installation files: \(error.localizedDescription)")
            }
        }
    }
}