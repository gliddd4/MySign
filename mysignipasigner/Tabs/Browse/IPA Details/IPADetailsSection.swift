//
//  IPADetailsSection.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct IPADetailsSection: View {
    let app: App
    
    var body: some View {

        if let developerName = app.developerName {
            CompactInfoRow(title: "Developer:", content: developerName)
        }
        
        // Descriptions
        if let description = app.displayDescription {
            CompactInfoRow(title: "Description:", content: description)
        }
        
        if let localizedDescription = app.localizedDescription,
           localizedDescription != app.displayDescription {
            CompactInfoRow(title: "Localized Description:", content: localizedDescription)
        }
        
        if let title = app.title {
            CompactInfoRow(title: "Title:", content: title)
        }

        if let category = app.category {
            CompactInfoRow(title: "Category:", content: category)
        }
        
        // Boolean/Numeric Properties
        if let beta = app.beta {
            CompactInfoRow(title: "Beta:", content: beta ? "Yes" : "No")
        }
        
        if let type = app.type {
            CompactInfoRow(title: "Type:", content: String(type))
        }
        
        
        // Arrays
        if let screenshotURLs = app.screenshotURLs, !screenshotURLs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(screenshotURLs.count)")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary) +
                Text(" Screenshot\(screenshotURLs.count == 1 ? "" : "s")")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                ScreenshotGallery(screenshotURLs: screenshotURLs)
            }
        }

        // Current Version Description (only for the main version)
        if let versionDescription = app.versionDescription {
            CompactInfoRow(title: "Current Version Notes:", content: versionDescription)
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func versionDisplayText(version: String, date: String?) -> String {
        if let date = date {
            return "\(version) (\(date))"
        } else {
            return version
        }
    }
}