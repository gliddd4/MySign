//
//  BackgroundBlurView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import BezelKit

struct BackgroundBlurView: View {
    let maxBlurRadius: CGFloat
    let direction: VariableBlurDirection
    let cornerRadius: CGFloat
    
    init(
        maxBlurRadius: CGFloat = 20,
        direction: VariableBlurDirection = .blurredCenterOutwards,
        cornerRadius: CGFloat = 12
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        VariableBlurView(
            maxBlurRadius: maxBlurRadius,
            direction: direction
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }
}

// Extension for easy device-dependent corner radius
extension BackgroundBlurView {
    static func deviceCornerRadius(
        maxBlurRadius: CGFloat = 20,
        direction: VariableBlurDirection = .blurredCenterOutwards
    ) -> BackgroundBlurView {
        let radius: CGFloat = hasHomeButton() ? 24 : .deviceBezel
        return BackgroundBlurView(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            cornerRadius: radius
        )
    }
}