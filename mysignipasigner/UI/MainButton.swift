import SwiftUI

// MARK: - Connected Button Group
struct ConnectedButtonGroup<Content: View>: View {
    @EnvironmentObject var themeAccent: Theme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, 1.25)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.176, green: 0.176, blue: 0.176))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(red: 0.235, green: 0.235, blue: 0.235), lineWidth: 2.5)
        )
        .environmentObject(themeAccent)
    }
}

// MARK: - Connected Button Item Modifier
extension View {
    func connectedButtonItem() -> some View {
        self.frame(maxWidth: .infinity)
            .background(Color.clear)
    }
    
    func withButtonSeparator() -> some View {
        ThickButtonSeparatorView(content: self)
    }
    
    func lastConnectedButton() -> some View {
        self
    }
}

private struct ThickButtonSeparatorView<Content: View>: View {
    let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
            Rectangle()
                .fill(Color(red: 0.235, green: 0.235, blue: 0.235))
                .frame(height: 2.5)
        }
    }
}

// MARK: - Main Button View (Standalone Component like UniversalButton)
struct MainButtonView: View {
    @EnvironmentObject var themeAccent: Theme
    @State private var isPressed = false
    let title: String
    let icon: String?
    let customImage: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.customImage = nil
        self.action = action
    }
    
    init(_ title: String, customImage: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = nil
        self.customImage = customImage
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Trigger haptic immediately like tab switcher
            HapticManager.shared.medium()
            action()
        }) {
            HStack(spacing: 8) {
                if let customImage = customImage {
                    Image(customImage)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .cornerRadius(3)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(themeAccent.accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(isPressed ? 0.2 : 0.1))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Split Main Button View (Two buttons horizontally split)
struct SplitMainButton: View {
    @EnvironmentObject var themeAccent: Theme
    @State private var leftIsPressed = false
    @State private var rightIsPressed = false
    
    let leftTitle: String
    let leftIcon: String?
    let leftCustomImage: String?
    let leftAction: () -> Void
    
    let rightTitle: String
    let rightIcon: String?
    let rightCustomImage: String?
    let rightAction: () -> Void
    
    init(
        left: (title: String, icon: String?, action: () -> Void),
        right: (title: String, icon: String?, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = left.icon
        self.leftCustomImage = nil
        self.leftAction = left.action
        
        self.rightTitle = right.title
        self.rightIcon = right.icon
        self.rightCustomImage = nil
        self.rightAction = right.action
    }
    
    init(
        left: (title: String, customImage: String, action: () -> Void),
        right: (title: String, customImage: String, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = nil
        self.leftCustomImage = left.customImage
        self.leftAction = left.action
        
        self.rightTitle = right.title
        self.rightIcon = nil
        self.rightCustomImage = right.customImage
        self.rightAction = right.action
    }
    
    init(
        left: (title: String, icon: String?, action: () -> Void),
        right: (title: String, customImage: String, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = left.icon
        self.leftCustomImage = nil
        self.leftAction = left.action
        
        self.rightTitle = right.title
        self.rightIcon = nil
        self.rightCustomImage = right.customImage
        self.rightAction = right.action
    }
    
    init(
        left: (title: String, customImage: String, action: () -> Void),
        right: (title: String, icon: String?, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = nil
        self.leftCustomImage = left.customImage
        self.leftAction = left.action
        
        self.rightTitle = right.title
        self.rightIcon = right.icon
        self.rightCustomImage = nil
        self.rightAction = right.action
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Left Button
            Button(action: {
                HapticManager.shared.medium()
                leftAction()
            }) {
                HStack(spacing: 8) {
                    if let customImage = leftCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                    } else if let icon = leftIcon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(leftTitle)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(leftIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    leftIsPressed = pressing
                }
            }, perform: {})
            
            // Right Button
            Button(action: {
                HapticManager.shared.medium()
                rightAction()
            }) {
                HStack(spacing: 8) {
                    if let customImage = rightCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                    } else if let icon = rightIcon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(rightTitle)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(rightIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    rightIsPressed = pressing
                }
            }, perform: {})
        }
    }
}

// MARK: - Triple Split Main Button View (Three buttons horizontally split)
struct TripleSplitMainButton: View {
    @EnvironmentObject var themeAccent: Theme
    @State private var leftIsPressed = false
    @State private var middleIsPressed = false
    @State private var rightIsPressed = false
    
    let leftTitle: String
    let leftIcon: String?
    let leftCustomImage: String?
    let leftAction: () -> Void
    
    let middleTitle: String
    let middleIcon: String?
    let middleCustomImage: String?
    let middleAction: () -> Void
    
    let rightTitle: String
    let rightIcon: String?
    let rightCustomImage: String?
    let rightAction: () -> Void
    
    init(
        left: (title: String, icon: String?, action: () -> Void),
        middle: (title: String, icon: String?, action: () -> Void),
        right: (title: String, icon: String?, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = left.icon
        self.leftCustomImage = nil
        self.leftAction = left.action
        
        self.middleTitle = middle.title
        self.middleIcon = middle.icon
        self.middleCustomImage = nil
        self.middleAction = middle.action
        
        self.rightTitle = right.title
        self.rightIcon = right.icon
        self.rightCustomImage = nil
        self.rightAction = right.action
    }
    
    init(
        left: (title: String, customImage: String, action: () -> Void),
        middle: (title: String, customImage: String, action: () -> Void),
        right: (title: String, icon: String?, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = nil
        self.leftCustomImage = left.customImage
        self.leftAction = left.action
        
        self.middleTitle = middle.title
        self.middleIcon = nil
        self.middleCustomImage = middle.customImage
        self.middleAction = middle.action
        
        self.rightTitle = right.title
        self.rightIcon = right.icon
        self.rightCustomImage = nil
        self.rightAction = right.action
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Left Button
            Button(action: {
                HapticManager.shared.medium()
                leftAction()
            }) {
                HStack(spacing: 6) {
                    if let customImage = leftCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = leftIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(leftTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(leftIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    leftIsPressed = pressing
                }
            }, perform: {})
            
            // Middle Button
            Button(action: {
                HapticManager.shared.medium()
                middleAction()
            }) {
                HStack(spacing: 6) {
                    if let customImage = middleCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = middleIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(middleTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(middleIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    middleIsPressed = pressing
                }
            }, perform: {})
            
            // Right Button
            Button(action: {
                HapticManager.shared.medium()
                rightAction()
            }) {
                HStack(spacing: 6) {
                    if let customImage = rightCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = rightIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(rightTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(rightIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    rightIsPressed = pressing
                }
            }, perform: {})
        }
    }
}

// MARK: - Four Split Main Button View (Four buttons horizontally split)
struct FourSplitMainButton: View {
    @EnvironmentObject var themeAccent: Theme
    @State private var leftIsPressed = false
    @State private var middle1IsPressed = false
    @State private var middle2IsPressed = false
    @State private var rightIsPressed = false
    
    let leftTitle: String
    let leftIcon: String?
    let leftCustomImage: String?
    let leftAction: () -> Void
    
    let middle1Title: String
    let middle1Icon: String?
    let middle1CustomImage: String?
    let middle1Action: () -> Void
    
    let middle2Title: String
    let middle2Icon: String?
    let middle2CustomImage: String?
    let middle2Action: () -> Void
    
    let rightTitle: String
    let rightIcon: String?
    let rightCustomImage: String?
    let rightAction: () -> Void
    
    init(
        left: (title: String, icon: String?, action: () -> Void),
        middle1: (title: String, icon: String?, action: () -> Void),
        middle2: (title: String, icon: String?, action: () -> Void),
        right: (title: String, icon: String?, action: () -> Void)
    ) {
        self.leftTitle = left.title
        self.leftIcon = left.icon
        self.leftCustomImage = nil
        self.leftAction = left.action
        
        self.middle1Title = middle1.title
        self.middle1Icon = middle1.icon
        self.middle1CustomImage = nil
        self.middle1Action = middle1.action
        
        self.middle2Title = middle2.title
        self.middle2Icon = middle2.icon
        self.middle2CustomImage = nil
        self.middle2Action = middle2.action
        
        self.rightTitle = right.title
        self.rightIcon = right.icon
        self.rightCustomImage = nil
        self.rightAction = right.action
    }
    
    var body: some View {
        HStack(spacing: 3) {
            // Left Button
            Button(action: {
                HapticManager.shared.medium()
                leftAction()
            }) {
                HStack(spacing: 5) {
                    if let customImage = leftCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = leftIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(leftTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(leftIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    leftIsPressed = pressing
                }
            }, perform: {})
            
            // Middle 1 Button
            Button(action: {
                HapticManager.shared.medium()
                middle1Action()
            }) {
                HStack(spacing: 5) {
                    if let customImage = middle1CustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = middle1Icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(middle1Title)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(middle1IsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    middle1IsPressed = pressing
                }
            }, perform: {})
            
            // Middle 2 Button
            Button(action: {
                HapticManager.shared.medium()
                middle2Action()
            }) {
                HStack(spacing: 5) {
                    if let customImage = middle2CustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = middle2Icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(middle2Title)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(middle2IsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    middle2IsPressed = pressing
                }
            }, perform: {})
            
            // Right Button
            Button(action: {
                HapticManager.shared.medium()
                rightAction()
            }) {
                HStack(spacing: 5) {
                    if let customImage = rightCustomImage {
                        Image(customImage)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .cornerRadius(2)
                    } else if let icon = rightIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(rightTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeAccent.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(rightIsPressed ? 0.2 : 0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    rightIsPressed = pressing
                }
            }, perform: {})
        }
    }
}
