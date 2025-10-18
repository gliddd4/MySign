//
//  HeaderStyling.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

extension Text {
    func secondaryHeader() -> some View {
        self
            .foregroundColor(.secondary)
            .font(.system(size: 13, weight: .regular))
    }
    
    func footerText() -> some View {
        self
            .foregroundColor(.secondary)
            .font(.footnote)
            .padding(.top, 6)
    }
}
