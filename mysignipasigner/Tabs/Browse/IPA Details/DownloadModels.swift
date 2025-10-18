//
//  DownloadModels.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

enum DownloadAlert: Identifiable {
    case success(String)
    case failure(String)
    
    var id: String {
        switch self {
        case .success(let message), .failure(let message):
            return message
        }
    }
}

enum DownloadError: Error {
    case noDirectory
    case fileHandling(String)
    case downloadFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .noDirectory:
            return "Could not access Imported IPAs directory"
        case .fileHandling(let message):
            return "File handling error: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}
