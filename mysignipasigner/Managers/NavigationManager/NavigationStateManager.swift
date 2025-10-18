//
//  NavigationStateManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Combine

// MARK: - Navigation State Manager

class NavigationStateManager: ObservableObject {
    static let shared = NavigationStateManager()
    @Published var isNavigationVisible = true
    @Published var shouldHideNavigationForCurrentView = false
    
    private init() {}
    
    func hideNavigationForView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldHideNavigationForCurrentView = true
        }
    }
    
    func showNavigationForView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldHideNavigationForCurrentView = false
        }
    }
}