//
//  TabItem.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

// MARK: - TabItem

struct TabItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let color: Color
    
    // MARK: - Default Items
    
    static let defaultItems: [TabItem] = [
        .init(icon: "plus.app", name: "Sign", color: .white),
        .init(icon: "folder", name: "Files", color: .white),
        .init(icon: "sparkle.magnifyingglass", name: "Browse", color: .white),
        .init(icon: "arrow.down.app", name: "Downloads", color: .white),
        .init(icon: "gear", name: "Settings", color: .white)
    ]
}
