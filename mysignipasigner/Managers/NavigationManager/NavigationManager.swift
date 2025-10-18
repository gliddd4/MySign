//
//  NavigationManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit
import BezelKit

// MARK: - NavigationBarItemView

fileprivate struct NavigationBarItemView: View {
    let item: NavigationItem
    @EnvironmentObject private var theme: Theme

    @ViewBuilder
    var body: some View {
        if let menuView = item.menu {
            SwiftUI.Menu {
                menuView
            } label: {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.accentColor)
            }
        } else if let action = item.action {
            Button(action: action) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.accentColor)
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - NavigationManager View

struct NavigationManager: View {
    @EnvironmentObject private var tabSelectionManager: TabSelectionManager
    @EnvironmentObject private var theme: Theme
    @Environment(\.originalSafeArea) private var originalSafeArea
    
    // Navigation-specific properties
    var title: String = ""
    var showBackButton: Bool = false
    var leadingItems: [NavigationItem] = []
    var trailingItems: [NavigationItem] = []
    var pillContent: AnyView?
    var secondaryPillContent: AnyView?
    
    @ObservedObject private var navigationState = NavigationStateManager.shared
    
    @AppStorage("ui_hideNavigationBarBlur") private var hideNavigationBarBlur = false
    
    private var cornerRadius: CGFloat {
        return deviceHasHomeButton ? 24 : .deviceBezel
    }
    
    private var deviceHasHomeButton: Bool {
        hasHomeButton()
    }
    
    private var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate navigation height based on whether we have secondary content
            let baseNavigationHeight: CGFloat = 44
            let secondaryPillHeight: CGFloat = secondaryPillContent != nil ? 44 : 0
            let totalNavigationHeight = baseNavigationHeight + secondaryPillHeight
            
            ZStack {
                // --- 1. Progressive blur layer (behind navigation) ---
                if !navigationState.shouldHideNavigationForCurrentView && !hideNavigationBarBlur {
                    ZStack {
                        // Top blur - 40 points down from top
                        VStack {
                            VariableBlurView(
                                maxBlurRadius: 20,
                                direction: .blurredTopClearBottom
                            )
                            .frame(height: 40)
                            Spacer()
                        }
                        .edgesIgnoringSafeArea(.top)
                        
                        // Bottom blur - 40 points up from bottom
                        VStack {
                            Spacer()
                            VariableBlurView(
                                maxBlurRadius: 20,
                                direction: .blurredBottomClearTop
                            )
                            .frame(height: 40)
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    }
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(false)
                }
                
                // --- 2. Actual navigation UI (top layer) ---
                if !navigationState.shouldHideNavigationForCurrentView {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 8) {
                                // Main navigation bar
                                HStack(spacing: 8) {
                                    // Leading section with toolbar items
                                    if !leadingItems.isEmpty {
                                        HStack(spacing: 8) {
                                            ForEach(leadingItems) { item in
                                                NavigationBarItemView(item: item)
                                            }
                                        }
                                    }
                                    
                                    // Center section with title
                                    if !title.isEmpty || (!leadingItems.isEmpty && title.isEmpty) {
                                        if !title.isEmpty {
                                            Text(title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .layoutPriority(2)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.9)
                                                .truncationMode(.tail)
                                        }
                                    } else {
                                        Text(tabSelectionManager.selectedTabName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .layoutPriority(2)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.9)
                                            .truncationMode(.tail)
                                    }
                                    
                                    // Trailing section with toolbar items
                                    if !trailingItems.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(trailingItems) { item in
                                                NavigationBarItemView(item: item)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(navigationBackground)
                                .background(
                                    // Add blur behind the navigation bar background
                                    VariableBlurView(
                                        maxBlurRadius: 10,
                                        direction: .blurredTopClearBottom,
                                        startOffset: -0.5
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                    .allowsHitTesting(false)
                                )
                                .cornerRadius(cornerRadius)
                                
                                // Pill switcher with its own background
                                if let pillContent = pillContent {
                                    pillContent
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(navigationBackground)
                                        .background(
                                            // Add blur behind the pill switcher background
                                            VariableBlurView(
                                                maxBlurRadius: 10,
                                                direction: .blurredTopClearBottom,
                                                startOffset: -0.5
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                            .allowsHitTesting(false)
                                        )
                                        .cornerRadius(cornerRadius)
                                }
                            }
                            .frame(height: 44)
                            
                            // Secondary pill row
                            if let secondaryPillContent = secondaryPillContent {
                                HStack {
                                    secondaryPillContent
                                    Spacer()
                                }
                                .frame(height: 44)
                            }
                        }
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { navigationState.isNavigationVisible = true }
                    .onDisappear { navigationState.isNavigationVisible = false }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: navigationState.shouldHideNavigationForCurrentView)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: tabSelectionManager.selectedTab)
        }
    }
    
    private var navigationBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.05))
                .blur(radius: 1)
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -10)
    }
}

// MARK: - NavigationManager Extensions

extension NavigationManager {
    // Convenience initializers for different navigation configurations
    
    // For Settings view with logs button
    static func settingsNavigation(showLogsAction: @escaping () -> Void) -> NavigationManager {
        var manager = NavigationManager()
        manager.trailingItems = [
            NavigationItem(icon: "text.book.closed", name: "Logs", action: showLogsAction)
        ]
        return manager
    }
    
    // For other views with custom title and actions
    static func customNavigation(title: String = "", leadingItems: [NavigationItem] = [], trailingItems: [NavigationItem] = []) -> NavigationManager {
        var manager = NavigationManager()
        manager.title = title
        manager.leadingItems = leadingItems
        manager.trailingItems = trailingItems
        manager.pillContent = nil
        manager.secondaryPillContent = nil
        return manager
    }

    // For Browse view with integrated tab switcher
    static func browseNavigation(
        selectedTab: Binding<BrowseTab>,
        trailingItems: [NavigationItem] = []
    ) -> NavigationManager {
        var manager = NavigationManager()
        manager.title = "Browse"
        manager.trailingItems = trailingItems
        manager.pillContent = AnyView(
            HStack(spacing: 16) {
                Button(action: {
                    selectedTab.wrappedValue = .all
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Switched to All repositories tab")
                }) {
                    Text("All")
                        .font(.headline)
                        .foregroundColor(selectedTab.wrappedValue == .all ? Theme.shared.accentColor : .white)
                }
                .accessibilityLabel("All")
                
                Button(action: {
                    selectedTab.wrappedValue = .news
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Switched to News tab")
                }) {
                    Text("News")
                        .font(.headline)
                        .foregroundColor(selectedTab.wrappedValue == .news ? Theme.shared.accentColor : .white)
                }
                .accessibilityLabel("News")
            }
        )
        manager.secondaryPillContent = nil
        return manager
    }

    // Overload for custom navigation with a pill switcher
    static func customNavigation<PillContent: View>(
        title: String = "",
        leadingItems: [NavigationItem] = [],
        trailingItems: [NavigationItem] = [],
        @ViewBuilder pillContent: () -> PillContent
    ) -> NavigationManager {
        var manager = NavigationManager()
        manager.title = title
        manager.leadingItems = leadingItems
        manager.trailingItems = trailingItems
        manager.pillContent = AnyView(pillContent())
        manager.secondaryPillContent = nil
        return manager
    }

    // Overload for custom navigation with primary and secondary pill content
    static func customNavigation<PillContent: View, SecondaryContent: View>(
        title: String = "",
        leadingItems: [NavigationItem] = [],
        trailingItems: [NavigationItem] = [],
        @ViewBuilder pillContent: () -> PillContent,
        @ViewBuilder secondaryPillContent: () -> SecondaryContent
    ) -> NavigationManager {
        var manager = NavigationManager()
        manager.title = title
        manager.leadingItems = leadingItems
        manager.trailingItems = trailingItems
        manager.pillContent = AnyView(pillContent())
        manager.secondaryPillContent = AnyView(secondaryPillContent())
        return manager
    }
}
