import SwiftUI
import BezelKit

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct MaterialBackgroundView: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Divider()
                        .opacity(0.08)
                }
                .clipShape(RoundedCorner(radius: .deviceBezel, corners: [.topLeft, .topRight]))
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct NewsCard: View {
    let title: String
    let verticalOffset: CGFloat
    let containerSize: CGSize
    let id: Int
    @ObservedObject private var themeManager = Theme.shared
    @State private var showingShareSheet = false
    
    private var cardWidth: CGFloat {
        containerSize.width * 0.9
    }
    
    private var baseHeight: CGFloat {
        cardWidth / 0.6
    }
    
    private var rotationAngle: Double {
        let normalizedOffset = Double(verticalOffset) / 300.0
        return normalizedOffset * 15.0
    }
    
    private var scale: CGFloat {
        let centerScale: CGFloat = 0.9
        let outerScale: CGFloat = 0.85
        let scaleRange = outerScale - centerScale
        let normalizedOffset = min(max(abs(verticalOffset) / 300.0, 0), 1)
        return centerScale + (normalizedOffset * scaleRange)
    }
    
    private var height: CGFloat {
        let centerHeight = baseHeight * 0.9
        let outerHeight = baseHeight * 0.85
        let heightDifference = outerHeight - centerHeight
        let normalizedOffset = min(max(abs(verticalOffset) / 300.0, 0), 1)
        return centerHeight + (normalizedOffset * heightDifference)
    }
    
    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            ZStack {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .frame(width: cardWidth, height: height)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .scaleEffect(scale)
                    .rotation3DEffect(
                        .degrees(rotationAngle),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.5
                    )
            }
            .frame(width: cardWidth * scale, height: height * scale)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .contextMenu {
                Group {
                    Button {
                        showingShareSheet = true
                        HapticManager.shared.medium()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        UIPasteboard.general.string = title
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.success("Copied to clipboard")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.warning("Save functionality coming soon")
                    } label: {
                        Label("Save", systemImage: "bookmark")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [title])
                    .edgesIgnoringSafeArea(.bottom)
            }
            Spacer()
        }
    }
}

struct NewsHeaderView: View {
    let dismissAction: () -> Void
    @ObservedObject var themeManager: Theme

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(width: 36, height: 5)
                .padding(.top, 4)
                .padding(.bottom, 4)

            ZStack {
                HStack {
                    Button {
                        HapticManager.shared.medium()
                        dismissAction()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 22))
                    }
                    .padding(.leading, 18)
                    .tint(themeManager.accentColor)
                    Spacer()
                }

                Text("News")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(height: 44)
        }
        .padding(.bottom, 8)
    }

    static let estimatedHeight: CGFloat = 5 + 4 + 4 + 44 + 8
}

struct CardContainerView: View {
    let items: [String]
    let containerSize: CGSize
    let cardHeight: CGFloat
    let cardSpacing: CGFloat
    @Binding var currentIndex: Int
    @Binding var dragOffset: CGFloat
    @Binding var isDragging: Bool

    private func animateToIndex(_ index: Int) {
        PopoverAnimation.animateToCardIndex(currentIndex: $currentIndex, newIndex: index, dragOffset: $dragOffset)
        HapticManager.shared.medium()
    }
    
    var body: some View {
        ZStack {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let offset = CGFloat(index - currentIndex)
                let totalOffset = (offset * (cardHeight * 0.7 + cardSpacing)) + dragOffset
                let zPosition = 1000.0 - abs(CGFloat(index) - CGFloat(currentIndex))

                NewsCard(
                    title: item,
                    verticalOffset: totalOffset,
                    containerSize: containerSize,
                    id: index
                )
                .padding(.horizontal)
                .offset(y: totalOffset)
                .zIndex(zPosition)
                .onTapGesture {
                    guard index != currentIndex, !isDragging else { return }
                    animateToIndex(index)
                }
                .animation(PopoverAnimation.cardAnimation, value: isDragging)
            }
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    isDragging = true
                    withAnimation(PopoverAnimation.cardInteractiveSpring) {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let velocity = value.predictedEndLocation.y - value.location.y

                    withAnimation(PopoverAnimation.cardAnimation) {
                        if abs(dragOffset) > PopoverAnimation.cardSensitivity || abs(velocity) > PopoverAnimation.cardVelocityThreshold {
                            if dragOffset > 0 && currentIndex > 0 {
                                currentIndex -= 1
                                HapticManager.shared.medium()
                            } else if dragOffset < 0 && currentIndex < items.count - 1 {
                                currentIndex += 1
                                HapticManager.shared.medium()
                            }
                        }
                        dragOffset = 0
                    }
                }
        )
    }
}
