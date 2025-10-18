//
//  DownloadRowView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct DownloadRowView: View {
    @ObservedObject var download: IPADownload
    @Binding var currentDate: Date
    
    var body: some View {
        NavigationLink(destination: DownloadIPADetailsWrapper(app: download.app)) {
            DownloadRowContent(download: download, currentDate: $currentDate)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DownloadRowContent: View {
    @ObservedObject var download: IPADownload
    @ObservedObject private var themeManager = Theme.shared
    @AppStorage("app_hideDescriptions") private var hideAppDescriptions = false
    @Binding var currentDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Regular app icon instead of progress icon view
                AppIconView(app: download.app)
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(download.app.name)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.body)
                    
                    metadataView
                }
                
                Spacer()
                
            }
            
            if !hideAppDescriptions, let description = download.app.localizedDescription, !description.isEmpty {
                Text(truncatedDescription(description))
                    .foregroundColor(.gray)
                    .font(.caption)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if download.hasError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download failed")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    
                    if let errorMessage = download.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            } else if download.isCompleted && download.showCompletedStatus {
                HStack {
                    Text("Download completed")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if download.totalBytes > 0 {
                        Text(formatFileSize(download.totalBytes))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !download.isCompleted && !download.hasError {
                HStack(spacing: 8) {
                    // Progress percentage
                    Text("\(Int(max(0, download.progress * 100)))%")
                        .font(.caption)
                        .foregroundColor(themeManager.accentColor)
                        .fontWeight(.medium)
                        .frame(minWidth: 30, alignment: .leading)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 6)
                            
                            // Progress bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(themeManager.accentColor)
                                .frame(width: geometry.size.width * CGFloat(max(0.01, min(1.0, download.progress))), height: 6)
                                .animation(.easeInOut(duration: 0.2), value: download.progress)
                        }
                    }
                    .frame(height: 6)
                    
                    // Download speed
                    if download.downloadSpeed > 0.01 {
                        Text("\(formatSpeed(download.downloadSpeed))")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor.opacity(0.8))
                            .frame(minWidth: 50, alignment: .trailing)
                    } else if download.bytesDownloaded > 1000 {
                        Text("Calculating...")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor.opacity(0.5))
                            .frame(minWidth: 50, alignment: .trailing)
                    } else {
                        Text("Starting...")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor.opacity(0.5))
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private var metadataView: some View {
        HStack(spacing: 4) {
            if let versionDate = download.app.versionDate, let date = DateFormatting.parseDate(versionDate) {
                Text(DateFormatting.formatRelativeDate(date))
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            if let version = download.app.version {
                Text(versionText(version))
                    .foregroundColor(.gray)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
    
    private func versionText(_ version: String) -> String {
        if download.app.versionDate != nil {
            return " - \(version)"
        } else {
            return version
        }
    }
    
    private func truncatedDescription(_ description: String) -> String {
        if description.count > 750 {
            let index = description.startIndex..<description.index(description.startIndex, offsetBy: 750)
            return String(description[index]) + "..."
        }
        return description
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1.0 {
            return String(format: "%.1f MB/s", mbps)
        } else if mbps >= 0.1 {
            return String(format: "%.2f MB/s", mbps)
        } else if mbps >= 0.01 {
            return String(format: "%.3f MB/s", mbps)
        } else {
            let kbps = mbps * 1024
            if kbps >= 1 {
                return String(format: "%.0f KB/s", kbps)
            } else {
                return String(format: "%.1f KB/s", kbps)
            }
        }
    }
    
    private func calculateETA() -> String? {
        guard download.downloadSpeed > 0.01 else { return nil }
        
        let totalBytes: Int64
        if download.totalBytes > 0 {
            totalBytes = download.totalBytes
        } else if let appSize = download.app.size, appSize > 0 {
            totalBytes = Int64(appSize)
        } else {
            return nil
        }
        
        let remainingBytes = totalBytes - download.bytesDownloaded
        guard remainingBytes > 0 else { return nil }
        
        let remainingMB = Double(remainingBytes) / (1024 * 1024)
        let eta = remainingMB / download.downloadSpeed
        
        if eta < 60 {
            return "\(Int(eta))s"
        } else if eta < 3600 {
            let minutes = Int(eta / 60)
            let seconds = Int(eta.truncatingRemainder(dividingBy: 60))
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            let hours = Int(eta / 3600)
            let minutes = Int((eta.truncatingRemainder(dividingBy: 3600)) / 60)
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}

struct DownloadIPADetailsWrapper: View {
    let app: App
    
    var body: some View {
        IPADetailsView(app: app)
            .onAppear {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.log("Opened \(app.name) from Downloads")
            }
    }
}