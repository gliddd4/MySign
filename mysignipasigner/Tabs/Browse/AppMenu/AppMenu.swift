//
//  AppMenu.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct AppMenu: View {
    let app: App
    
    // Store weak reference to root view controller
    private let weakRootVC: () -> UIViewController? = {
        weak var rootVC = UIApplication.shared.connectedScenes
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?
            .windows
            .first?
            .rootViewController
        return { rootVC }
    }()
    
    var body: some View {
        Group {
            // Download URL Menu
            if let downloadURL = app.downloadURL ?? app.versions?.first?.downloadURL {
                Button(action: {
                    copyDownloadURL(downloadURL)
                }) {
                    Label("Copy Download URL", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    shareDownloadURL(downloadURL)
                }) {
                    Label("Share Download URL", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    openDownloadURL(downloadURL)
                }) {
                    Label("Open Download URL", systemImage: "link")
                }
            }
            
            // Icon URL Menu
            if let iconURL = app.iconURL {
                Button(action: {
                    copyIconURL(iconURL)
                }) {
                    Label("Copy Icon URL", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    shareIconURL(iconURL)
                }) {
                    Label("Share Icon URL", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    openIconURL(iconURL)
                }) {
                    Label("Open Icon URL", systemImage: "link")
                }
            }
            
            // App JSON Menu
            Button(action: {
                copyAppJSON()
            }) {
                Label("Copy App JSON", systemImage: "doc.text")
            }
            
            Button(action: {
                shareAppJSON()
            }) {
                Label("Share App JSON", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    // Download URL Actions
    private func copyDownloadURL(_ url: String) {
        UIPasteboard.general.string = url
        ToastManager.shared.showToast.success("Copied Download URL")
        ToastManager.shared.showToast.log("Copied Download URL for \(app.name)")
    }
    
    private func shareDownloadURL(_ url: String) {
        guard let rootVC = weakRootVC() else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = .init(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 0, height: 0)
        
        rootVC.present(activityVC, animated: true)
        ToastManager.shared.showToast.log("Shared Download URL for \(app.name)")
    }
    
    private func openDownloadURL(_ url: String) {
        if let urlObj = URL(string: url) {
            UIApplication.shared.open(urlObj)
            ToastManager.shared.showToast.log("Opened Download URL for \(app.name)")
        } else {
            ToastManager.shared.showToast.error("Invalid Download URL")
        }
    }
    
    // Icon URL Actions
    private func copyIconURL(_ url: String) {
        UIPasteboard.general.string = url
        ToastManager.shared.showToast.success("Copied Icon URL")
        ToastManager.shared.showToast.log("Copied Icon URL for \(app.name)")
    }
    
    private func shareIconURL(_ url: String) {
        guard let rootVC = weakRootVC() else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = .init(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 0, height: 0)
        
        rootVC.present(activityVC, animated: true)
        ToastManager.shared.showToast.log("Shared Icon URL for \(app.name)")
    }
    
    private func openIconURL(_ url: String) {
        if let urlObj = URL(string: url) {
            UIApplication.shared.open(urlObj)
            ToastManager.shared.showToast.log("Opened Icon URL for \(app.name)")
        } else {
            ToastManager.shared.showToast.error("Invalid Icon URL")
        }
    }
    
    // App JSON Actions
    private func copyAppJSON() {
        let jsonString = formatJSON()
        UIPasteboard.general.string = jsonString
        ToastManager.shared.showToast.success("Copied App JSON")
        ToastManager.shared.showToast.log("Copied App JSON for \(app.name)")
    }
    
    private func shareAppJSON() {
        guard let rootVC = weakRootVC() else { return }
        
        let jsonString = formatJSON()
        let activityVC = UIActivityViewController(
            activityItems: [jsonString],
            applicationActivities: nil
        )
        
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = .init(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 0, height: 0)
        
        rootVC.present(activityVC, animated: true)
        ToastManager.shared.showToast.log("Shared App JSON for \(app.name)")
    }
    
    private func formatJSON() -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(app)
            return String(data: data, encoding: .utf8) ?? "Unable to format JSON"
        } catch {
            return "Error encoding JSON: \(error.localizedDescription)"
        }
    }
}