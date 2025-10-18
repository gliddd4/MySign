import SwiftUI
import UIKit
// Import for date formatting
import Foundation

struct IPADetailsView: View {
    let app: App
    
    @EnvironmentObject var themeAccent: Theme
    
    @State private var isDownloadPressed = false
    @State private var isSharePressed = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadAlert: DownloadAlert?
    @StateObject private var downloadManager = FileDownloadManager()
    @ObservedObject private var globalDownloadManager = DownloadManager.shared
    @State private var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    @State private var selectedDetailTab: DetailTab = .details
    @State private var showJSONSheet = false
    @State private var jsonText = ""
    @State private var hideVersionDescriptions = false
    
    @EnvironmentObject private var tabSelectionManager: TabSelectionManager
    
    private var effectiveDownloadURL: String? {
        app.downloadURL ?? app.versions?.first?.downloadURL
    }
    
    private var downloadButtonText: String {
        let sizeText = formatFileSize(app.size)
        
        if isDownloading {
            if downloadProgress < 0 {
                return "Downloading..." // Indeterminate progress
            } else {
                let downloadedSize = formatFileSize(downloadProgress * (app.size ?? 0))
                return "Downloading \(downloadedSize)/\(sizeText)"
            }
        } else {
            if !sizeText.isEmpty {
                return "Download (\(sizeText))"
            } else {
                return "Download"
            }
        }
    }

    private func formatFileSize(_ bytes: Double?) -> String {
        guard let bytes = bytes, bytes > 0 else { return "" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        actionsSection
                        openInSection
                        detailsSection
                        screenshotsSection
                        versionHistorySection
                        jsonSection
                    }
                    .padding(.vertical, 20)
                }
                .safeAreaInset(edge: .top) {
                    Color.clear
                        .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 10)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: 34)
                }
            }
            
            navigationBar
        }
        .navigationBarHidden(true)
        .onAppear {
            ToastManager.shared.showToast.log("Opened \(app.name)")
            setupPopGesture()
        }
        .onDisappear {
            restorePopGesture()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var actionsSection: some View {
        if let downloadURL = effectiveDownloadURL {
            VStack(spacing: 12) {
                HStack {
                    Text("ACTIONS")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    SplitMainButton(
                        left: (title: downloadButtonText, icon: "arrow.down.app", action: {
                            ToastManager.shared.showToast.log("Clicked Download for \(app.name)")
                            downloadAndSaveFile(from: URL(string: downloadURL)!)
                            tabSelectionManager.selectTab(3) // Downloads tab is index 3
                        }),
                        right: (title: "Share", icon: "square.and.arrow.up", action: {
                            ToastManager.shared.showToast.log("Clicked Share for \(app.name)")
                            shareFile(from: URL(string: downloadURL)!)
                        })
                    )
                    .opacity(isDownloading ? 0.6 : 1.0)
                    .disabled(isDownloading)
                    .padding(.horizontal)
                }
                .environmentObject(themeAccent)
            }
        }
    }
    
    @ViewBuilder
    private var openInSection: some View {
        if let downloadURL = effectiveDownloadURL {
            VStack(spacing: 12) {
                HStack {
                    Text("OPEN IN")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    TripleSplitMainButton(
                        left: (title: "SideStore", customImage: "sidestore", action: {
                            ToastManager.shared.showToast.log("Clicked Open in SideStore for \(app.name)")
                            if let encodedURL = downloadURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let sideStoreURL = URL(string: "sidestore://install?url=\(encodedURL)") {
                                UIApplication.shared.open(sideStoreURL)
                            }
                        }),
                        middle: (title: "AltStore", customImage: "altstore", action: {
                            ToastManager.shared.showToast.log("Clicked Open in AltStore for \(app.name)")
                            if let encodedURL = downloadURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let altStoreURL = URL(string: "altstore://install?url=\(encodedURL)") {
                                UIApplication.shared.open(altStoreURL)
                            }
                        }),
                        right: (title: "Safari", icon: "safari", action: {
                            ToastManager.shared.showToast.log("Clicked Open in Safari for \(app.name)")
                            if let url = URL(string: downloadURL) {
                                UIApplication.shared.open(url)
                            }
                        })
                    )
                    .padding(.horizontal)
                }
                .environmentObject(themeAccent)
            }
        }
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("DETAILS")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            ConnectedLabelGroup {
                detailsContent
            }
            .environmentObject(themeAccent)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var detailsContent: some View {
        // Bundle ID
        ConnectedUniversalLabel("Bundle ID")
            .withIcon("app.badge")
            .withValue(app.bundleIdentifier)
        
        // Version
        if let version = app.version {
            ConnectedUniversalLabel("Version")
                .withIcon("number")
                .withValue(version)
        }
        
        // Updated Date
        if let versionDate = app.versionDate, let date = DateFormatting.parseDate(versionDate) {
            ConnectedUniversalLabel("Updated")
                .withIcon("clock.arrow.circlepath")
                .withValue(DateFormatting.formatRelativeDate(date))
        }
        
        // Size
        if let size = app.size {
            ConnectedUniversalLabel("Size")
                .withIcon("archivebox")
                .withValue(formatFileSize(size))
        }
        
        // Developer
        if let developerName = app.developerName {
            ConnectedUniversalLabel("Developer")
                .withIcon("person")
                .withValue(developerName)
        }
        
        // Category
        if let category = app.category {
            ConnectedUniversalLabel("Category")
                .withIcon("folder")
                .withValue(category)
        }
        
        // Title
        if let title = app.title {
            ConnectedUniversalLabel("Title")
                .withIcon("textformat")
                .withValue(title)
        }
        
        // Beta
        if let beta = app.beta {
            ConnectedUniversalLabel("Beta")
                .withIcon("exclamationmark.triangle")
                .withValue(beta ? "Yes" : "No")
        }
        
        // Type
        if let type = app.type {
            ConnectedUniversalLabel("Type")
                .withIcon("gear")
                .withValue(String(type))
        }
        
        // Description
        if let description = app.displayDescription {
            ConnectedUniversalLabel("Description")
                .withIcon("text.alignleft")
                .withDescription(description)
        }
        
        // Localized Description
        if let localizedDescription = app.localizedDescription,
           localizedDescription != app.displayDescription {
            ConnectedUniversalLabel("Localized Description")
                .withIcon("globe")
                .withDescription(localizedDescription)
        }
        
        // Version Notes - this should be the last item in the connected group
        if let versionDescription = app.versionDescription {
            ConnectedUniversalLabel("Version Notes")
                .withIcon("note.text")
                .withDescription(versionDescription)
                .lastConnectedItem()
        }
    }
    
    @ViewBuilder
    private var screenshotsSection: some View {
        if let screenshotURLs = app.screenshotURLs, !screenshotURLs.isEmpty {
            ScreenshotGallery(screenshotURLs: screenshotURLs)
        }
    }
    
    @ViewBuilder
    private var versionHistorySection: some View {
        if let versions = app.versions,
           versions.contains(where: { version in version.version != app.version }) {
            VStack(spacing: 12) {
                HStack {
                    Text("VERSION HISTORY")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                
                ConnectedLabelGroup {
                    versionHistoryContent(versions: versions)
                }
                .environmentObject(themeAccent)
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func versionHistoryContent(versions: [AppVersion]) -> some View {
        ConnectedUniversalLabel("Hide descriptions")
            .withIcon("eye.slash")
            .withToggle($hideVersionDescriptions)
        
        let otherVersions = versions.filter { version in
            version.version != app.version
        }
        
        ForEach(Array(otherVersions.enumerated()), id: \.element.version) { index, version in
            let isLast = index == otherVersions.count - 1
            
            ConnectedUniversalLabel(version.version)
                .withIcon("number.circle")
                .withDescription(hideVersionDescriptions ? shortVersionDescription(for: version) : versionDescription(for: version))
                .withButton(UniversalButton.ButtonContent.icon("arrow.down.app"), action: {
                    ToastManager.shared.showToast.log("Clicked Download version \(version.version) for \(app.name)")
                    if let downloadURL = version.downloadURL,
                       let url = URL(string: downloadURL) {
                        UIApplication.shared.open(url)
                    }
                })
                .if(isLast) { view in
                    view.lastConnectedItem()
                }
        }
    }
    
    @ViewBuilder
    private var jsonSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("JSON DATA")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            ConnectedLabelGroup {
                ConnectedUniversalLabel("Copy JSON Data")
                    .withIcon("doc.text")
                    .withButton(UniversalButton.ButtonContent.icon("doc.on.clipboard"), action: {
                        copyJSONToClipboard()
                    })
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text("JSON Data")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(height: 36)
                    
                    //JSONTextView(jsonText: jsonText.isEmpty ? generateJSONTextSync() : jsonText)
                      //  .onAppear {
                        //    if jsonText.isEmpty {
                          //      jsonText = generateJSONTextSync()
                            //}
                    //}
                }
                .connectedLabelItem()
            }
            .environmentObject(themeAccent)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var navigationBar: some View {
        NavigationManager.customNavigation(
            title: "",
            leadingItems: [
                NavigationItem(icon: "chevron.left", name: "Back", action: {
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in \(app.name)")
                    // Navigate back
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let navigationController = window.rootViewController as? UINavigationController ??
                       window.rootViewController?.children.first as? UINavigationController {
                        navigationController.popViewController(animated: true)
                    }
                })
            ]
        ) {
            IPADetailsPillSwitcher(selection: $selectedDetailTab, themeAccent: themeAccent, appName: app.name, app: app)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupPopGesture() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController as? UINavigationController ??
           window.rootViewController?.children.first as? UINavigationController {
            self.originalPopGestureDelegate = navigationController.interactivePopGestureRecognizer?.delegate
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
    
    private func restorePopGesture() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController as? UINavigationController ??
           window.rootViewController?.children.first as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.delegate = self.originalPopGestureDelegate
        }
    }
    
    private func versionDescription(for version: AppVersion) -> String {
        var parts: [String] = []
        
        // Add metadata at the top
        if let date = version.date {
            parts.append("Released: \(date)")
        }
        
        if let size = version.size {
            parts.append("Size: \(formatFileSize(Double(size)))")
        }
        
        // Add detailed version description after metadata with newline separator
        if let localizedDescription = version.localizedDescription, !localizedDescription.isEmpty {
            if !parts.isEmpty {
                parts.append("") // Empty string creates a newline
            }
            parts.append(localizedDescription)
        } else if let versionDescription = version.versionDescription, !versionDescription.isEmpty {
            if !parts.isEmpty {
                parts.append("") // Empty string creates a newline
            }
            parts.append(versionDescription)
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func shortVersionDescription(for version: AppVersion) -> String {
        var parts: [String] = []
        
        // Add metadata only when descriptions are hidden
        if let date = version.date {
            parts.append("Released: \(date)")
        }
        
        if let size = version.size {
            parts.append("Size: \(formatFileSize(Double(size)))")
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func copyJSONToClipboard() {
        jsonText = generateJSONTextSync()
        UIPasteboard.general.string = jsonText
        ToastManager.shared.showToast.success("JSON copied to clipboard")
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Copied JSON for \(app.name)")
    }
    
    private func generateJSONTextSync() -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(app)
            return String(data: data, encoding: .utf8) ?? "Unable to format JSON"
        } catch {
            return "Error encoding JSON: \(error.localizedDescription)"
        }
    }
    
    private func downloadAndSaveFile(from url: URL) {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        ToastManager.shared.showToast.log("Starting download for \(url.absoluteString)")
        
        let trackedDownload = globalDownloadManager.addDownload(for: app, url: url)
        
        downloadManager.setTrackedDownload(trackedDownload)
        
        // Generate filename from app name or URL
        let originalFilename = "\(app.name).ipa"
        
        downloadManager.downloadFile(url: url, originalFilename: originalFilename) { progress in
            Task { @MainActor in
                downloadProgress = progress
            }
        } completion: { result in
            Task { @MainActor in
                isDownloading = false
                downloadProgress = 0.0
                
                switch result {
                case .success(let message):
                    ToastManager.shared.showToast.success(message)
                    ToastManager.shared.showToast.log("Download completed successfully: \(message)")
                    globalDownloadManager.markCompleted(for: trackedDownload.id)
                case .failure(let error):
                    ToastManager.shared.showToast.error(error.localizedDescription)
                    ToastManager.shared.showToast.log("Download failed with error: \(error.localizedDescription)")
                    globalDownloadManager.markError(for: trackedDownload.id, error: error.localizedDescription)
                }
            }
        }
    }
    
    private func shareFile(from url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}
