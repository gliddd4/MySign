//
//  DownloadsView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Combine

struct DownloadsView: View {
    @ObservedObject private var themeManager = Theme.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var currentDate = Date()
    @State private var loadedIcons: [String: UIImage] = [:]
    @State private var loadingIcons: Set<String> = []
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if downloadManager.allDownloads.isEmpty {
                    emptyStateView
                } else {
                    downloadsList
                }
            }
            .background(backgroundView)
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 20)
            }
            
            NavigationManager.customNavigation(
                title: "Downloads",
                trailingItems: [
                    NavigationItem(icon: "trash", name: "Clear", action: {
                        ToastManager.shared.showToast.log("Clicked Clear (toolbar) in Downloads")
                        downloadManager.clearCompletedDownloads()
                        ToastManager.shared.showToast.success("Cleared download history")
                    })
                ]
            )
            .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
    
    private var backgroundView: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }
    
    private var emptyStateView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                downloadSection(
                    title: "NO DOWNLOADS",
                    downloads: []
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var downloadsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !downloadManager.activeDownloads.isEmpty {
                    downloadSection(
                        title: "DOWNLOADING",
                        downloads: downloadManager.activeDownloads
                    )
                }
                
                ForEach(groupedCompletedDownloads, id: \.0) { group in
                    downloadSection(
                        title: group.0,
                        downloads: group.1
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private func downloadSection(title: String, downloads: [IPADownload]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .secondaryHeader()
                Spacer()
            }
            
            if downloads.isEmpty && title == "NO DOWNLOADS" {
                ConnectedLabelGroup {
                    ConnectedUniversalLabel("Your downloads will appear here")
                        .lastConnectedItem()
                }
                .environmentObject(themeManager)
            } else {
                ConnectedLabelGroup {
                    ForEach(Array(downloads.enumerated()), id: \.element.id) { index, download in
                        downloadRow(download: download, isLast: index == downloads.count - 1)
                    }
                }
                .environmentObject(themeManager)
            }
        }
    }
    
    @ViewBuilder
    private func downloadRow(download: IPADownload, isLast: Bool) -> some View {
        NavigationLink(destination: DownloadIPADetailsWrapper(app: download.app)) {
            downloadRowContent(download: download, isLast: isLast)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            HapticManager.shared.medium()
            ToastManager.shared.showToast.log("Opened \(download.app.name) from Downloads")
        })
        .onAppear {
            loadAppIconIfNeeded(for: download.app)
        }
    }
    
    private func downloadRowContent(download: IPADownload, isLast: Bool) -> some View {
        if isLast {
            ConnectedUniversalLabel(download.app.name)
                .withBigCustomIconTitleDescriptionAndSecondDescription(
                    metadataString(for: download),
                    statusString(for: download),
                    customIcon: loadedIcons[download.app.id],
                    iconSize: 40,
                    cornerRadius: 8
                )
                .lastConnectedItem()
        } else {
            ConnectedUniversalLabel(download.app.name)
                .withBigCustomIconTitleDescriptionAndSecondDescription(
                    metadataString(for: download),
                    statusString(for: download),
                    customIcon: loadedIcons[download.app.id],
                    iconSize: 40,
                    cornerRadius: 8
                )
        }
    }
    
    private func loadAppIconIfNeeded(for app: App) {
        // Don't load if already loaded or currently loading
        guard loadedIcons[app.id] == nil && !loadingIcons.contains(app.id) else { return }
        
        // Don't load if no iconURL
        guard let iconURLString = app.iconURL,
              let iconURL = URL(string: iconURLString) else { return }
        
        loadingIcons.insert(app.id)
        
        Task {
            do {
                let session = URLSession.shared
                var request = URLRequest(url: iconURL)
                request.timeoutInterval = 5.0
                request.cachePolicy = .returnCacheDataElseLoad
                
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode != 200 {
                    throw URLError(.badServerResponse)
                }
                
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        loadedIcons[app.id] = uiImage
                        loadingIcons.remove(app.id)
                    }
                } else {
                    throw URLError(.cannotDecodeContentData)
                }
            } catch {
                await MainActor.run {
                    loadingIcons.remove(app.id)
                    // Icon loading failed, but we don't set a fallback here
                    // The UniversalComponents will handle the nil case with a default icon
                }
            }
        }
    }
    
    private func metadataString(for download: IPADownload) -> String {
        var components: [String] = []
        
        if let versionDate = download.app.versionDate,
           let date = DateFormatting.parseDate(versionDate) {
            components.append(DateFormatting.formatRelativeDate(date))
        }
        
        if let version = download.app.version {
            if components.isEmpty {
                components.append(version)
            } else {
                components.append(" - \(version)")
            }
        }
        
        return components.joined()
    }
    
    private func statusString(for download: IPADownload) -> String {
        if download.hasError {
            var statusText = "Download failed"
            if let errorMessage = download.errorMessage {
                statusText += ": \(errorMessage)"
            }
            return statusText
        } else if download.isCompleted && download.showCompletedStatus {
            var statusText = "Download completed"
            if download.totalBytes > 0 {
                statusText += " • \(formatFileSize(download.totalBytes))"
            }
            return statusText
        } else if !download.isCompleted {
            let progress = Int(max(0, download.progress * 100))
            var statusText = "\(progress)% "
            
            if download.downloadSpeed > 0.01 {
                statusText += "• \(formatSpeed(download.downloadSpeed))"
            } else if download.bytesDownloaded > 1000 {
                statusText += "• Calculating..."
            } else {
                statusText += "• Starting..."
            }
            
            return statusText
        }
        
        // Default case - shouldn't normally hit this
        return ""
    }
    
    @AppStorage("app_hideDescriptions") private var hideAppDescriptions = false
    
    private func shouldShowDescription(for download: IPADownload) -> Bool {
        guard !hideAppDescriptions else { return false }
        guard let description = download.app.localizedDescription else { return false }
        return !description.isEmpty
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
    
    private var groupedCompletedDownloads: [(String, [IPADownload])] {
        let grouped = Dictionary(grouping: downloadManager.completedDownloads) { download in
            // Group by 5-minute intervals
            let timeInterval = currentDate.timeIntervalSince(download.downloadDate)
            let fiveMinuteIntervals = Int(timeInterval / 300) // 300 seconds = 5 minutes
            return fiveMinuteIntervals
        }
        
        return grouped.map { (intervalCount, downloads) in
            let headerText = formatFiveMinuteInterval(intervalCount: intervalCount).uppercased()
            return (headerText, downloads.sorted { $0.downloadDate > $1.downloadDate })
        }.sorted { $0.1.first?.downloadDate ?? Date.distantPast > $1.1.first?.downloadDate ?? Date.distantPast }
    }
    
    private func formatFiveMinuteInterval(intervalCount: Int) -> String {
        if intervalCount == 0 {
            return "Just now"
        } else if intervalCount == 1 {
            return "5 minutes ago"
        } else if intervalCount < 12 { // Less than 1 hour (12 * 5 minutes)
            let minutes = intervalCount * 5
            return "\(minutes) minutes ago"
        } else if intervalCount < 288 { // Less than 1 day (288 * 5 minutes)
            let hours = intervalCount / 12
            let remainingIntervals = intervalCount % 12
            
            if remainingIntervals == 0 {
                return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
            } else {
                let minutes = remainingIntervals * 5
                if hours == 1 {
                    return "1 hour and \(minutes) minutes ago"
                } else {
                    return "\(hours) hours and \(minutes) minutes ago"
                }
            }
        } else {
            let days = intervalCount / 288
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
}
