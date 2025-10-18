//
//  ImageLoader.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import UIKit
import Nuke
import SwiftUI

@MainActor
class ImageLoader: ObservableObject {
    @Published private(set) var state = ImageState.empty
    private var task: ImageTask?

    private let pipeline: ImagePipeline = {
        var config = ImagePipeline.Configuration()
        config.dataCache = try? DataCache(name: "com.repository.icons")
        config.dataCachePolicy = .automatic
        config.isProgressiveDecodingEnabled = true
        config.isRateLimiterEnabled = true
        config.imageCache = ImageCache.shared
        return ImagePipeline(configuration: config)
    }()

    func load(url: URL) {
        task?.cancel()

        let request = ImageRequest(url: url)

        ToastManager.shared.showToast.silentWarning("Loading image from URL \(url.absoluteString)")

        if let cache = pipeline.configuration.imageCache as? ImageCache {
            let key = ImageCacheKey(request: request)
            if let container = cache[key] {
                ToastManager.shared.showToast.silentSuccess("Found cached image")
                state = .success(container.image)
                return
            }
        }

        ToastManager.shared.showToast.silentWarning("No cached image found. Downloading from network")

        task = pipeline.loadImage(
            with: request,
            progress: { [weak self] _, completed, total in
                Task { @MainActor [weak self] in
                    let partialDownload = total > 0 ? Double(completed) / Double(total) * 100.0 : 0
                    ToastManager.shared.showToast.silentWarning("Download Progress: \(Int(partialDownload))%")
                    self?.state = .progress(completed: completed, total: total)
                }
            },
            completion: { [weak self] result in
                Task { @MainActor [weak self] in
                    switch result {
                    case .success(let response):
                        ToastManager.shared.showToast.silentSuccess("Image loaded successfully")
                        self?.state = .success(response.image)
                        
                    case .failure(let error):
                        ToastManager.shared.showToast.silentError("Failed to load image: \(error.localizedDescription)")
                        self?.state = .failure
                    }
                }
            }
        )
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
