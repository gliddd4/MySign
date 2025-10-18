//
//  ShareSheet.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var completion: ((Bool) -> Void)? = nil
    var sourceRect: CGRect? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Validate items are shareable
        let validItems = items.compactMap { item -> Any? in
            if let url = item as? URL {
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            return item
        }
        
        guard !validItems.isEmpty else {
            DispatchQueue.main.async {
                ToastManager.shared.showToast.error("No valid items to share")
                self.completion?(false)
            }
            return UIActivityViewController(activityItems: [], applicationActivities: nil)
        }
        
        let controller = UIActivityViewController(
            activityItems: validItems,
            applicationActivities: [SaveToDownloadsActivity(), QuickExportActivity()]
        )
        
        controller.completionWithItemsHandler = { (activityType, completed, _, error) in
            DispatchQueue.main.async { [self] in
                if let error = error {
                    ToastManager.shared.showToast.error("Sharing failed: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    if completed {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.success("Shared successfully")
                    }
                    completion?(completed)
                }
            }
        }
        
        // For iPad - prevent fullscreen and set proper presentation
        if let popover = controller.popoverPresentationController {
            configurePopover(popover: popover)
        }
        
        return controller
    }
    
    private func configurePopover(popover: UIPopoverPresentationController) {
        if let sourceRect = sourceRect {
            popover.sourceRect = sourceRect
        } else {
            // Fallback to centered presentation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window.rootViewController?.view
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            } else {
                // Fallback
                popover.sourceView = UIView()
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            }
            popover.permittedArrowDirections = []
        }
        
        popover.permittedArrowDirections = []
        popover.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Custom Activities
class SaveToDownloadsActivity: UIActivity {
    override var activityTitle: String? { "Save to Downloads" }
    override var activityImage: UIImage? { UIImage(systemName: "folder.badge.plus") }
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is URL }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        guard let url = activityItems.first(where: { $0 is URL }) as? URL else { return }
        Task {
            await FileImporter.moveIPAToDownloads(url)
        }
    }
}

class QuickExportActivity: UIActivity {
    override var activityTitle: String? { "Quick Export" }
    override var activityImage: UIImage? { UIImage(systemName: "bolt.horizontal") }
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is URL }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        guard let url = activityItems.first(where: { $0 is URL }) as? URL else { return }
        // Handle quick export logic here
        print("Quick export triggered for \(url)")
    }
}
