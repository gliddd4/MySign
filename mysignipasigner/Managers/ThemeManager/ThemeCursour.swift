//
//  ThemeCursour.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ThemeCursour: ViewModifier {
    @ObservedObject private var themeManager = Theme.shared
    
    func body(content: Content) -> some View {
        content
            .tint(themeManager.accentColor)
    }
}

extension View {
    func withThemeCursour() -> some View {
        modifier(ThemeCursour())
    }
}
// This file makes the cursour color themed to what the user wants
