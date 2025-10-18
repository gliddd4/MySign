//
//  DockItemView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

// MARK: - TabItemView

struct TabItemView: View {
    let isSelected: Bool
    let item: TabItem
    let namespace: Namespace.ID
    let selectedColor: Color
    let cornerRadius: CGFloat
    @State private var isHovered = false
    @State private var animatedSelected = false
    @State private var tapResponse = false
    
    var body: some View {
        ZStack {
            Image(systemName: item.icon)
                .imageScale(.large)
                .font(.system(size: 18, weight: animatedSelected ? .semibold : .medium))
                .foregroundColor(animatedSelected ? selectedColor : .white)
                .opacity(tapResponse ? 0.5 : 1.0)
            
            if animatedSelected {
                Image(systemName: item.icon)
                    .imageScale(.large)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selectedColor)
                    .opacity(tapResponse ? 0.5 : 1.0)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "selected",
                                                   in: namespace,
                                                   isSource: false)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onChange(of: isSelected) { newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatedSelected = newValue
            }
        }
        .onAppear {
            animatedSelected = isSelected
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("TabTapResponse"))) { notification in
            if let tappedIndex = notification.object as? Int,
               let currentIndex = TabItem.defaultItems.firstIndex(where: { $0.icon == item.icon }),
               tappedIndex == currentIndex {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    tapResponse = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        tapResponse = false
                    }
                }
            }
        }
    }
}