//
//  DockStateManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Combine

// MARK: - State Managers

@MainActor
class TabStateManager: ObservableObject {
    static let shared = TabStateManager()
    @Published var isTabVisible = true
    @Published var shouldHideTabForCurrentView = false
    @Published var isDragHandleAutoHidden = false
    @Published var dragHandleSwipeConfirmationState: DragHandleSwipeConfirmationState = .none
    
    private var dragHandleAutoHideTimer: Timer?
    private let dragHandleAutoHideDelay: TimeInterval = 10.0 // 10 seconds
    
    enum DragHandleSwipeConfirmationState {
        case none
        case firstSwipeDetected
    }
    
    private init() {}
    
    func hideTabForView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldHideTabForCurrentView = true
        }
        cancelDragHandleAutoHideTimer()
    }
    
    func showTabForView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldHideTabForCurrentView = false
        }
    }
    
    func recordDragHandleInteraction() {
        // Show drag handle if it was auto-hidden
        if isDragHandleAutoHidden {
            showAutoHiddenDragHandle()
        }
        
        // Reset swipe confirmation
        dragHandleSwipeConfirmationState = .none
    }
    
    func handleDragHandleEdgeSwipe() {
        if isDragHandleAutoHidden {
            if dragHandleSwipeConfirmationState == .none {
                // First swipe - show confirmation state
                dragHandleSwipeConfirmationState = .firstSwipeDetected
                ToastManager.shared.showToast.log("Swipe right again to show drag handle")
                HapticManager.shared.light()
                
                // Reset confirmation after 3 seconds if no second swipe
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    if self.dragHandleSwipeConfirmationState == .firstSwipeDetected {
                        self.dragHandleSwipeConfirmationState = .none
                    }
                }
            } else if dragHandleSwipeConfirmationState == .firstSwipeDetected {
                // Second swipe - actually show the drag handle
                showAutoHiddenDragHandle()
                dragHandleSwipeConfirmationState = .none
                ToastManager.shared.showToast.log("Drag handle shown")
                HapticManager.shared.medium()
            }
        }
    }
    
    func startDragHandleAutoHideTimer() {
        // Auto-hide timer disabled per user request
    }
    
    private func cancelDragHandleAutoHideTimer() {
        dragHandleAutoHideTimer?.invalidate()
        dragHandleAutoHideTimer = nil
    }
    
    private func autoHideDragHandle() {
        guard !shouldHideTabForCurrentView else { return }
        
        // Start the state transition sequence by posting notifications
        // The FixedTabSwitcher will respond to these and handle the state changes
        NotificationCenter.default.post(name: .init("AutoCollapseTabBar"), object: nil)
        
        ToastManager.shared.showToast.log("Drag handle auto-hidden after inactivity")
        HapticManager.shared.light()
    }
    
    private func showAutoHiddenDragHandle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDragHandleAutoHidden = false
        }
        
        // Reset tab bar to normal state
        NotificationCenter.default.post(name: .init("RestoreTabBar"), object: nil)
    }
}