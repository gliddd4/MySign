//  FileUtilities.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI
import ZIPFoundation

@MainActor
class FileUtilities {
    static func extractIPAPayload(ipaFilePath: URL) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            await MainActor.run {
                ToastManager.shared.showToast.silentWarning("Processing IPA at \(ipaFilePath.lastPathComponent)")
            }
            
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                await MainActor.run {
                    ToastManager.shared.showToast.silentError("Documents directory not found")
                }
                throw NSError(domain: "FileUtilities", code: -1, userInfo: [NSLocalizedDescriptionKey: "Documents directory not found"])
            }
            
            let destinationPath = documentsDirectory
            let payloadPath = destinationPath.appendingPathComponent("Payload")
            
            if fileManager.fileExists(atPath: payloadPath.path) {
                do {
                    try fileManager.removeItem(at: payloadPath)
                    await MainActor.run {
                        ToastManager.shared.showToast.silentSuccess("Cleaned existing Payload folder")
                    }
                } catch {
                    await MainActor.run {
                        ToastManager.shared.showToast.silentError("Failed to clean Payload folder: \(error.localizedDescription)")
                    }
                    throw error
                }
            }
            
            await MainActor.run {
                ToastManager.shared.showToast.silentWarning("Extracting IPA")
            }
            
            do {
                try fileManager.unzipItem(at: ipaFilePath, to: destinationPath)
                await MainActor.run {
                    ToastManager.shared.showToast.silentSuccess("IPA extraction complete")
                }
                return payloadPath
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.silentError("IPA extraction failed: \(error.localizedDescription)")
                }
                throw error
            }
        }.value
    }

    static func fileSizeForURL(_ url: URL) throws -> Float {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? NSNumber {
            return fileSize.floatValue / 1_000_000.0
        } else {
            throw NSError(domain: "FileSizeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not get file size"])
        }
    }
    
    static func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                let sizeInMB = Double(fileSize.intValue) / (1024 * 1024)
                return String(format: "%.1f MB", sizeInMB)
            }
        } catch {
            return "Unknown size"
        }
        return "Unknown size"
    }

    private static let specificFilesToDelete = [
        "debugger.ipa",
        "install.plist",
        "Payload",
        "._Payload",
        "__MACOSX",
        "downloaded-file.ipa"
    ]
    
    private static let certificateFilesToDelete = [
        "nocturna-cert.p12",
        "nocturna-cert.mobileprovision"
    ]
    
    private static func deleteFile(at url: URL, fileManager: FileManager = .default) async {
        do {
            try await Task.detached(priority: .background) {
                try fileManager.removeItem(at: url)
            }.value
            await MainActor.run {
                ToastManager.shared.showToast.silentSuccess("Deleted \(url.lastPathComponent)")
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.silentError("Error deleting \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
    
    private static func cleanDirectory(at url: URL, matching predicate: ((URL) -> Bool)? = nil) async throws {
        let fileManager = FileManager.default
        let contents = try await Task.detached(priority: .background) {
            try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )
        }.value
        
        let filesToDelete = predicate == nil ? contents : contents.filter(predicate!)
        for fileURL in filesToDelete {
            try? await Task.detached(priority: .background) {
                try fileManager.removeItem(at: fileURL)
            }.value
            await MainActor.run {
                ToastManager.shared.showToast.silentSuccess("Deleted \(fileURL.lastPathComponent)")
            }
        }
    }

    static func clearTemporaryFiles(deleteCertificates: Bool = true) async throws {
        let fileManager = FileManager.default
        
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileUtilities", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"])
        }
        
        for filename in specificFilesToDelete {
            let filePath = documentsDirectory.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: filePath.path) {
                try? await Task.detached(priority: .background) {
                    try fileManager.removeItem(at: filePath)
                }.value
                await MainActor.run {
                    ToastManager.shared.showToast.silentSuccess("Deleted \(filename)")
                }
            }
        }
        
        if deleteCertificates {
            for filename in certificateFilesToDelete {
                let filePath = documentsDirectory.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: filePath.path) {
                    try? await Task.detached(priority: .background) {
                        try fileManager.removeItem(at: filePath)
                    }.value
                    await MainActor.run {
                        ToastManager.shared.showToast.silentSuccess("Deleted \(filename)")
                    }
                }
            }
        }
        
        if let tempDirectory = DirectoryManager.shared.getURL(for: .temporaryFiles) {
            try await cleanDirectory(at: tempDirectory)
        }
        
        try await cleanDirectory(at: FileManager.default.temporaryDirectory) { url in
            url.lastPathComponent.contains("PayloadTemp") ||
            url.lastPathComponent.hasSuffix(".ipa") ||
            url.lastPathComponent.hasSuffix(".app")
        }
    }

    static func clearOldFilesInDocuments(deleteCertificates: Bool = true) async throws {
        try await clearTemporaryFiles(deleteCertificates: deleteCertificates)
    }

    @MainActor
    static func countDylibsAndFrameworks(inPayloadFolderPath path: String, tweakImported: Bool, sideloadingViewModel: SideloadingViewModel?) async throws {
        let fileManager = FileManager.default
        let appFolderPath = URL(fileURLWithPath: path).appendingPathComponent("Payload")
        
        let contents = try await Task.detached(priority: .background) {
            try fileManager.contentsOfDirectory(atPath: appFolderPath.path)
        }.value
        
        guard let appPath = contents.first(where: { $0.hasSuffix(".app") }) else {
            await MainActor.run {
                ToastManager.shared.showToast.silentError("Missing application bundle")
            }
            throw NSError(domain: "FileUtilities", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing application bundle"])
        }
        
        let fullAppPath = appFolderPath.appendingPathComponent(appPath)
        let frameworksFolderPath = fullAppPath.appendingPathComponent("Frameworks")
        
        if !fileManager.fileExists(atPath: frameworksFolderPath.path) {
            try await Task.detached(priority: .background) {
                try fileManager.createDirectory(at: frameworksFolderPath, withIntermediateDirectories: true)
            }.value
            await MainActor.run {
                ToastManager.shared.showToast.success("Created Frameworks directory")
            }
        }
        
        if let fileURL = Bundle.main.url(forResource: "CydiaSubstrate", withExtension: "framework") {
            try await copyFramework(from: fileURL, to: frameworksFolderPath, name: "CydiaSubstrate.framework")
        }
        
        if let fileURL = Bundle.main.url(forResource: "libsubstrate", withExtension: "dylib") {
            try await copyFramework(from: fileURL, to: frameworksFolderPath, name: "libsubstrate.dylib")
        }
        
        let (dylibCount, frameworkCount) = await Task.detached(priority: .background) {
            var dylibs = 0
            var frameworks = 0
            
            let enumerator = FileManager.default.enumerator(at: fullAppPath, includingPropertiesForKeys: nil)
            
            while let element = enumerator?.nextObject() as? URL {
                if element.pathExtension == "dylib" {
                    dylibs += 1
                } else if element.pathExtension == "framework" {
                    frameworks += 1
                }
            }
            return (dylibs, frameworks)
        }.value
        
        await MainActor.run {
            ToastManager.shared.showToast.warning("Found \(dylibCount) dylibs and \(frameworkCount) frameworks")
            ToastManager.shared.showToast.warning("Total items to sign: \(dylibCount + frameworkCount + 1)")
            sideloadingViewModel?.totalTweaks = (dylibCount + frameworkCount + 1)
        }
    }
    
    private static func copyFramework(from sourceURL: URL, to destinationFolder: URL, name: String) async throws {
        let fileManager = FileManager.default
        let destinationURL = destinationFolder.appendingPathComponent(name)
        
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try await Task.detached(priority: .background) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }.value
            await MainActor.run {
                ToastManager.shared.showToast.success("Copied \(name) successfully")
            }
        } else {
            await MainActor.run {
                ToastManager.shared.showToast.success("\(name) already exists")
            }
        }
    }
}