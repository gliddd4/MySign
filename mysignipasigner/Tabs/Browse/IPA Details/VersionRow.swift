//
//  VersionRow.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit

struct VersionRow: View {
    let version: AppVersion
    let themeAccent: Theme
    let appName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version \(version.version)")
                        .fontWeight(.medium)
                    if let date = version.date {
                        Text("Released: \(date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let size = version.size {
                        Text(formatSize(size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let downloadURL = version.downloadURL,
                   let url = URL(string: downloadURL) {
                    Button(action: {
                        ToastManager.shared.showToast.log("Clicked Download version \(version.version) for \(appName)")
                        UIApplication.shared.open(url)
                    }) {
                        Image("downloaddark")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                            .foregroundColor(themeAccent.accentColor)
                    }
                }
            }
            
            if let versionDescription = version.versionDescription {
                Text(versionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}