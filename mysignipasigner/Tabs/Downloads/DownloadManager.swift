//
//  DownloadManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import SwiftUI

// Codable wrapper for IPADownload to support persistence
struct PersistedDownload: Codable {
    let id: UUID
    let app: App  // Store the full App object instead of minimal fields
    let url: URL
    let isCompleted: Bool
    let hasError: Bool
    let errorMessage: String?
    let downloadDate: Date
    let showCompletedStatus: Bool
    
    init(from download: IPADownload) {
        self.id = download.id
        self.app = download.app  // Store the complete App object
        self.url = download.url
        self.isCompleted = download.isCompleted
        self.hasError = download.hasError
        self.errorMessage = download.errorMessage
        self.downloadDate = download.downloadDate
        self.showCompletedStatus = download.showCompletedStatus
    }
    
    func toIPADownload() -> IPADownload {
        // Use the complete App object that was persisted
        let download = IPADownload(app: app, url: url)
        download.isCompleted = isCompleted
        download.hasError = hasError
        download.errorMessage = errorMessage
        download.progress = isCompleted ? 1.0 : 0.0
        download.showCompletedStatus = showCompletedStatus
        download.downloadDate = downloadDate
        return download
    }
}

class IPADownload: Identifiable, ObservableObject {
    let id = UUID()
    let app: App
    let url: URL
    @Published var progress: Double = 0.0
    @Published var isCompleted: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published var downloadSpeed: Double = 0.0 // MB/s
    @Published var bytesDownloaded: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var showCompletedStatus: Bool = false
    var downloadDate: Date
    
    private var speedSamples: [Double] = []
    private var lastBytesWritten: Int64 = 0
    private var lastUpdateTime: Date = Date()
    private var startTime: Date = Date()
    private var completedStatusTimer: Timer?
    
    init(app: App, url: URL) {
        self.app = app
        self.url = url
        self.downloadDate = Date()
        self.startTime = Date()
    }
    
    func markAsCompleted() {
        isCompleted = true
        progress = 1.0
        showCompletedStatus = true
        resetSpeed()
        
        // Start timer to hide completed status after 10 seconds
        completedStatusTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.showCompletedStatus = false
            }
        }
    }
    
    func updateBytes(written: Int64, total: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            
            // Update byte counts first
            self.bytesDownloaded = written
            
            // Use app size if server doesn't provide total bytes (total = -1)
            let effectiveTotal: Int64
            if total > 0 {
                effectiveTotal = total
                self.totalBytes = total
            } else if let appSize = self.app.size, appSize > 0 {
                // Use app size from repository data (convert from Double to Int64)
                effectiveTotal = Int64(appSize)
                self.totalBytes = effectiveTotal
            } else {
                // No size info available, use indeterminate progress
                effectiveTotal = -1
                self.totalBytes = total
            }
            
            // Calculate progress
            if effectiveTotal > 0 && written > 0 {
                self.progress = Double(written) / Double(effectiveTotal)
            } else if written > 0 {
                // Indeterminate progress - show 10% to indicate activity
                self.progress = 0.1
            } else {
                self.progress = 0.0
            }
            
            let timeDiff = now.timeIntervalSince(self.lastUpdateTime)
            
            if timeDiff > 0.2 && self.lastBytesWritten > 0 && written > self.lastBytesWritten {
                let bytesDiff = written - self.lastBytesWritten
                let bytesPerSecond = Double(bytesDiff) / timeDiff
                let mbPerSecond = bytesPerSecond / (1024 * 1024)
                
                self.speedSamples.append(mbPerSecond)
                if self.speedSamples.count > 3 {
                    self.speedSamples.removeFirst()
                }
                
                self.downloadSpeed = self.speedSamples.reduce(0, +) / Double(self.speedSamples.count)
                
                self.lastBytesWritten = written
                self.lastUpdateTime = now
            } else if self.lastBytesWritten == 0 && written > 0 {
                self.lastBytesWritten = written
                self.lastUpdateTime = now
            }
        }
    }
    
    func resetSpeed() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadSpeed = 0.0
            self.speedSamples.removeAll()
        }
    }
    
    deinit {
        completedStatusTimer?.invalidate()
    }
}

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var isLoading = false
    @Published var activeDownloads: [IPADownload] = []
    // Persist every change automatically
    @Published var completedDownloads: [IPADownload] = [] {
        didSet { saveCompletedDownloads() }
    }
    
    private let userDefaults = UserDefaults.standard
    private let completedDownloadsKey = "CompletedDownloads"
    
    init() {
        loadCompletedDownloads()
    }
    
    func downloadJSON(for repository: RepositoryFormat, viewModel: RepositoryViewModel) async {
        do {
            isLoading = true
            let json = try await viewModel.fetchRepositoryJSON(for: repository)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            
            let filename = "\(repository.name)-\(dateString).json"
            
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "com.mysignipasigner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not access Documents directory"])
            }
            
            let jsonDirectory = documentsDirectory.appendingPathComponent("Repository JSON")
            
            do {
                try FileManager.default.createDirectory(
                    at: jsonDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                
                var url = jsonDirectory
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try url.setResourceValues(resourceValues)
                
                let fileURL = jsonDirectory.appendingPathComponent(filename)
                try json.write(to: fileURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    isLoading = false
                    ToastManager.shared.showToast.success("Downloaded File")
                    
                    // Automatically switch to the Files tab (index 1) after a successful JSON download
                    TabSelectionManager.shared.selectTab(1)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: .init("ExpandRepositoryJSONFolder"), object: nil)
                    }
                }
            } catch {
                throw NSError(
                    domain: "com.mysignipasigner",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create directory or save file: \(error.localizedDescription)"]
                )
            }
        } catch {
            await MainActor.run {
                isLoading = false
                ToastManager.shared.showToast.error("Download failed: \(error.localizedDescription)")
            }
        }
    }
    
    func addDownload(for app: App, url: URL) -> IPADownload {
        let download = IPADownload(app: app, url: url)
        activeDownloads.append(download)
        return download
    }
    
    func removeDownload(_ download: IPADownload) {
        activeDownloads.removeAll { $0.id == download.id }
    }
    
    /// Update download progress with bytes information for speed calculation
    func updateProgress(for downloadId: UUID, progress: Double) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let index = self.activeDownloads.firstIndex(where: { $0.id == downloadId })
            else { return }
            
            self.activeDownloads[index].progress = max(0.0, min(1.0, progress))
        }
    }
    
    /// Update download progress with detailed byte information for speed tracking
    func updateProgressWithBytes(for downloadId: UUID, bytesWritten: Int64, totalBytes: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let index = self.activeDownloads.firstIndex(where: { $0.id == downloadId })
            else { return }
            
            self.activeDownloads[index].updateBytes(written: bytesWritten, total: totalBytes)
        }
    }
    
    func markCompleted(for downloadId: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let index = self.activeDownloads.firstIndex(where: { $0.id == downloadId })
            else { return }
            
            self.activeDownloads[index].markAsCompleted()
            
            let finished = self.activeDownloads[index]
            self.completedDownloads.insert(finished, at: 0)
            self.activeDownloads.remove(at: index)
        }
    }
    
    func markError(for downloadId: UUID, error: String) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let index = self.activeDownloads.firstIndex(where: { $0.id == downloadId })
            else { return }
            
            self.activeDownloads[index].hasError     = true
            self.activeDownloads[index].errorMessage = error
            self.activeDownloads[index].resetSpeed()
            
            let failed = self.activeDownloads[index]
            self.completedDownloads.insert(failed, at: 0)
            self.activeDownloads.remove(at: index)
        }
    }
    
    func clearCompletedDownloads() {
        completedDownloads.removeAll()          // didSet → saveCompletedDownloads() ⟶ empties the key
    }
    
    var allDownloads: [IPADownload] {
        return activeDownloads + completedDownloads
    }
    
    private func saveCompletedDownloads() {
        let persistedDownloads = completedDownloads.map { PersistedDownload(from: $0) }
        
        do {
            let data = try JSONEncoder().encode(persistedDownloads)
            userDefaults.set(data, forKey: completedDownloadsKey)
        } catch {
            print("Failed to save completed downloads: \(error)")
        }
    }
    
    private func loadCompletedDownloads() {
        guard let data = userDefaults.data(forKey: completedDownloadsKey) else { return }
        
        do {
            let persistedDownloads = try JSONDecoder().decode([PersistedDownload].self, from: data)
            completedDownloads = persistedDownloads.map { $0.toIPADownload() }
        } catch {
            print("Failed to load completed downloads: \(error)")
        }
    }
}
