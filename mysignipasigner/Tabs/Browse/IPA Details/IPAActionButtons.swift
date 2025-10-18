//
//  IPAActionButtons.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit

struct IPAActionButtons: View {
    let url: URL
    let effectiveDownloadURL: String?
    let isDownloading: Bool
    let downloadButtonText: String
    let themeAccent: Theme
    let app: App
    let onDownload: () -> Void
    let onShare: () -> Void
    
    @EnvironmentObject private var tabSelectionManager: TabSelectionManager
    
    var body: some View {
        Button(action: {
            ToastManager.shared.showToast.log("Clicked Download for \(app.name)")
            onDownload()
            tabSelectionManager.selectTab(3) // Downloads tab is index 3
        }) {
            HStack {
                Image("downloaddark")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                Text(downloadButtonText)
            }
        }
        .foregroundColor(.white)
        .disabled(isDownloading)
        
        Button(action: {
            ToastManager.shared.showToast.log("Clicked Share for \(app.name)")
            onShare()
        }) {
            HStack {
                Image("sharedark")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                Text("Share")
            }
        }
        .foregroundColor(.white)
        
        Button(action: {
            ToastManager.shared.showToast.log("Clicked Install with SideStore for \(app.name)")
            if let encodedURL = effectiveDownloadURL?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let sideStoreURL = URL(string: "sidestore://install?url=\(encodedURL)") {
                UIApplication.shared.open(sideStoreURL)
            }
        }) {
            HStack {
                Image("sidestore")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                Text("Install with SideStore")
            }
        }
        .foregroundColor(.white)
        .disabled(effectiveDownloadURL == nil)

        Button(action: {
            ToastManager.shared.showToast.log("Clicked Install with AltStore for \(app.name)")
            if let encodedURL = effectiveDownloadURL?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let altStoreURL = URL(string: "altstore://install?url=\(encodedURL)") {
                UIApplication.shared.open(altStoreURL)
            }
        }) {
            HStack {
                Image("altstore")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                Text("Install with AltStore")
            }
        }
        .foregroundColor(.white)
        .disabled(effectiveDownloadURL == nil)
        
        Button(action: {
            ToastManager.shared.showToast.log("Clicked Open in Safari for \(app.name)")
            if let downloadURL = effectiveDownloadURL, let url = URL(string: downloadURL) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image("safaridark")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                Text("Open Download URL in Safari")
            }
        }
        .foregroundColor(.white)
        .disabled(effectiveDownloadURL == nil)
        
        Button(action: {
            ToastManager.shared.showToast.log("Clicked Copy URL for \(app.name)")
            if let downloadURL = effectiveDownloadURL {
                UIPasteboard.general.string = downloadURL
                ToastManager.shared.showToast.success("URL copied to clipboard")
            }
        }) {
            HStack {
                Image("clipboarddocumentdark")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                Text("Copy Download URL")
            }
        }
        .foregroundColor(.white)
        .disabled(effectiveDownloadURL == nil)
    }
}