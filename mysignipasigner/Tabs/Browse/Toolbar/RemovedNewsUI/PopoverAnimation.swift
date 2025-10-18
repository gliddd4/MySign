//
//  PopoverAnimation.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

enum PopoverAnimation {
    // Base animation configuration
    static let duration = 0.3
    static let animation = Animation.easeInOut(duration: duration)
    static let transition = AnyTransition.move(edge: .bottom)
    
    // Interactive gesture animations
    static let dragAnimation = Animation.linear(duration: 0.1)
    static let recoveryAnimation = Animation.easeOut(duration: 0.2)
    
    // Card animations
    static let cardIndexDuration = 0.8
    static let cardAnimation = Animation.easeInOut(duration: cardIndexDuration)
    static let cardInteractiveSpring = Animation.interactiveSpring(response: 0.6, dampingFraction: 0.7)
    
    // Gesture thresholds
    static let dismissDistance: CGFloat = 100
    static let dismissVelocity: CGFloat = 100
    static let maxOpacityOffset: CGFloat = 300
    static let cardSensitivity: CGFloat = 50
    static let cardVelocityThreshold: CGFloat = 300
    
    // Helper to calculate dismiss decision
    static func shouldDismiss(translation: CGFloat, predictedEndVelocity: CGFloat) -> Bool {
        translation > dismissDistance || predictedEndVelocity > dismissVelocity
    }
    
    @MainActor
    static func animateAppear(offset: Binding<CGSize>) {
        offset.wrappedValue.height = UIScreen.main.bounds.height
        withAnimation(animation) {
            offset.wrappedValue.height = 0
        }
    }
    
    @MainActor
    static func animateDismiss(offset: Binding<CGSize>, completion: @escaping () -> Void) {
        withAnimation(animation) {
            offset.wrappedValue.height = UIScreen.main.bounds.height
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }
    
    static func animateToCardIndex(currentIndex: Binding<Int>, newIndex: Int, dragOffset: Binding<CGFloat>) {
        withAnimation(cardAnimation) {
            currentIndex.wrappedValue = newIndex
            dragOffset.wrappedValue = 0
        }
    }
}
