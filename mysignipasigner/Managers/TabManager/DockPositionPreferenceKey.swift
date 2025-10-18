//
//  DockPositionPreferenceKey.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct DockPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}