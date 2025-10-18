//
//  IPADetailsPillSwitcher.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct IPADetailsPillSwitcher: View {
    @Binding var selection: DetailTab
    let themeAccent: Theme
    let appName: String
    let app: App

    var body: some View {
        // App details content - sized to exactly match back button
        HStack(spacing: 8) {
            AppIconView(app: app)
                .aspectRatio(1, contentMode: .fit)
                .frame(height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text(appName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}