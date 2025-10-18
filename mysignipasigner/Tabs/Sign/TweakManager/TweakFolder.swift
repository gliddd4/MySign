//
//  TweakFolder.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

struct TweakFolder {
    let name: String
    let fileURL: URL
    let fileType: TweakFileType
    let fileSize: Int64
    let isValid: Bool
    
    enum TweakFileType: String, CaseIterable {
        case dylib = "dylib"
        case deb = "deb"
        
        var displayName: String {
            switch self {
            case .dylib:
                return ".dylib"
            case .deb:
                return ".deb"
            }
        }
        
        var systemIcon: String {
            switch self {
            case .dylib:
                return "gearshape.fill"
            case .deb:
                return "shippingbox.fill"
            }
        }
    }
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.name = fileURL.deletingPathExtension().lastPathComponent
        
        let pathExtension = fileURL.pathExtension.lowercased()
        self.fileType = TweakFileType(rawValue: pathExtension) ?? .dylib
        
        // Check if file is valid and get size
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                self.fileSize = attributes[.size] as? Int64 ?? 0
                self.isValid = fileSize > 0
            } catch {
                self.fileSize = 0
                self.isValid = false
            }
        } else {
            self.fileSize = 0
            self.isValid = false
        }
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}