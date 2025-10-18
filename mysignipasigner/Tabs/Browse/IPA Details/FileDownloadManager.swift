//
//  FileDownloadManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//
import Foundation
import UIKit

class FileDownloadManager: NSObject, ObservableObject {
    @Published var isDownloading = false
    private var urlSession: URLSession!
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<String, DownloadError>) -> Void)?
    private var currentTrackedDownload: IPADownload?
    private var lastProgressUpdate: Date = Date()

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0  // 60 seconds for initial connection
        config.timeoutIntervalForResource = 3600.0  // 1 hour for entire download
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func setTrackedDownload(_ download: IPADownload) {
        currentTrackedDownload = download
        lastProgressUpdate = Date()
    }
    
    func downloadFile(url: URL, originalFilename: String, progress: @escaping (Double) -> Void, completion: @escaping (Result<String, DownloadError>) -> Void) {
        progressHandler = progress
        completionHandler = completion
        
        DispatchQueue.main.async {
            self.isDownloading = true
        }

        URLSession.shared.downloadTask(with: url) { [weak self] location, response, error in
            DispatchQueue.main.async {
                self?.isDownloading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.downloadFailed(error.localizedDescription)))
                }
                return
            }
            
            guard let location = location else {
                DispatchQueue.main.async {
                    completion(.failure(.downloadFailed("No download location")))
                }
                return
            }
            
            guard FileManager.default.fileExists(atPath: location.path) else {
                DispatchQueue.main.async {
                    completion(.failure(.downloadFailed("Downloaded file not found")))
                }
                return
            }
            
            // Get file size and HTTP info
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let contentType = (response as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String ?? "unknown"
            
            // Get Documents directory
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    completion(.failure(.noDirectory))
                }
                return
            }
            
            // Create "Imported IPAs" subdirectory if it doesn't exist
            let importedIPAsURL = documentsURL.appendingPathComponent("Imported IPAs")
            
            if !FileManager.default.fileExists(atPath: importedIPAsURL.path) {
                do {
                    try FileManager.default.createDirectory(at: importedIPAsURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(.fileHandling("Could not create import directory: \(error.localizedDescription)")))
                    }
                    return
                }
            }
            
            guard FileManager.default.fileExists(atPath: importedIPAsURL.path) else {
                DispatchQueue.main.async {
                    completion(.failure(.noDirectory))
                }
                return
            }
            
            // Generate unique filename if file already exists
            var destinationURL = importedIPAsURL.appendingPathComponent(originalFilename)
            var counter = 1
            
            while FileManager.default.fileExists(atPath: destinationURL.path) {
                let nameWithoutExtension = URL(fileURLWithPath: originalFilename).deletingPathExtension().lastPathComponent
                let fileExtension = URL(fileURLWithPath: originalFilename).pathExtension
                let newFilename = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
                destinationURL = importedIPAsURL.appendingPathComponent(newFilename)
                counter += 1
            }
            
            // Move file to Documents/Imported IPAs
            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
                
                DispatchQueue.main.async {
                    let message = "Downloaded \(destinationURL.lastPathComponent)"
                    completion(.success(message))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.fileHandling("Could not move downloaded file: \(error.localizedDescription)")))
                }
            }
        }.resume()
    }
}

// MARK: - URLSessionDownloadDelegate
extension FileDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Removed
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Removed
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Removed
    }
}