//
//  FixedTabSwitcher.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import BezelKit

struct TabBarSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

struct FixedTabSwitcher: View {
    @EnvironmentObject private var tabSelectionManager: TabSelectionManager
    @EnvironmentObject private var tabStateManager: TabStateManager
    @EnvironmentObject private var theme: Theme
    @ObservedObject private var navigationState = NavigationStateManager.shared
    @AppStorage("ui_verticalTabBarBlur") private var verticalTabBarBlur: Double = 1.0
    
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var expandedWidth: CGFloat = 0
    @State private var isHidden = false
    @State private var handleDragOffset: CGFloat = 0
    @State private var dragStartPosition: CGPoint = .zero
    @State private var isDragging = false
    @State private var isAutoCollapsing = false
    
    private var cornerRadius: CGFloat {
        let baseRadius: CGFloat = hasHomeButton() ? 24 : .deviceBezel
        return isExpanded ? baseRadius * 0.5 : baseRadius
    }
    
    private var tabBarWidth: CGFloat {
        return isExpanded ? max(expandedWidth, 44) : 44
    }
    
    private var blurWidth: CGFloat {
        return isExpanded ? max(expandedWidth, 44) : 44
    }
    
    private var tabBarHeight: CGFloat {
        return (5 * 20) + (4 * 12) + 24
    }
    
    private var handleOpacity: Double {
        if tabStateManager.isDragHandleAutoHidden { return 0.0 }
        if isDragging { return 1.0 }
        return 1.0  // Removed isHidden opacity change - handle should stay solid when hidden
    }
    
    private var handleColor: Color {
        if isDragging { return theme.accentColor }
        return .white
    }
    
    private var shouldShowBlur: Bool {
        return verticalTabBarBlur > 0
    }
    
    private var blurRadius: CGFloat {
        return CGFloat(verticalTabBarBlur)
    }
    
    private var edgeSwipeWidth: CGFloat {
        return (isHidden || tabStateManager.isDragHandleAutoHidden) ? 60 : 0
    }
    
    var body: some View {
        if !navigationState.shouldHideNavigationForCurrentView {
            mainContent
        }
    }
    
    private var mainContent: some View {
        HStack {
            VStack {
                Spacer()
                tabBarSection
                Spacer()
            }
            .frame(maxHeight: .infinity)
            
            Spacer()
        }
        .padding(.leading, 16)
        .zIndex(999)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: tabSelectionManager.selectedTab)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .animation(.easeInOut(duration: 0.5), value: tabStateManager.isDragHandleAutoHidden)
        .animation(.easeInOut(duration: 0.2), value: tabStateManager.dragHandleSwipeConfirmationState)
        .overlay(leftEdgeSwipeBackground, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .init("AutoCollapseTabBar"))) { _ in
            startAutoCollapseSequence()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("RestoreTabBar"))) { _ in
            restoreTabBar()
        }
    }
    
    private func startAutoCollapseSequence() {
        isAutoCollapsing = true
        
        if isExpanded {
            // Step 1: Collapse if expanded
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded = false
            }
            
            // Wait for collapse animation to complete, then hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isHidden = true
                }
                
                // Wait for hide animation to complete, then set drag handle as auto-hidden
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tabStateManager.isDragHandleAutoHidden = true
                    isAutoCollapsing = false
                }
            }
        } else {
            // Step 1: Hide directly if already collapsed
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isHidden = true
            }
            
            // Wait for hide animation to complete, then set drag handle as auto-hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tabStateManager.isDragHandleAutoHidden = true
                isAutoCollapsing = false
            }
        }
    }
    
    private func restoreTabBar() {
        isAutoCollapsing = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isHidden = false
        }
    }
    
    private var tabBarSection: some View {
        HStack(spacing: 0) {
            tabBarContent // Always show, but animate position
            dragHandle
        }
    }
    
    private var tabBarContent: some View {
        ZStack {
            if shouldShowBlur {
                blurBackground
            }
            tabButtonsContainer
        }
        .offset(x: (isHidden ? -100 : 0) + handleDragOffset) // Follow drag handle movement
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHidden) // Only animate position
    }
    
    private var blurBackground: some View {
        VariableBlurView(
            maxBlurRadius: blurRadius,
            direction: .blurredTopClearBottom,
            startOffset: -0.5
        )
        .frame(width: blurWidth, height: tabBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }
    
    private var tabButtonsContainer: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(TabItem.defaultItems.enumerated()), id: \.element.id) { index, item in
                tabButtonRow(for: index, item: item)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: isExpanded ? nil : 44)
        .background(navigationBackground)
        .cornerRadius(cornerRadius)
        .background(sizeTrackingBackground)
        .offset(x: dragOffset)
        .scaleEffect(isDragging ? 0.98 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Don't allow interaction during auto-collapse
                    guard !isAutoCollapsing else { return }
                    
                    if dragStartPosition == .zero {
                        dragStartPosition = value.startLocation
                    }
                    
                    isDragging = true
                    
                    if !isExpanded {
                        dragOffset = value.translation.width * 0.5
                    }
                    
                    // Debug logging
                    print("Tab bar drag changed: \(value.translation.width)")
                }
                .onEnded { value in
                    // Don't allow interaction during auto-collapse
                    guard !isAutoCollapsing else { return }
                    
                    isDragging = false
                    dragStartPosition = .zero
                    
                    let dragDistance = value.translation.width
                    let dragVelocity = value.predictedEndTranslation.width
                    
                    // Debug logging
                    print("Tab bar drag ended - Distance: \(dragDistance), Velocity: \(dragVelocity)")
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                        
                        // Very low thresholds
                        if dragDistance > 20 || dragVelocity > 40 {
                            print("Triggering tab bar right drag")
                            if !isExpanded {
                                isExpanded = true
                                HapticManager.shared.medium()
                                ToastManager.shared.showToast.log("Tab bar expanded")
                            }
                        } else if dragDistance < -20 || dragVelocity < -40 {
                            print("Triggering tab bar left drag")
                            if isExpanded {
                                isExpanded = false
                                HapticManager.shared.medium()
                                ToastManager.shared.showToast.log("Tab bar collapsed")
                            } else {
                                isHidden = true
                                tabStateManager.isDragHandleAutoHidden = true // Mark as auto-hidden when hiding via tab bar swipe
                                HapticManager.shared.medium()
                                ToastManager.shared.showToast.log("Tab bar hidden")
                            }
                        }
                    }
                }
        )
    }
    
    private func tabButtonRow(for index: Int, item: TabItem) -> some View {
        Group {
            if isExpanded {
                expandedTabButton(for: index, item: item)
            } else {
                collapsedTabButton(for: index, item: item)
            }
        }
    }
    
    private func expandedTabButton(for index: Int, item: TabItem) -> some View {
        HStack(spacing: 12) {
            tabButton(for: index, item: item)
            
            Text(item.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(tabColor(for: index))
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
        .frame(height: 20)
    }
    
    private func collapsedTabButton(for index: Int, item: TabItem) -> some View {
        tabButton(for: index, item: item)
            .frame(maxWidth: .infinity)
            .frame(height: 20)
    }
    
    private func tabButton(for index: Int, item: TabItem) -> some View {
        Button(action: {
            // Don't allow interaction during auto-collapse
            guard !isAutoCollapsing else { return }
            
            tabSelectionManager.selectTab(index)
            HapticManager.shared.medium()
        }) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(tabColor(for: index))
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel(item.name)
    }
    
    private func tabColor(for index: Int) -> Color {
        return tabSelectionManager.selectedTab == index ? theme.accentColor : .white
    }
    
    private var sizeTrackingBackground: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: TabBarSizePreferenceKey.self, value: geometry.size)
                .onChange(of: geometry.size.width) { newWidth in
                    if isExpanded && newWidth > 44 {
                        expandedWidth = newWidth
                    }
                }
        }
    }
    
    private var dragHandle: some View {
        VStack {
            Spacer()
            
            ZStack {
                handleBackground
                handleIndicators
            }
            .opacity(handleOpacity)
            .offset(x: handleDragOffset + (isHidden ? -50 : 0)) // Slide further left when hidden
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHidden) // Only animate position, NOT opacity
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // Don't allow interaction during auto-collapse
                        guard !isAutoCollapsing else { return }
                        
                        isDragging = true
                        handleDragOffset = value.translation.width * 0.3
                        
                        // Record interaction to reset timer
                        tabStateManager.recordDragHandleInteraction()
                        
                        // Debug logging
                        print("Handle drag changed: \(value.translation.width)")
                    }
                    .onEnded { value in
                        // Don't allow interaction during auto-collapse
                        guard !isAutoCollapsing else { return }
                        
                        isDragging = false
                        
                        let dragDistance = value.translation.width
                        let dragVelocity = value.predictedEndTranslation.width
                        
                        // Debug logging
                        print("Handle drag ended - Distance: \(dragDistance), Velocity: \(dragVelocity)")
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            handleDragOffset = 0
                            
                            // Very low thresholds for easy interaction
                            if dragDistance > 15 || dragVelocity > 25 {
                                print("Triggering right drag")
                                if isHidden {
                                    isHidden = false
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Tab bar shown")
                                } else if !isExpanded {
                                    isExpanded = true
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Tab bar expanded")
                                }
                            } else if dragDistance < -15 || dragVelocity < -25 {
                                print("Triggering left drag")
                                if isExpanded {
                                    isExpanded = false
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Tab bar collapsed")
                                } else if !isHidden {
                                    isHidden = true
                                    tabStateManager.isDragHandleAutoHidden = true // Mark as auto-hidden immediately
                                    HapticManager.shared.medium()
                                    ToastManager.shared.showToast.log("Tab bar hidden")
                                }
                            }
                        }
                    }
            )
            .onTapGesture {
                // Don't allow interaction during auto-collapse
                guard !isAutoCollapsing else { return }
                
                print("Handle tapped")
                // Record interaction to reset timer
                tabStateManager.recordDragHandleInteraction()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isHidden {
                        isHidden = false
                        ToastManager.shared.showToast.log("Tab bar shown (tap)")
                    } else if isExpanded {
                        isExpanded = false
                        ToastManager.shared.showToast.log("Tab bar collapsed (tap)")
                    } else {
                        isExpanded = true
                        ToastManager.shared.showToast.log("Tab bar expanded (tap)")
                    }
                    HapticManager.shared.light()
                }
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                // Don't allow interaction during auto-collapse
                guard !isAutoCollapsing else { return }
                
                print("Handle long pressed")
                // Record interaction to reset timer
                tabStateManager.recordDragHandleInteraction()
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    if isHidden {
                        isHidden = false
                        isExpanded = true
                        ToastManager.shared.showToast.log("Tab bar expanded (long press)")
                    } else if !isExpanded {
                        isExpanded = true
                        ToastManager.shared.showToast.log("Tab bar expanded (long press)")
                    } else {
                        isHidden = true
                        isExpanded = false
                        ToastManager.shared.showToast.log("Tab bar hidden (long press)")
                    }
                    HapticManager.shared.heavy()
                }
            }
            
            Spacer()
        }
        .frame(width: 40)
        .contentShape(Rectangle())
    }
    
    private var handleBackground: some View {
        ZStack {
            if shouldShowBlur {
                VariableBlurView(
                    maxBlurRadius: blurRadius,
                    direction: .blurredTopClearBottom,
                    startOffset: -0.5
                )
                .frame(width: 20, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .allowsHitTesting(false)
            }
            
            navigationBackground
                .frame(width: 20, height: 100)
        }
    }
    
    private var handleIndicators: some View {
        VStack(spacing: 6) {
            chevronIndicator
        }
    }
    
    private var chevronIndicator: some View {
        Group {
            if isHidden {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDragging ? theme.accentColor : .white)
            } else if isExpanded {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDragging ? theme.accentColor : .white)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDragging ? theme.accentColor : .white)
            }
        }
    }
    
    private var leftEdgeSwipeBackground: some View {
        Color.clear
            .frame(width: edgeSwipeWidth, height: UIScreen.main.bounds.height)
            .contentShape(Rectangle())
            .gesture(leftEdgeSwipeGesture)
            .allowsHitTesting(tabStateManager.isDragHandleAutoHidden)
    }
    
    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 5) // Reduced minimum distance
            .onEnded { value in
                if isHidden && value.translation.width > 15 {
                    // Handle edge swipe for manually hidden tab bar
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHidden = false
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Tab bar shown (edge swipe)")
                    }
                }
            }
    }
    
    private var leftEdgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onEnded { value in
                if tabStateManager.isDragHandleAutoHidden && value.translation.width > 15 {
                    // Handle left edge swipe for auto-hidden drag handle
                    tabStateManager.handleDragHandleEdgeSwipe()
                }
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
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: -3, y: 0)
    }
}