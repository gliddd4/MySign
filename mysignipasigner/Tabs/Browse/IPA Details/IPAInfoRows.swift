//
//  IPAInfoRows.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct CompactInfoRow: View {
    let title: String
    let content: String
    
    private var cleanContent: String {
        // More aggressive cleaning of whitespace
        let cleaned = content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return cleaned
    }
    
    var body: some View {
        Text(title)
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(.primary) +
        Text(" \(cleanContent)")
            .font(.body)
            .foregroundColor(.secondary)
    }
}

struct InfoRow: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}