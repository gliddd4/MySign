//
//  NewsOverlayView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import BezelKit

struct NewsOverlayView: View {
    let dismissAction: () -> Void
    @StateObject private var themeManager = Theme.shared
    @State private var offset = CGSize.zero
    @State private var isDismissing = false
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6"]
    private let cardSpacing: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            contentView(in: geometry)
                .transition(PopoverAnimation.transition)
        }
        .animation(nil, value: isDismissing)
        .onAppear {
            PopoverAnimation.animateAppear(offset: $offset)
        }
    }

    @MainActor
    private func dismissWithAnimation() {
        PopoverAnimation.animateDismiss(offset: $offset) {
            dismissAction()
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                withAnimation(PopoverAnimation.dragAnimation) {
                    offset.height = max(0, value.translation.height)
                }
            }
            .onEnded { value in
                let shouldDismiss = PopoverAnimation.shouldDismiss(
                    translation: value.translation.height,
                    predictedEndVelocity: value.predictedEndLocation.y - value.location.y
                )
                
                if shouldDismiss {
                    dismissWithAnimation()
                } else {
                    withAnimation(PopoverAnimation.recoveryAnimation) {
                        offset = .zero
                    }
                }
            }
    }

    private func contentView(in geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            MaterialBackgroundView()
                .edgesIgnoringSafeArea(.bottom)
                .zIndex(1)
                
            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(height: 5)
                .offset(y: -5)
                .zIndex(4)

            VStack(spacing: 0) {
                NewsHeaderView(dismissAction: dismissWithAnimation, themeManager: themeManager)
                    .background(.clear)
                    .zIndex(2)

                GeometryReader { cardGeometry in
                    let cardHeight = cardGeometry.size.width / 0.6 * 0.9
                    CardContainerView(
                        items: items,
                        containerSize: cardGeometry.size,
                        cardHeight: cardHeight,
                        cardSpacing: cardSpacing,
                        currentIndex: $currentIndex,
                        dragOffset: $dragOffset,
                        isDragging: $isDragging
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .zIndex(1)
            }
            .zIndex(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 10)
        .ignoresSafeArea(.container, edges: [.bottom])
        .offset(y: max(offset.height, 0))
        .gesture(dismissGesture)
    }
}