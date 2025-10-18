//
//  ToastConfiguration.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit

struct UIConfig {
    // Minimum allowed height for toast notifications
    static let minHeight: CGFloat = 36
    
    // Maximum allowed height for toast notifications before scrolling
    static let maxHeight: CGFloat = 120
    
    // Corner-radius values that are *unique* to toasts
    //  – 24 pt for multi-line (standard, matches dock height)
    //  – 18 pt for single-line (slightly more compact)
    static let standardCornerRadius: CGFloat = 24   // multi-line
    static let compactCornerRadius:  CGFloat = 18   // single-line
    
    // Size of the message text in toast notifications
    static let fontSize: CGFloat = 14
    
    // Left and right padding inside the toast
    static let horizontalPadding: CGFloat = 12
    
    // Top and bottom padding inside the toast
    static let verticalPadding: CGFloat = 7.5
    
    // Maximum width of toast as a percentage of screen width
    static let maxWidthMultiplier: CGFloat = 0.96
    
    // Position toasts right above the bottom safe area
    static let loweredBottomOffset: CGFloat = 0
    
    // Size of the checkmark/warning icon in toast
    static let iconSize: CGFloat = 20
    
    // Space between icon and message text
    static let iconSpacing: CGFloat = 8
}

enum ToastType {
    case success
    case error
    case warning
}

struct ToastItem {
    let containerView: UIView
    let position: ToastPosition
    let timer: Timer
}