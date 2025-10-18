//
//  DockPositionCalculator.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit

// MARK: - DockPositionCalculator

struct DockPositionCalculator: UIViewRepresentable {
    @Binding var dockTopY: CGFloat
    @Binding var safeAreaBottom: CGFloat
    @Binding var blurHeight: CGFloat
    
    func makeUIView(context: Context) -> DockPositionView {
        let view = DockPositionView()
        view.onPositionUpdate = { dockTop, safeBottom, height in
            DispatchQueue.main.async {
                self.dockTopY = dockTop
                self.safeAreaBottom = safeBottom
                self.blurHeight = height
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: DockPositionView, context: Context) {
        uiView.calculatePositions()
    }
}

// MARK: - DockPositionView

class DockPositionView: UIView {
    var onPositionUpdate: ((CGFloat, CGFloat, CGFloat) -> Void)?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        calculatePositions()
    }
    
    func calculatePositions() {
        guard let window = self.window else { return }
        
        // Get the safe area insets
        let safeAreaInsets = window.safeAreaInsets
        let screenHeight = window.bounds.height
        
        // Calculate safe area bottom position (from top of screen)
        let safeAreaBottomY = screenHeight - safeAreaInsets.bottom
        
        // For dock positioning, we need to account for:
        // 1. The dock height (65 points)
        // 2. The dock background padding (12 points top + 12 points bottom)
        // 3. Any device-specific positioning adjustments
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let dockHeight: CGFloat = 65
        let dockBackgroundPadding: CGFloat = 12
        let deviceAdjustment: CGFloat = isIPad ? 10 : -15
        
        // Calculate where the top of the dock background actually appears
        let dockBackgroundTopY = safeAreaBottomY + deviceAdjustment - dockBackgroundPadding
        
        // Calculate the blur height needed to reach from safe area bottom to dock background top
        let blurHeight = abs(dockBackgroundTopY - safeAreaBottomY)
        
        onPositionUpdate?(dockBackgroundTopY, safeAreaBottomY, blurHeight)
    }
}