//
//  DirectoryManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

@MainActor
class DirectoryManager {
    static let shared = DirectoryManager()
    
    enum AppFolder: String {
        case importedIPAs = "Imported IPAs"
        case importedTweaks = "Imported Tweaks"
        case importedCertificates = "Imported Certificates"
        case importedMedia = "Imported Media"
        case downloads = "Downloads"
        case repositoryIcons = "Repository Icons"
        case repositoryJSON = "Repository JSON"
        case temporaryFiles = "Temporary Files"
        case wallpapers = "Wallpapers"
        
        static var all: [AppFolder] {
            [.importedIPAs, .importedTweaks, .importedCertificates,
             .importedMedia, .downloads, .repositoryIcons,
             .repositoryJSON, .temporaryFiles, .wallpapers]
        }
    }
    
    private init() {}
    
    func createAppFolders() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ToastManager.shared.showToast.error("Cannot access documents directory")
            return
        }
        
        for folder in AppFolder.all {
            let folderPath = documentsDirectory.appendingPathComponent(folder.rawValue)
            
            if !FileManager.default.fileExists(atPath: folderPath.path) {
                do {
                    try FileManager.default.createDirectory(
                        at: folderPath,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    ToastManager.shared.showToast.success("Created directory: \(folder.rawValue)")
                } catch {
                    ToastManager.shared.showToast.error("Error creating \(folder.rawValue) directory: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func getURL(for folder: AppFolder) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(folder.rawValue)
    }
    
    func importIPAFile(from sourceURL: URL) {
        guard let importedIPAsURL = getURL(for: .importedIPAs) else {
            ToastManager.shared.showToast.error("Cannot access Imported IPAs folder")
            return
        }
        
        let fileName = sourceURL.lastPathComponent
        let destinationURL = importedIPAsURL.appendingPathComponent(fileName)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file to Imported IPAs folder
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            ToastManager.shared.showToast.success("IPA imported: \(fileName)")
        } catch {
            ToastManager.shared.showToast.error("Failed to import IPA: \(error.localizedDescription)")
        }
    }
}