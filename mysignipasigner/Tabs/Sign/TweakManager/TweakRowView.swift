//
//  TweakRowView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct TweakRowView: View {
    let tweak: TweakFolder
    let isDefault: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.medium()
            onTap()
        }) {
            HStack {
                Image(systemName: tweak.fileType.systemIcon)
                    .frame(width: 30, height: 30)
                    .foregroundColor(tweak.isValid ? .blue : .red)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(tweak.name)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if isDefault {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        // File type indicator
                        HStack(spacing: 2) {
                            Image(systemName: tweak.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(tweak.isValid ? .green : .red)
                            Text(tweak.fileType.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // File size
                        Text(tweak.formattedFileSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}