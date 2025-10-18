//
//  RepoMenuURL.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct MenuURL: View {
    let repository: RepositoryFormat
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    
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
            Button(action: copyURL) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                // Simplified share action
                guard let url = viewModel.getRepositoryURL(for: repository.identifier),
                      let rootVC = weakRootVC() else { return }
                
                let activityVC = UIActivityViewController(
                    activityItems: [url],
                    applicationActivities: nil
                )
                
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                activityVC.popoverPresentationController?.sourceRect = .init(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 0, height: 0)
                
                rootVC.present(activityVC, animated: true)
                
            }) {
                Label("Share URL", systemImage: "square.and.arrow.up")
            }
            
            Button(action: openURL) {
                Label("Open URL", systemImage: "link")
            }
        }
    }
    
    private func copyURL() {
        if let url = viewModel.getRepositoryURL(for: repository.identifier) {
            UIPasteboard.general.string = url
            themeManager.showToast("Copied")
        } else {
            themeManager.showToast("Invalid URL", isError: true)
        }
    }
    
    private func openURL() {
        if let url = viewModel.getRepositoryURL(for: repository.identifier),
           let urlObj = URL(string: url) {
            UIApplication.shared.open(urlObj)
        } else {
            themeManager.showToast("Invalid URL", isError: true)
        }
    }
}
