//  DockManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit
import BezelKit

// MARK: - DockManager View

struct DockManager: View {
    @AppStorage("dock_useAccentColor") private var useAccentDockColor = false
    @AppStorage("dock_useCustomColor") private var useUnifiedDockColor = false
    @AppStorage("dock_unifiedColor") private var unifiedDockData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    @AppStorage("dock_signColor") private var signColorData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    @AppStorage("dock_filesColor") private var filesColorData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    @AppStorage("dock_browseColor") private var browseColorData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    @AppStorage("dock_downloadsColor") private var downloadsColorData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    @AppStorage("dock_settingsColor") private var settingsColorData: Data = try! JSONEncoder().encode(UIColor.white.cgColor.components)
    @AppStorage("dock_hideInLandscape") private var hideDockInLandscape = false
    @EnvironmentObject private var tabStateManager: TabStateManager
    @EnvironmentObject private var tabSelectionManager: TabSelectionManager
    @EnvironmentObject private var theme: Theme
    @Environment(\.originalSafeArea) private var originalSafeArea
    
    @AppStorage("ui_hideTabBarBlur") private var hideTabBarBlur = false
    
    @State private var isLandscape = false
    @Namespace private var namespace
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ObservedObject private var keyboardManager = KeyboardManager.shared
    
    @State private var dockBackgroundTopY: CGFloat = 0
    @State private var safeAreaBottomY: CGFloat = 0
    @State private var dockBackgroundFrame: CGRect = .zero
    
    // For draggable dock
    @State private var dockPosition: CGPoint = CGPoint(x: 10, y: 0)
    @State private var lastDragPosition: CGPoint = CGPoint(x: 10, y: 0)
    @State private var isDragging = false
    @State private var isDockExpanded = true
    @State private var dragStartPosition: CGFloat = 0
    
    private var cornerRadius: CGFloat {
        // Use device corner radius for gesture devices, fixed radius for home button devices
        return deviceHasHomeButton ? 24 : .deviceBezel
    }
    
    private var innerCornerRadius: CGFloat {
        // Calculate inner corner radius based on outer radius + padding
        let padding: CGFloat = 12  // Standard padding inside dock
        return cornerRadius - padding
    }
    
    private var signColor: Color {
        colorFromData(signColorData)
    }
    
    private var filesColor: Color {
        colorFromData(filesColorData)
    }
    
    private var browseColor: Color {
        colorFromData(browseColorData)
    }
    
    private var downloadsColor: Color {
        colorFromData(downloadsColorData)
    }
    
    private var settingsColor: Color {
        colorFromData(settingsColorData)
    }
    
    private var unifiedColor: Color {
        colorFromData(unifiedDockData)
    }
    
    private func colorFromData(_ data: Data) -> Color {
        if let components = try? JSONDecoder().decode([CGFloat].self, from: data),
           components.count >= 4 {
            return Color(.sRGB,
                       red: Double(components[0]),
                       green: Double(components[1]),
                       blue: Double(components[2]),
                       opacity: Double(components[3]))
        }
        return .white
    }
    
    private var deviceHasHomeButton: Bool {
        let hasHome = hasHomeButton()
        return hasHome
    }
    
    private var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        GeometryReader { geometry in
            let currentIsLandscape = geometry.size.width > geometry.size.height
            let usePortraitLayout = !currentIsLandscape || isIPad
            let shouldHideDockInLandscape = hideDockInLandscape && currentIsLandscape && isIPad
            
            ZStack(alignment: usePortraitLayout ? .bottom : .topLeading) {

                // --- 1. Progressive blur layer (bottom layer) ---
                VStack(spacing: 0) {
                    Spacer()
                    VariableBlurView(
                        maxBlurRadius: 20,
                        direction: .blurredBottomClearTop
                    )
                    .frame(height: 30)
                }
                .allowsHitTesting(false)
                
                // --- 2. Dock UI with background (top layer) ---
                if !keyboardManager.isKeyboardVisible && !tabStateManager.shouldHideTabForCurrentView && !shouldHideDockInLandscape {
                    if usePortraitLayout {
                        VStack(spacing: 0) {
                            Spacer()
                            
                            ZStack {
                                // Actual dock buttons
                                HStack(alignment: .center, spacing: 12) {
                                    ForEach(Array(TabItem.defaultItems.enumerated()), id: \.element.id) { index, item in
                                        dockButton(for: index, item: item)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    GeometryReader { dockGeometry in
                                        dockBackground
                                            .preference(key: DockPositionPreferenceKey.self, value: dockGeometry.frame(in: .global))
                                    }
                                )
                                .cornerRadius(cornerRadius)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .padding(.bottom, isIPad ? 10 : -15)
                        }
                        .onPreferenceChange(DockPositionPreferenceKey.self) { frame in
                            dockBackgroundFrame = frame
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear { tabStateManager.isTabVisible = true }
                        .onDisappear { tabStateManager.isTabVisible = false }
                    } else {
                        VStack(spacing: 12) {
                            // Grab bar for dragging (now half as wide)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 15, height: 6) // Half the width (30 -> 15)
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        isDockExpanded.toggle()
                                        ToastManager.shared.showToast.log("Dock \(isDockExpanded ? "expanded" : "collapsed")")
                                    }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            isDragging = true
                                            // Detect drag direction to expand/collapse
                                            let dragDistance = value.translation.height
                                            
                                            // If dragging down significantly, collapse the dock
                                            if dragDistance > 30 && isDockExpanded {
                                                isDockExpanded = false
                                                ToastManager.shared.showToast.log("Dock collapsed")
                                                HapticManager.shared.light()
                                            }
                                            // If dragging up significantly, expand the dock
                                            else if dragDistance < -30 && !isDockExpanded {
                                                isDockExpanded = true
                                                ToastManager.shared.showToast.log("Dock expanded")
                                                HapticManager.shared.light()
                                            }
                                        }
                                        .onEnded { _ in
                                            isDragging = false
                                        }
                                )
                            
                            if isDockExpanded {
                                ForEach(Array(TabItem.defaultItems.enumerated()), id: \.element.id) { index, item in
                                    dockButton(for: index, item: item)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(
                            GeometryReader { dockGeometry in
                                dockBackground
                                    .onAppear {
                                        let globalFrame = dockGeometry.frame(in: .global)
                                        dockBackgroundTopY = globalFrame.minY
                                        dockBackgroundFrame = globalFrame
                                        // Initialize dock position
                                        dockPosition = CGPoint(x: 10, y: globalFrame.midY)
                                        lastDragPosition = dockPosition
                                    }
                                    .onChange(of: geometry.size) { _ in
                                        let globalFrame = dockGeometry.frame(in: .global)
                                        dockBackgroundTopY = globalFrame.minY
                                        dockBackgroundFrame = globalFrame
                                    }
                            }
                        )
                        .frame(width: 44)
                        .frame(height: isDockExpanded ? nil : 40) // Minimized height when collapsed
                        .position(dockPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    // Update position based on drag
                                    dockPosition = CGPoint(
                                        x: lastDragPosition.x,
                                        y: lastDragPosition.y + value.translation.height
                                    )
                                }
                                .onEnded { value in
                                    isDragging = false
                                    lastDragPosition = dockPosition
                                    HapticManager.shared.light()
                                }
                        )
                        .ignoresSafeArea(.all)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .onAppear { tabStateManager.isTabVisible = true }
                        .onDisappear { tabStateManager.isTabVisible = false }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: keyboardManager.isKeyboardVisible)
            .animation(.easeInOut(duration: 0.3), value: tabStateManager.shouldHideTabForCurrentView)
            .animation(.linear(duration: 0.3), value: tabSelectionManager.selectedTab)
            .animation(.easeInOut(duration: 0.3), value: currentIsLandscape)
            .animation(.spring(), value: isDockExpanded)
            .coordinateSpace(name: "tabManager")
            .onChange(of: keyboardManager.isKeyboardVisible) { value in
                updateDockVisibility(geometry: geometry)
            }
            .onChange(of: currentIsLandscape) { value in
                isLandscape = value
                updateDockVisibility(geometry: geometry)
            }
        }
    }
    
    private func updateDockVisibility(geometry: GeometryProxy) {
        let currentIsLandscape = geometry.size.width > geometry.size.height
        let shouldHideDockInLandscape = hideDockInLandscape && currentIsLandscape && isIPad
        
        withAnimation(.easeInOut(duration: 0.3)) {
            tabStateManager.isTabVisible = !keyboardManager.isKeyboardVisible &&
            !tabStateManager.shouldHideTabForCurrentView &&
            !shouldHideDockInLandscape
        }
    }
    
    private func colorForTab(_ index: Int) -> Color {
        if useAccentDockColor {
            return theme.accentColor
        }
        
        if useUnifiedDockColor {
            return unifiedColor
        }
        
        switch index {
        case 0:
            return signColor
        case 1:
            return filesColor
        case 2:
            return browseColor
        case 3:
            return downloadsColor
        case 4:
            return settingsColor
        default:
            return .white
        }
    }
    
    private func dockButton(for index: Int, item: TabItem) -> some View {
        Button {
            if !tabSelectionManager.isInitializing {
                HapticManager.shared.medium()
            }
            
            // Always call selectTab to track clicks, even for same tab
            tabSelectionManager.selectTab(index)
            
            // Visual feedback for tapping already selected tab
            if tabSelectionManager.selectedTab == index {
                NotificationCenter.default.post(name: .init("TabTapResponse"), object: index)
            }
        } label: {
            TabItemView(isSelected: tabSelectionManager.selectedTab == index,
                        item: item,
                        namespace: namespace,
                        selectedColor: colorForTab(index),
                        cornerRadius: innerCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dockBackground: some View {
        ZStack {
            // Only the translucent glass layers remain here
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
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
    }
}