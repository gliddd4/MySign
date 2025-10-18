//
//  TimerManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

@MainActor
class TimerManager: ObservableObject {
    @Published var fileSizeMB: Float = 0
    @Published var signingTime: Float = 0
    @Published var finalSigningTime: Float = 0
    
    private var timer: Timer?
    private var startTime: Date?
    private var fileURL: URL?
    
    func startTimer(fileURL: URL) async {
        self.fileURL = fileURL
        startTime = Date()
        
        ToastManager.shared.showToast.silentWarning("Tracking signing progress")
        
        do {
            let fileSize = try FileUtilities.fileSizeForURL(fileURL)
            ToastManager.shared.showToast.silentWarning("File size \(String(format: "%.1f", fileSize))MB")
            fileSizeMB = fileSize
            signingTime = calculateSigningTime(fileSize: fileSize) + 0.5
        } catch {
            ToastManager.shared.showToast.error("Could not get initial file size")
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let fileURL = self.fileURL else { return }
                if let fileSize = try? FileUtilities.fileSizeForURL(fileURL) {
                    self.fileSizeMB = fileSize
                    // Removed periodic size logging to reduce toast spam
                } else {
                    ToastManager.shared.showToast.error("Could not read file size")
                }
            }
        }
    }
    
    func stopTimer() {
        if let startTime = startTime {
            finalSigningTime = Float(Date().timeIntervalSince(startTime))
            ToastManager.shared.showToast.silentSuccess("Signing process completed")
        }
        timer?.invalidate()
        timer = nil
        startTime = nil
        fileURL = nil
    }
    
    func resetTimers() {
        stopTimer()
        fileSizeMB = 0
        signingTime = 0
        finalSigningTime = 0
        ToastManager.shared.showToast.warning("Timers reset")
    }
    
    private func calculateSigningTime(fileSize: Float) -> Float {
        return Float(0.0126) * fileSize
    }
}
