//
//  SigningManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

@MainActor
class SigningManager {
    private weak var sideloadingViewModel: SideloadingViewModel?
    
    init(sideloadingViewModel: SideloadingViewModel?) {
        self.sideloadingViewModel = sideloadingViewModel
    }
    
    func sign(appFolderURL: URL, p12Path: String?, provisioningProfilePath: String?, password: String, bundleId: String, appName: String, appVersion: String, tweakPath: String) async -> Int {
        // Validate inputs
        guard FileManager.default.fileExists(atPath: appFolderURL.path) else {
            ToastManager.shared.showToast.error("App folder not found")
            return -1
        }
        
        if let p12Path {
            guard FileManager.default.fileExists(atPath: p12Path) else {
                ToastManager.shared.showToast.error("P12 certificate not found")
                return -2
            }
        }
        
        if let provisioningProfilePath {
            guard FileManager.default.fileExists(atPath: provisioningProfilePath) else {
                ToastManager.shared.showToast.error("Provisioning profile not found")
                return -3
            }
        }
        
        // Clean and fix frameworks before signing
        await processFrameworks(appFolderURL: appFolderURL)
        
        // Handle tweak injection if needed
        if !tweakPath.isEmpty {
            FixSubstrate(tweakPath)
        }
        
        // Update progress
        sideloadingViewModel?.sideloadingPercentage = 50
        globalSideloadingPercentage = 50 // TODO: Remove global state
        
        let safeP12Path = p12Path ?? ""
        let safeProvisioningProfilePath = provisioningProfilePath ?? ""
        let safeTweakPath = tweakPath.isEmpty ? "" : tweakPath
        
        // Perform signing in a Task since zsign is synchronous
        let code = await Task.detached(priority: .userInitiated) {
            return Int(zsign(
                appFolderURL.path,
                safeP12Path,
                safeProvisioningProfilePath,
                password,
                bundleId,
                appVersion, // Pass version as bundleVersion parameter
                appName,    // Pass appName as displayName parameter
                safeTweakPath
            ))
        }.value
        
        // Handle result
        handleSigningResult(code)
        sideloadingViewModel?.sideloadingPercentage = 100
        globalSideloadingPercentage = 100 // TODO: Remove global state
        
        return code
    }
    
    func handleSigningResult(_ code: Int) {
        ToastManager.shared.showToast.silentWarning("Signing process returned code: \(code)")
        
        switch code {
        case 0:
            ToastManager.shared.showToast.success("App signed successfully")
        case -1:
            ToastManager.shared.showToast.error("Signing failed - check certificate and provisioning profile")
        case -2:
            ToastManager.shared.showToast.error("Failed to initialize signing asset - check certificate and provisioning profile")
        case -3:
            ToastManager.shared.showToast.error("Provisioning profile not found")
        default:
            ToastManager.shared.showToast.error("Failed to sign app (error \(code))")
        }
        
        ToastManager.shared.showToast.silentSuccess("Signing process completed")
    }
    
    private func processFrameworks(appFolderURL: URL) async {
        ToastManager.shared.showToast.silentWarning("Processing frameworks...")
        let fileManager = FileManager.default

        // 1. Clean main app bundle signature
        let codeSignatureURL = appFolderURL.appendingPathComponent("_CodeSignature")
        let mobileProvisionURL = appFolderURL.appendingPathComponent("embedded.mobileprovision")
        
        do {
            if fileManager.fileExists(atPath: codeSignatureURL.path) {
                try fileManager.removeItem(at: codeSignatureURL)
                ToastManager.shared.showToast.silentSuccess("Removed main app _CodeSignature")
            }
            if fileManager.fileExists(atPath: mobileProvisionURL.path) {
                try fileManager.removeItem(at: mobileProvisionURL)
                ToastManager.shared.showToast.silentSuccess("Removed main app embedded.mobileprovision")
            }
        } catch {
            ToastManager.shared.showToast.silentError("Failed to clean main app bundle: \(error.localizedDescription)")
        }

        // 2. Process frameworks
        let frameworksURL = appFolderURL.appendingPathComponent("Frameworks")
        guard fileManager.fileExists(atPath: frameworksURL.path) else {
            ToastManager.shared.showToast.silentWarning("No Frameworks folder found, skipping processing.")
            return
        }
        
        do {
            let frameworks = try fileManager.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil)
            ToastManager.shared.showToast.silentWarning("Found \(frameworks.count) items in Frameworks directory.")

            let knownProblematicFrameworks = ["OpenSSL", "libssl", "libcrypto", "OpenSSL-Universal"]

            for frameworkURL in frameworks where frameworkURL.pathExtension == "framework" {
                let frameworkName = frameworkURL.deletingPathExtension().lastPathComponent
                let executableURL = frameworkURL.appendingPathComponent(frameworkName)

                // Clean signature from all frameworks
                let frameworkCodeSignatureURL = frameworkURL.appendingPathComponent("_CodeSignature")
                if fileManager.fileExists(atPath: frameworkCodeSignatureURL.path) {
                    try? fileManager.removeItem(at: frameworkCodeSignatureURL)
                }

                // For known problematic frameworks, replace their executable with a valid stub
                if knownProblematicFrameworks.contains(where: frameworkName.contains) {
                    if fileManager.fileExists(atPath: executableURL.path) {
                        try fileManager.removeItem(at: executableURL)
                    }
                    let placeholderData = createMinimalMachOExecutable()
                    try placeholderData.write(to: executableURL)
                    ToastManager.shared.showToast.silentSuccess("Replaced \(frameworkName) with a placeholder executable.")
                }
            }
        } catch {
            ToastManager.shared.showToast.silentError("Error processing frameworks: \(error.localizedDescription)")
        }
    }

    private func createMinimalMachOExecutable() -> Data {
        // A valid, minimal 64-bit Mach-O with a pre-allocated space for the code signature.
        // This structure is sufficient for zsign/arksigning to parse and embed a new signature,
        // avoiding "No Enough CodeSignature Space" errors.
        
        // The size of the empty space for the signature. Must be larger than what's needed.
        let signatureAllocationSize: UInt32 = 8192 // 8KB
        
        // Header (32 bytes) + Load Command (16 bytes)
        let headerAndCommandSize: UInt32 = 48

        var placeholderBytes: [UInt8] = [
            // --- Mach-O Header (64-bit) ---
            0xCF, 0xFA, 0xED, 0xFE, // magic: MH_MAGIC_64
            0x0C, 0x00, 0x00, 0x01, // cputype: CPU_TYPE_ARM64
            0x00, 0x00, 0x00, 0x00, // cpusubtype: CPU_SUBTYPE_ARM64_ALL
            0x06, 0x00, 0x00, 0x00, // filetype: MH_DYLIB
            0x01, 0x00, 0x00, 0x00, // ncmds: 1
            0x10, 0x00, 0x00, 0x00, // sizeofcmds: 16 (for one LC_CODE_SIGNATURE)
            0x85, 0x00, 0x20, 0x00, // flags: MH_PIE | MH_NO_REEXPORTED_DYLIBS
            0x00, 0x00, 0x00, 0x00, // reserved
            
            // --- Load Command (LC_CODE_SIGNATURE) ---
            0x1D, 0x00, 0x00, 0x00, // cmd: LC_CODE_SIGNATURE (29)
            0x10, 0x00, 0x00, 0x00, // cmdsize: 16
        ]
        
        // Append dataoff and datasize as little-endian UInt32
        var dataoff = headerAndCommandSize.littleEndian
        withUnsafeBytes(of: &dataoff) { placeholderBytes.append(contentsOf: $0) }
        
        var datasize = signatureAllocationSize.littleEndian
        withUnsafeBytes(of: &datasize) { placeholderBytes.append(contentsOf: $0) }

        // Append the placeholder data for the signature
        placeholderBytes.append(contentsOf: [UInt8](repeating: 0, count: Int(signatureAllocationSize)))
        
        return Data(placeholderBytes)
    }
}