//
//  NavigationItem.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

// MARK: - NavigationItem

struct NavigationItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let action: (() -> Void)?
    let menu: AnyView?
    
    // Initializer for toolbar items
    init(icon: String, name: String, action: @escaping () -> Void) {
        self.icon = icon
        self.name = name
        self.action = action
        self.menu = nil
    }

    init<Content: View>(icon: String, name: String, menu: () -> Content, action: (() -> Void)? = nil) {
        self.icon = icon
        self.name = name
        self.action = action
        self.menu = AnyView(menu())
    }
}