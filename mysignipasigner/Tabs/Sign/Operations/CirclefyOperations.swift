//
//  CirclefyOperations.swift
//  mysignipasigner
//
//  Created by gliddd4 eee
//

import Foundation
import ZIPFoundation

class CirclefyOperations {
    static let shared = CirclefyOperations()
    
    private init() {}
    
    func modifyIPA(_ ipaPath: String, _ platform: Int32) throws -> String {
        guard let extractedPath = unzipIPA(ipaPath, platform: platform) else {
            throw NSError(domain: "CirclefyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract IPA"])
        }
        
        defer {
            try? FileManager.default.removeItem(atPath: extractedPath)
        }
        
        let payloadPath = "\(extractedPath)/Payload"
        guard let appFolder = try FileManager.default.contentsOfDirectory(atPath: payloadPath).first(where: { $0.hasSuffix(".app") }),
              let infoPlist = NSDictionary(contentsOfFile: "\(payloadPath)/\(appFolder)/Info.plist"),
              let executable = infoPlist["CFBundleExecutable"] as? String else {
            throw NSError(domain: "CirclefyError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to locate executable"])
        }
        
        let executablePath = "\(payloadPath)/\(appFolder)/\(executable)"
        
        // Make the ModifyExecutable call synchronous using a semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var modificationSuccess = false
        
        DispatchQueue.main.async {
            if CirclefyManager.shared.isModifyExecutableAvailable() {
                CirclefyManager.shared.modifyExecutable(at: executablePath, with: UInt32(platform))
                ToastManager.shared.showToast.success("Circlefy modification applied")
                modificationSuccess = true
            } else {
                ToastManager.shared.showToast.warning("Circlefy modification temporarily disabled - function not accessible")
                modificationSuccess = false
            }
            semaphore.signal()
        }
        
        // Wait for the modification to complete
        semaphore.wait()
        
        guard modificationSuccess else {
            throw NSError(domain: "CirclefyError", code: -4, userInfo: [NSLocalizedDescriptionKey: "ModifyExecutable failed or unavailable"])
        }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let modifiedIpaPath = "\(documentsPath)/\(UUID().uuidString)_circlefy.ipa"
        
        // Don't delete the original IPA - let the caller handle cleanup
        // The original IPA needs to remain for potential error recovery
        
        guard zipPayload(payloadPath, to: modifiedIpaPath) else {
            throw NSError(domain: "CirclefyError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create modified IPA"])
        }
        
        return modifiedIpaPath
    }
    
    private func unzipIPA(_ ipaPath: String, platform: Int32) -> String? {
        let extractedPath = "\(NSHomeDirectory())/Documents/\(UUID().uuidString)"
        
        do {
            try FileManager.default.unzipItem(at: URL(fileURLWithPath: ipaPath), to: URL(fileURLWithPath: extractedPath))
            
            DispatchQueue.main.async {
                let maskType = platform == PLATFORM_VISIONOS ? "Circle" : "No Mask"
                ToastManager.shared.showToast.warning("Applying \(maskType) mask to IPA")
            }
            
            return extractedPath
        } catch {
            DispatchQueue.main.async {
                ToastManager.shared.showToast.error("Failed to extract IPA: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    func modifySignedIPA(_ signedIpaPath: String, _ platform: Int32) throws -> String {
        DispatchQueue.main.async {
            ToastManager.shared.showToast.warning("Starting Circlefy modification on signed IPA...")
        }
        
        guard let extractedPath = unzipSignedIPA(signedIpaPath, platform: platform) else {
            throw NSError(domain: "CirclefyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract signed IPA"])
        }
        
        defer {
            try? FileManager.default.removeItem(atPath: extractedPath)
        }
        
        let payloadPath = "\(extractedPath)/Payload"
        guard let appFolder = try FileManager.default.contentsOfDirectory(atPath: payloadPath).first(where: { $0.hasSuffix(".app") }),
              let infoPlist = NSDictionary(contentsOfFile: "\(payloadPath)/\(appFolder)/Info.plist"),
              let executable = infoPlist["CFBundleExecutable"] as? String else {
            throw NSError(domain: "CirclefyError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to locate executable in signed IPA"])
        }
        
        let executablePath = "\(payloadPath)/\(appFolder)/\(executable)"
        
        // Apply ModifyExecutable to the signed executable
        let semaphore = DispatchSemaphore(value: 0)
        var modificationSuccess = false
        
        DispatchQueue.main.async {
            if CirclefyManager.shared.isModifyExecutableAvailable() {
                CirclefyManager.shared.modifyExecutable(at: executablePath, with: UInt32(platform))
                ToastManager.shared.showToast.success("Circlefy modification applied to signed executable")
                modificationSuccess = true
            } else {
                ToastManager.shared.showToast.warning("Circlefy modification temporarily disabled - function not accessible")
                modificationSuccess = false
            }
            semaphore.signal()
        }
        
        // Wait for the modification to complete
        semaphore.wait()
        
        guard modificationSuccess else {
            throw NSError(domain: "CirclefyError", code: -4, userInfo: [NSLocalizedDescriptionKey: "ModifyExecutable failed or unavailable"])
        }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let modifiedIpaPath = "\(documentsPath)/\(UUID().uuidString)_circlefy_signed.ipa"
        
        guard zipPayload(payloadPath, to: modifiedIpaPath) else {
            throw NSError(domain: "CirclefyError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create Circlefy-modified signed IPA"])
        }
        
        DispatchQueue.main.async {
            ToastManager.shared.showToast.success("Circlefy-modified signed IPA created successfully")
        }
        return modifiedIpaPath
    }
    
    private func unzipSignedIPA(_ signedIpaPath: String, platform: Int32) -> String? {
        let extractedPath = "\(NSHomeDirectory())/Documents/\(UUID().uuidString)_signed_extract"
        
        do {
            try FileManager.default.unzipItem(at: URL(fileURLWithPath: signedIpaPath), to: URL(fileURLWithPath: extractedPath))
            
            DispatchQueue.main.async {
                let maskType = platform == PLATFORM_VISIONOS ? "Circle" : "No Mask"
                ToastManager.shared.showToast.warning("Applying \(maskType) mask to signed IPA")
            }
            
            return extractedPath
        } catch {
            DispatchQueue.main.async {
                ToastManager.shared.showToast.error("Failed to extract signed IPA: \(error.localizedDescription)")
            }
            return nil
        }
    }

    private func zipPayload(_ payloadPath: String, to destinationPath: String) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: destinationPath) {
                try FileManager.default.removeItem(atPath: destinationPath)
            }
            try FileManager.default.zipItem(at: URL(fileURLWithPath: payloadPath), to: URL(fileURLWithPath: destinationPath), compressionMethod: .deflate)
            
            DispatchQueue.main.async {
                ToastManager.shared.showToast.success("IPA packaged successfully")
            }
            
            return true
        } catch {
            DispatchQueue.main.async {
                ToastManager.shared.showToast.error("Failed to package IPA: \(error.localizedDescription)")
            }
            return false
        }
    }
}