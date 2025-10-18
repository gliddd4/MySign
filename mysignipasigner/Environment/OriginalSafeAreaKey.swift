//
//  OriginalSafeAreaKey.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct OriginalSafeAreaKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var originalSafeArea: EdgeInsets {
        get { self[OriginalSafeAreaKey.self] }
        set { self[OriginalSafeAreaKey.self] = newValue }
    }
}