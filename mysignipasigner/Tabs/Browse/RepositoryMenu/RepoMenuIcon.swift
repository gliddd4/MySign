//
//  RepoMenuIcon.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct MenuIcon: View {
    let repository: RepositoryFormat
    @ObservedObject var themeManager: Theme
    @ObservedObject private var iconManager = IconManager.shared
    
    var body: some View {
        Group {
            Button {
                Task {
                    let success = await IconManager.shared.reloadImage(
                        for: repository.iconURL ?? "", 
                        name: repository.name,
                        repository: repository
                    )
                    if success {
                        themeManager.showToast("Successfully reloaded icon for \(repository.name)", isError: false)
                    } else {
                        themeManager.showToast("Failed to reload icon for \(repository.name)", isError: true)
                    }
                }
            } label: {
                Label("Reload Icon", systemImage: "arrow.clockwise")
            }
            
            if let iconURL = repository.iconURL, let url = URL(string: iconURL) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("Open Icon in Browser", systemImage: "safari")
                }
            }
        }
    }
}