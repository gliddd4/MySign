//
//  CertificateManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import Security
import ZIPFoundation

struct P12ValidationResult {
    let teamName: String
    let password: String
}

@_silgen_name("validateP12Only")
func validateP12Only(_ p12Path: UnsafePointer<CChar>, _ password: UnsafePointer<CChar>, _ teamNameOut: UnsafeMutablePointer<CChar>, _ teamNameSize: Int32) -> Int32

class CertificateManager {
    static let shared = CertificateManager()
    private var currentValidation: P12ValidationResult?
    
    private let commonPasswords = [
        "1",
        "",
        "AppleP12",
        "AppleP12.com",
        "1234",
        "123"
    ]
    
    private init() {}
    
    enum CertificateError: Error {
        case invalidPassword
        case cannotReadCertificate
        case invalidCertificateFormat
        case missingTeamName
        case fileAccessError
    }
    
    // MARK: - Team Name Cleanup
    private func cleanTeamName(_ rawTeamName: String) -> String {
        var cleanedName = rawTeamName
        
        // Remove common certificate type prefixes, keeping the developer name and Team ID
        let prefixesToRemove = [
            "iPhone Distribution: ",
            "iPhone Developer: ",
            "Apple Development: ",
            "Apple Distribution: ",
            "iOS Developer: ",
            "iOS Distribution: ",
            "Mac Developer: ",
            "Mac Distribution: ",
            "Developer ID Application: ",
            "Developer ID Installer: ",
            "3rd Party Mac Developer Application: ",
            "3rd Party Mac Developer Installer: "
        ]
        
        for prefix in prefixesToRemove {
            if cleanedName.hasPrefix(prefix) {
                cleanedName = String(cleanedName.dropFirst(prefix.count))
                break
            }
        }
        
        // Clean up whitespace
        cleanedName = cleanedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedName.isEmpty ? rawTeamName : cleanedName
    }
    
    func extractTeamNameFromP12(p12URL: URL, password: String) -> Result<String, Error> {
        let p12Path = p12URL.path
        let teamNameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { teamNameBuffer.deallocate() }
        
        Task { @MainActor in
            ToastManager.shared.addLog("Attempting to validate P12 with password: '\(password)'")
            ToastManager.shared.addLog("P12 file path: \(p12Path)")
        }
        
        let result = validateP12Only(p12Path, password, teamNameBuffer, 256)
        
        Task { @MainActor in
            ToastManager.shared.addLog("validateP12Only returned: \(result)")
        }
        
        switch result {
        case 0: // Success
            let rawTeamName = String(cString: teamNameBuffer).trimmingCharacters(in: .whitespaces)
            if rawTeamName.isEmpty {
                Task { @MainActor in
                    ToastManager.shared.showToast.silentError("Certificate Error: Could not extract team name")
                }
                return .failure(CertificateError.missingTeamName)
            }
            
            let cleanedTeamName = cleanTeamName(rawTeamName)
            
            Task { @MainActor in
                ToastManager.shared.showToast.silentSuccess("Successfully extracted team name: \(cleanedTeamName)")
                ToastManager.shared.addLog("Raw team name: \(rawTeamName)")
                ToastManager.shared.addLog("Cleaned team name: \(cleanedTeamName)")
            }
            return .success(cleanedTeamName)
            
        case -1: // Validation failed
            Task { @MainActor in
                ToastManager.shared.showToast.silentError("Certificate Error: Invalid password or certificate file")
            }
            return .failure(CertificateError.invalidPassword)
            
        case -2: // No team name found
            Task { @MainActor in
                ToastManager.shared.showToast.silentError("Certificate Error: Could not extract team name from certificate")
            }
            return .failure(CertificateError.missingTeamName)
            
        default:
            Task { @MainActor in
                ToastManager.shared.showToast.silentError("Certificate Error: Unknown validation error (code: \(result))")
            }
            return .failure(CertificateError.cannotReadCertificate)
        }
    }
    
    func validateP12Password(p12URL: URL, password: String) -> Result<String, Error> {
        let result = extractTeamNameFromP12(p12URL: p12URL, password: password)
        
        switch result {
        case .success(let teamName):
            currentValidation = P12ValidationResult(teamName: teamName, password: password)
        case .failure:
            Task { @MainActor in
                ToastManager.shared.showToast.silentError("Failed to validate certificate with provided password")
            }
        }
        
        return result
    }
    
    @MainActor
    func tryCommonPasswords(p12URL: URL) async -> Bool {
        ToastManager.shared.addLog("Starting common password attempt with \(commonPasswords.count) passwords")
        var anySuccess = false
        
        for (index, password) in commonPasswords.enumerated() {
            ToastManager.shared.addLog("Trying password #\(index + 1): '\(password)'")
            let result = validateP12Password(p12URL: p12URL, password: password)
            
            switch result {
            case .success(let teamName):
                ToastManager.shared.addLog("SUCCESS: Password '\(password)' worked for team: \(teamName)")
                anySuccess = true
                break
            case .failure(let error):
                ToastManager.shared.addLog("FAILED: Password '\(password)' failed with error: \(error)")
                continue
            }
        }
        
        if anySuccess {
            return true
        }
        
        ToastManager.shared.showToast.silentError("No common certificate passwords worked")
        ToastManager.shared.addLog("All common passwords failed")
        return false
    }
    
    @MainActor
    func createCertificateFolder(mpURL: URL, p12URL: URL) async -> Bool {
        guard let certificatesPath = DirectoryManager.shared.getURL(for: .importedCertificates),
              let validation = currentValidation else {
            ToastManager.shared.showToast.error("Error: Certificate validation not found")
            return false
        }

        do {
            // Log all files in Imported Certificates folder before processing
            await logImportedCertificatesContents(certificatesPath: certificatesPath, stage: "BEFORE certificate creation")
            
            let folderURL = certificatesPath.appendingPathComponent(validation.teamName)
            
            // Check if files are already in the team folder
            let mpSourceFolder = mpURL.deletingLastPathComponent().path
            let p12SourceFolder = p12URL.deletingLastPathComponent().path
            let teamFolderPath = folderURL.path
            
            if mpSourceFolder == teamFolderPath && p12SourceFolder == teamFolderPath {
                ToastManager.shared.showToast.success("Files already in team folder: \(validation.teamName)")
                try savePasswordToFolder(folderURL: folderURL, password: validation.password)
                return true
            }
            
            if FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.removeItem(at: folderURL)
            }
            
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            let mpDestination = folderURL.appendingPathComponent(mpURL.lastPathComponent)
            let p12Destination = folderURL.appendingPathComponent(p12URL.lastPathComponent)
            
            try FileManager.default.copyItem(at: mpURL, to: mpDestination)
            try FileManager.default.copyItem(at: p12URL, to: p12Destination)
            
            try savePasswordToFolder(folderURL: folderURL, password: validation.password)
            
            try await createCertificatePackage(folderURL: folderURL, teamName: validation.teamName)
            
            // Log all files before cleanup
            await logImportedCertificatesContents(certificatesPath: certificatesPath, stage: "BEFORE cleanup")
            
            // Clean up temporary files after successful certificate creation
            await cleanupTemporaryFiles(mpURL: mpURL, p12URL: p12URL, certificatesPath: certificatesPath)
            
            // Log all files after cleanup
            await logImportedCertificatesContents(certificatesPath: certificatesPath, stage: "AFTER cleanup")
            
            return true
        } catch {
            ToastManager.shared.showToast.error("Error creating certificate folder: \(error.localizedDescription)")
            return false
        }
    }
    
    @MainActor
    private func logImportedCertificatesContents(certificatesPath: URL, stage: String) async {
        ToastManager.shared.addLog("=== Imported Certificates Contents (\(stage)) ===")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: certificatesPath, includingPropertiesForKeys: [.isDirectoryKey])
            
            if contents.isEmpty {
                ToastManager.shared.addLog("Imported Certificates folder is empty")
            } else {
                ToastManager.shared.addLog("Found \(contents.count) items in Imported Certificates folder:")
                
                for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    let itemType = isDirectory ? "" : ""
                    
                    ToastManager.shared.addLog("  \(itemType): \(item.lastPathComponent)")
                    
                    // If it's a directory, show its contents too
                    if isDirectory {
                        do {
                            let subContents = try fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                            if !subContents.isEmpty {
                                ToastManager.shared.addLog("    Contents (\(subContents.count) files):")
                                for subItem in subContents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                                    ToastManager.shared.addLog("      \(subItem.lastPathComponent)")
                                }
                            }
                        } catch {
                            ToastManager.shared.addLog("    Error reading folder contents: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            ToastManager.shared.addLog("Error reading Imported Certificates folder: \(error.localizedDescription)")
        }
        
        ToastManager.shared.addLog("=== End of Contents (\(stage)) ===")
    }
    
    @MainActor
    private func cleanupTemporaryFiles(mpURL: URL, p12URL: URL, certificatesPath: URL) async {
        ToastManager.shared.addLog("Starting cleanup of temporary files...")
        
        // Clean up the specific files from current import
        await cleanupSpecificFiles(mpURL: mpURL, p12URL: p12URL, certificatesPath: certificatesPath)
        
        // Clean up any leftover temporary files from previous imports
        await cleanupAllTemporaryFiles(certificatesPath: certificatesPath)
        
        ToastManager.shared.addLog("Cleanup process completed")
    }
    
    @MainActor
    private func cleanupSpecificFiles(mpURL: URL, p12URL: URL, certificatesPath: URL) async {
        // Only clean up files if they're temporary files in the root of Imported Certificates
        let mpParentPath = mpURL.deletingLastPathComponent().path
        let p12ParentPath = p12URL.deletingLastPathComponent().path
        let certificatesRootPath = certificatesPath.path
        
        ToastManager.shared.addLog("MP file parent path: \(mpParentPath)")
        ToastManager.shared.addLog("P12 file parent path: \(p12ParentPath)")
        ToastManager.shared.addLog("Certificates root path: \(certificatesRootPath)")
        
        // Check if these are temporary files (in root and with timestamp prefix)
        let isTemporaryMP = mpParentPath == certificatesRootPath && mpURL.lastPathComponent.contains("_")
        let isTemporaryP12 = p12ParentPath == certificatesRootPath && p12URL.lastPathComponent.contains("_")
        
        ToastManager.shared.addLog("MP file is temporary: \(isTemporaryMP) (filename: \(mpURL.lastPathComponent))")
        ToastManager.shared.addLog("P12 file is temporary: \(isTemporaryP12) (filename: \(p12URL.lastPathComponent))")
        
        if isTemporaryMP {
            do {
                try FileManager.default.removeItem(at: mpURL)
                ToastManager.shared.addLog(" Cleaned up temporary MP file: \(mpURL.lastPathComponent)")
            } catch {
                ToastManager.shared.addLog(" Failed to clean up temporary MP file: \(error.localizedDescription)")
            }
        }
        
        if isTemporaryP12 {
            do {
                try FileManager.default.removeItem(at: p12URL)
                ToastManager.shared.addLog(" Cleaned up temporary P12 file: \(p12URL.lastPathComponent)")
            } catch {
                ToastManager.shared.addLog(" Failed to clean up temporary P12 file: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func cleanupAllTemporaryFiles(certificatesPath: URL) async {
        ToastManager.shared.addLog("Scanning for additional temporary files to clean up...")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: certificatesPath, includingPropertiesForKeys: [.isDirectoryKey])
            
            var tempFilesFound = 0
            var tempFilesDeleted = 0
            
            for item in contents {
                let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                
                // Skip directories (certificate folders)
                if isDirectory {
                    continue
                }
                
                let fileName = item.lastPathComponent
                
                // Identify temporary files by patterns:
                // 1. Files with timestamp prefix (digits followed by underscore)
                // 2. Files with just number prefix (like "1_" or "2_")
                let isTemporaryFile = fileName.contains("_") && (
                    fileName.hasPrefix(String(fileName.prefix(while: { $0.isNumber })) + "_") ||
                    fileName.matches(regex: "^\\d+_.*\\.(p12|mobileprovision)$")
                )
                
                if isTemporaryFile {
                    tempFilesFound += 1
                    ToastManager.shared.addLog("Found temporary file: \(fileName)")
                    
                    do {
                        try fileManager.removeItem(at: item)
                        tempFilesDeleted += 1
                        ToastManager.shared.addLog(" Deleted temporary file: \(fileName)")
                    } catch {
                        ToastManager.shared.addLog(" Failed to delete temporary file \(fileName): \(error.localizedDescription)")
                    }
                }
            }
            
            if tempFilesFound == 0 {
                ToastManager.shared.addLog("No additional temporary files found")
            } else {
                ToastManager.shared.addLog("Found \(tempFilesFound) temporary files, successfully deleted \(tempFilesDeleted)")
            }
            
        } catch {
            ToastManager.shared.addLog(" Error scanning for temporary files: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func savePasswordToFolder(folderURL: URL, password: String) throws {
        let passwordFileURL = folderURL.appendingPathComponent("password.txt")
        try password.write(to: passwordFileURL, atomically: true, encoding: .utf8)
        ToastManager.shared.showToast.silentSuccess("Password saved to password.txt")
    }
    
    @MainActor
    private func createCertificatePackage(folderURL: URL, teamName: String) async throws {
        let esigncertURL = folderURL.appendingPathComponent("\(teamName).esigncert")
        
        // Remove existing .esigncert file if it exists
        try? FileManager.default.removeItem(at: esigncertURL)
        
        // Create temporary zip file
        let tempZipURL = folderURL.appendingPathComponent("\(teamName)_temp.zip")
        try? FileManager.default.removeItem(at: tempZipURL)
        
        // Create zip archive
        let archive = try Archive(url: tempZipURL, accessMode: .create)
        
        // Add certificate files to archive (exclude the temp zip and any existing .esigncert)
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            // Skip temporary files and existing .esigncert files
            if !fileName.hasSuffix("_temp.zip") && !fileName.hasSuffix(".esigncert") {
                try archive.addEntry(with: fileName, fileURL: fileURL)
            }
        }
        
        // Rename .zip to .esigncert
        try FileManager.default.moveItem(at: tempZipURL, to: esigncertURL)
        
        await MainActor.run {
            ToastManager.shared.showToast.silentSuccess("Certificate package created: \(teamName).esigncert")
        }
    }
    
    func clearValidation() {
        currentValidation = nil
    }
    
    func hasValidP12Password() -> Bool {
        return currentValidation != nil
    }
    
    func getValidatedPassword() -> String? {
        return currentValidation?.password
    }
}

extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}