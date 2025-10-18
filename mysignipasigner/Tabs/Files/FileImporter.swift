//
//  FileImporter.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum FileTypeFilter {
    case ipa
    case image
    case dylib
    
    var contentTypes: [UTType] {
        switch self {
        case .ipa:
            // Allow both .ipa and .app files
            return [UTType(filenameExtension: "ipa"), .applicationBundle].compactMap { $0 }
        case .image:
            return [.image]
        case .dylib:
            return ["dylib", "deb"].compactMap { UTType(filenameExtension: $0) }
        }
    }
    
    var label: String {
        switch self {
        case .ipa: return ".ipa"
        case .dylib: return ".dylib"
        case .image: return "Media"
        }
    }
}

@MainActor
class DirectoryViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var isImporting: Bool = false
    @Published var selectedFilter: FileTypeFilter = .ipa
    
    func loadContents(at url: URL) -> [FileItem] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            return contents.compactMap { fileURL -> FileItem? in
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                      let isDirectory = resourceValues.isDirectory else { return nil }
                
                if isDirectory {
                    let subItems = loadContents(at: fileURL)
                    return FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: true, children: subItems)
                } else {
                    return FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: false, children: nil)
                }
            }.sorted { $0.name < $1.name }
        } catch {
            Task { @MainActor in
                ToastManager.shared.showToast.error("Error loading contents at \(url.lastPathComponent): \(error.localizedDescription)")
            }
            return []
        }
    }
    
    func loadDocumentsDirectory() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        DirectoryManager.shared.createAppFolders()
        items = loadContents(at: documentsPath)
    }
    
    private func generateUniqueURL(for baseURL: URL) -> URL {
        let baseDir = baseURL.deletingLastPathComponent()
        let filename = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        
        var index = 1
        var newURL = baseURL
        
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = baseDir.appendingPathComponent("\(filename)_\(index).\(ext)")
            index += 1
        }
        
        return newURL
    }
    
    func isFileInDocuments(_ url: URL) -> Bool {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        return url.path.contains(documentsPath.path)
    }

    func importFile(_ url: URL) async -> (newName: String?, alreadyExists: Bool) {
        if isFileInDocuments(url) {
            return (nil, true)
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            return (nil, false)
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Handle .app to .ipa conversion
        var finalURL = url
        if selectedFilter == .ipa && url.pathExtension.lowercased() == "app" {
            guard let destinationFolder = DirectoryManager.shared.getURL(for: .importedIPAs) else {
                return (nil, false)
            }
            do {
                finalURL = try await IPAParser.createIPAFromAppBundle(appURL: url, destinationDirectory: destinationFolder)
            } catch {
                ToastManager.shared.showToast.error("Failed to convert app bundle to IPA: \(error.localizedDescription)")
                return (nil, false)
            }
        }
        
        // Rest of your import logic remains the same...
        let targetURL: URL?
        switch selectedFilter {
        case .image:
            targetURL = DirectoryManager.shared.getURL(for: .importedMedia)
        case .ipa:
            targetURL = DirectoryManager.shared.getURL(for: .importedIPAs)
        case .dylib:
            targetURL = DirectoryManager.shared.getURL(for: .importedTweaks)
        }
        
        guard let destinationFolder = targetURL else {
            return (nil, false)
        }
        
        let initialDestination = destinationFolder.appendingPathComponent(finalURL.lastPathComponent)
        let destination = generateUniqueURL(for: initialDestination)
        
        do {
            try FileManager.default.moveItem(at: finalURL, to: destination)
            loadDocumentsDirectory()
            return (destination.lastPathComponent, false)
        } catch {
            do {
                try FileManager.default.copyItem(at: finalURL, to: destination)
                loadDocumentsDirectory()
                return (destination.lastPathComponent, false)
            } catch {
                ToastManager.shared.showToast.error("Error importing file: \(error.localizedDescription)")
                return (nil, false)
            }
        }
    }
    
    // Rest of the class remains the same...
}

@MainActor
class FileImporter {
    static func moveIPAToDownloads(_ sourceURL: URL) async {
        guard let downloadsURL = DirectoryManager.shared.getURL(for: .downloads) else {
            ToastManager.shared.showToast.error("Could not access downloads directory")
            return
        }

        let initialDestination = downloadsURL.appendingPathComponent(sourceURL.lastPathComponent)
        let destination = initialDestination
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destination)
        } catch {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destination)
            } catch {
                ToastManager.shared.showToast.error("Error importing file: \(error.localizedDescription)")
            }
        }
    }
}
