import SwiftUI

// MARK: - Default Main Button Style
struct MainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - Universal Button Component
struct UniversalButton: View {
    @EnvironmentObject var themeAccent: Theme
    @State private var isPressed = false
    let content: ButtonContent
    let action: () -> Void
    
    enum ButtonContent {
        case icon(String)
        case text(String)
        
        var isIcon: Bool {
            switch self {
            case .icon(_): return true
            case .text(_): return false
            }
        }
    }
    
    private let toggleWidth: CGFloat = 103
    
    private func calculateButtonWidth() -> CGFloat {
        switch content {
        case .icon(_):
            return 52
        case .text(let text):
            let font = UIFont.systemFont(ofSize: 10, weight: .semibold)
            let textSize = (text as NSString).size(withAttributes: [.font: font])
            let requiredWidth = textSize.width + 26
            
            let halfToggle = toggleWidth / 2
            let fullToggle = toggleWidth
            let threeHalfToggle = toggleWidth * 1.5
            let maxToggle = toggleWidth * 2
            
            if requiredWidth <= halfToggle {
                return halfToggle
            } else if requiredWidth <= fullToggle {
                return fullToggle
            } else if requiredWidth <= threeHalfToggle {
                return threeHalfToggle
            } else {
                return maxToggle
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeAccent.accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(isPressed ? 0.2 : 0.1))
                    )
                    .frame(width: calculateButtonWidth(), height: 23)
                
                switch content {
                case .icon(let iconName):
                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                case .text(let text):
                    Text(text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Connected Label Group
struct ConnectedLabelGroup<Content: View>: View {
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
        .background(themeAccent.labelBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .environmentObject(themeAccent)
    }
}

// MARK: - Connected Label Item Modifier
extension View {
    func connectedLabelItem() -> some View {
        self.frame(maxWidth: .infinity)
            .background(Color.clear)
    }
    
    func withThickSeparator() -> some View {
        ThickSeparatorView(content: self)
    }
}

private struct ThickSeparatorView<Content: View>: View {
    @EnvironmentObject var themeAccent: Theme
    let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Centered Section Header
struct CenteredSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 0)
    }
}

// MARK: - Disabled Label Style
extension View {
    func disabledLabelStyle(_ isDisabled: Bool) -> some View {
        self
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Content Types
enum UniversalLabelContent {
    case basic(String)
    case withIcon(String, String)
    case withCustomIcon(String, UIImage?, CGFloat, CGFloat, AnyShape?)
    case withValue(String, String)
    case withIconAndValue(String, String, String)
    case withToggle(String, Binding<Bool>)
    case withIconAndToggle(String, String, Binding<Bool>)
    case withTextInput(String, Binding<String>, String)
    case withIconAndTextInput(String, String, Binding<String>, String)
    case withButton(String, UniversalButton.ButtonContent, () -> Void)
    case withIconAndButton(String, String, UniversalButton.ButtonContent, () -> Void)
    case withValueAndButton(String, String, UniversalButton.ButtonContent, () -> Void)
    case withIconValueAndButton(String, String, String, UniversalButton.ButtonContent, () -> Void)
    case withTextInputAndButton(String, Binding<String>, String, UniversalButton.ButtonContent, () -> Void)
    case withIconTextInputAndButton(String, String, Binding<String>, String, UniversalButton.ButtonContent, () -> Void)
    case withDescription(String, String)
    case withIconAndDescription(String, String, String)
    case withDescriptionAndButton(String, String, UniversalButton.ButtonContent, () -> Void)
    case withIconDescriptionAndButton(String, String, String, UniversalButton.ButtonContent, () -> Void)
    case withDescriptionAndToggle(String, String, Binding<Bool>)
    case withIconDescriptionAndToggle(String, String, String, Binding<Bool>)
    case withMultilineTitle(String, UniversalButton.ButtonContent, () -> Void)
    case withCustomIconAndButton(String, UIImage?, UniversalButton.ButtonContent, () -> Void)
    case withBigIconTitleAndDescription(String, String, String, CGFloat)
    case withBigCustomIconTitleAndDescription(String, String, UIImage?, CGFloat, CGFloat, AnyShape?)
    case withBigIconTitleDescriptionAndButton(String, String, String, CGFloat, UniversalButton.ButtonContent, () -> Void)
    case withBigCustomIconTitleDescriptionAndButton(String, String, UIImage?, CGFloat, CGFloat, AnyShape?, UniversalButton.ButtonContent, () -> Void)
    case withBigIconTitleDescriptionAndSecondDescription(String, String, String, String, CGFloat)
    case withBigCustomIconTitleDescriptionAndSecondDescription(String, String, String, UIImage?, CGFloat, CGFloat, AnyShape?)
    case withBigIconTitleDescriptionSecondDescriptionAndButton(String, String, String, String, CGFloat, UniversalButton.ButtonContent, () -> Void)
    case withBigCustomIconTitleDescriptionSecondDescriptionAndButton(String, String, String, UIImage?, CGFloat, CGFloat, AnyShape?, UniversalButton.ButtonContent, () -> Void)
}

// MARK: - Universal Label Item (Main Component)
struct UniversalLabelItem: View {
    @EnvironmentObject var themeAccent: Theme
    let content: UniversalLabelContent
    let isConnected: Bool
    let showDivider: Bool
    let isLastItem: Bool
    
    init(content: UniversalLabelContent, isConnected: Bool = false, showDivider: Bool = true, isLastItem: Bool = false) {
        self.content = content
        self.isConnected = isConnected
        self.showDivider = showDivider
        self.isLastItem = isLastItem
    }
    
    var body: some View {
        VStack(spacing: 0) {
            contentView
                .if(isConnected) { view in
                    view.connectedLabelItem()
                }
                .if(!isConnected) { view in
                    view.background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(themeAccent.labelBackgroundColor)
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                    )
                }
            
            // Add divider for connected items that are not the last item
            if isConnected && !isLastItem {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1/3)
            }
        }
    }
    
    // MARK: - Layout Functions
    @ViewBuilder
    private var contentView: some View {
        switch content {
        case .basic(let title):
            basicLayout(title)
        case .withIcon(let title, let iconName):
            iconLayout(title, iconName)
        case .withCustomIcon(let title, let customIcon, let iconSize, let cornerRadius, let clipShape):
            customIconLayout(title, customIcon, iconSize, cornerRadius, clipShape)
        case .withValue(let title, let value):
            valueLayout(title, value)
        case .withIconAndValue(let title, let iconName, let value):
            iconValueLayout(title, iconName, value)
        case .withToggle(let title, let isOn):
            toggleLayout(title, isOn)
        case .withIconAndToggle(let title, let iconName, let isOn):
            iconToggleLayout(title, iconName, isOn)
        case .withTextInput(let title, let text, let placeholder):
            textInputLayout(title, text, placeholder)
        case .withIconAndTextInput(let title, let iconName, let text, let placeholder):
            iconTextInputLayout(title, iconName, text, placeholder)
        case .withButton(let title, let buttonContent, let action):
            buttonLayout(title, buttonContent, action)
        case .withIconAndButton(let title, let iconName, let buttonContent, let action):
            iconButtonLayout(title, iconName, buttonContent, action)
        case .withValueAndButton(let title, let value, let buttonContent, let action):
            valueButtonLayout(title, value, buttonContent, action)
        case .withIconValueAndButton(let title, let iconName, let value, let buttonContent, let action):
            iconValueButtonLayout(title, iconName, value, buttonContent, action)
        case .withTextInputAndButton(let title, let text, let placeholder, let buttonContent, let action):
            textInputButtonLayout(title, text, placeholder, buttonContent, action)
        case .withIconTextInputAndButton(let title, let iconName, let text, let placeholder, let buttonContent, let action):
            iconTextInputButtonLayout(title, iconName, text, placeholder, buttonContent, action)
        case .withDescription(let title, let description):
            descriptionLayout(title, description)
        case .withIconAndDescription(let title, let iconName, let description):
            iconDescriptionLayout(title, iconName, description)
        case .withDescriptionAndButton(let title, let description, let buttonContent, let action):
            descriptionButtonLayout(title, description, buttonContent, action)
        case .withIconDescriptionAndButton(let title, let iconName, let description, let buttonContent, let action):
            iconDescriptionButtonLayout(title, iconName, description, buttonContent, action)
        case .withDescriptionAndToggle(let title, let description, let isOn):
            descriptionToggleLayout(title, description, isOn)
        case .withIconDescriptionAndToggle(let title, let iconName, let description, let isOn):
            iconDescriptionToggleLayout(title, iconName, description, isOn)
        case .withMultilineTitle(let title, let buttonContent, let action):
            multilineTitleButtonLayout(title, buttonContent, action)
        case .withCustomIconAndButton(let title, let customIcon, let buttonContent, let action):
            customIconButtonLayout(title, customIcon, buttonContent, action)
        case .withBigIconTitleAndDescription(let title, let description, let iconName, let iconSize):
            bigIconTitleDescriptionLayout(title, description, iconName, iconSize)
        case .withBigCustomIconTitleAndDescription(let title, let description, let customIcon, let iconSize, let cornerRadius, let clipShape):
            bigCustomIconTitleDescriptionLayout(title, description, customIcon, iconSize, cornerRadius, clipShape)
        case .withBigIconTitleDescriptionAndButton(let title, let description, let iconName, let iconSize, let buttonContent, let action):
            bigIconTitleDescriptionButtonLayout(title, description, iconName, iconSize, buttonContent, action)
        case .withBigCustomIconTitleDescriptionAndButton(let title, let description, let customIcon, let iconSize, let cornerRadius, let clipShape, let buttonContent, let action):
            bigCustomIconTitleDescriptionButtonLayout(title, description, customIcon, iconSize, cornerRadius, clipShape, buttonContent, action)
        case .withBigIconTitleDescriptionAndSecondDescription(let title, let description, let secondDescription, let iconName, let iconSize):
            bigIconTitleDescriptionSecondDescriptionLayout(title, description, secondDescription, iconName, iconSize)
        case .withBigCustomIconTitleDescriptionAndSecondDescription(let title, let description, let secondDescription, let customIcon, let iconSize, let cornerRadius, let clipShape):
            bigCustomIconTitleDescriptionSecondDescriptionLayout(title, description, secondDescription, customIcon, iconSize, cornerRadius, clipShape)
        case .withBigIconTitleDescriptionSecondDescriptionAndButton(let title, let description, let secondDescription, let iconName, let iconSize, let buttonContent, let action):
            bigIconTitleDescriptionSecondDescriptionButtonLayout(title, description, secondDescription, iconName, iconSize, buttonContent, action)
        case .withBigCustomIconTitleDescriptionSecondDescriptionAndButton(let title, let description, let secondDescription, let customIcon, let iconSize, let cornerRadius, let clipShape, let buttonContent, let action):
            bigCustomIconTitleDescriptionSecondDescriptionButtonLayout(title, description, secondDescription, customIcon, iconSize, cornerRadius, clipShape, buttonContent, action)
        }
    }
    
    private func basicLayout(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconLayout(_ title: String, _ iconName: String) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func customIconLayout(_ title: String, _ customIcon: UIImage?, _ iconSize: CGFloat, _ cornerRadius: CGFloat, _ clipShape: AnyShape?) -> some View {
        HStack {
            if let customIcon = customIcon {
                Image(uiImage: customIcon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(clipShape ?? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func valueLayout(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconValueLayout(_ title: String, _ iconName: String, _ value: String) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func toggleLayout(_ title: String, _ isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(AdaptiveToggle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconToggleLayout(_ title: String, _ iconName: String, _ isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(AdaptiveToggle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func textInputLayout(_ title: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            textInputWrapper(text: text, placeholder: placeholder)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconTextInputLayout(_ title: String, _ iconName: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            textInputWrapper(text: text, placeholder: placeholder)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func buttonLayout(_ title: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconButtonLayout(_ title: String, _ iconName: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func valueButtonLayout(_ title: String, _ value: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconValueButtonLayout(_ title: String, _ iconName: String, _ value: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func textInputButtonLayout(_ title: String, _ text: Binding<String>, _ placeholder: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            textInputWrapper(text: text, placeholder: placeholder)
            
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func iconTextInputButtonLayout(_ title: String, _ iconName: String, _ text: Binding<String>, _ placeholder: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            textInputWrapper(text: text, placeholder: placeholder)
            
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func descriptionLayout(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func iconDescriptionLayout(_ title: String, _ iconName: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func descriptionButtonLayout(_ title: String, _ description: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                UniversalButton(content: buttonContent, action: action)
                    .environmentObject(themeAccent)
            }
            
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func iconDescriptionButtonLayout(_ title: String, _ iconName: String, _ description: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                UniversalButton(content: buttonContent, action: action)
                    .environmentObject(themeAccent)
            }
            
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func descriptionToggleLayout(_ title: String, _ description: String, _ isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(AdaptiveToggle())
            }
            
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func iconDescriptionToggleLayout(_ title: String, _ iconName: String, _ description: String, _ isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(AdaptiveToggle())
            }
            
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func multilineTitleButtonLayout(_ title: String, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                UniversalButton(content: buttonContent, action: action)
                    .environmentObject(themeAccent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
    }
    
    private func customIconButtonLayout(_ title: String, _ customIcon: UIImage?, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack {
            if let customIcon = customIcon {
                Image(uiImage: customIcon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            UniversalButton(content: buttonContent, action: action)
                .environmentObject(themeAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }
    
    private func bigIconTitleDescriptionLayout(_ title: String, _ description: String, _ iconName: String, _ iconSize: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: iconSize * 0.6, weight: .medium))
                .foregroundColor(.white)
                .frame(width: iconSize, height: iconSize)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigCustomIconTitleDescriptionLayout(_ title: String, _ description: String, _ customIcon: UIImage?, _ iconSize: CGFloat, _ cornerRadius: CGFloat, _ clipShape: AnyShape?) -> some View {
        HStack(spacing: 12) {
            if let customIcon = customIcon {
                Image(uiImage: customIcon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(clipShape ?? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: iconSize, height: iconSize)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigIconTitleDescriptionButtonLayout(_ title: String, _ description: String, _ iconName: String, _ iconSize: CGFloat, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: iconSize * 0.6, weight: .medium))
                .foregroundColor(.white)
                .frame(width: iconSize, height: iconSize)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Spacer()
                    
                    UniversalButton(content: buttonContent, action: action)
                        .environmentObject(themeAccent)
                }
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigCustomIconTitleDescriptionButtonLayout(_ title: String, _ description: String, _ customIcon: UIImage?, _ iconSize: CGFloat, _ cornerRadius: CGFloat, _ clipShape: AnyShape?, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            if let customIcon = customIcon {
                Image(uiImage: customIcon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(clipShape ?? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: iconSize, height: iconSize)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Spacer()
                    
                    UniversalButton(content: buttonContent, action: action)
                        .environmentObject(themeAccent)
                }
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigIconTitleDescriptionSecondDescriptionLayout(_ title: String, _ description: String, _ secondDescription: String, _ iconName: String, _ iconSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize * 0.6, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: iconSize, height: iconSize)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                
                Spacer()
            }
            
            Text(secondDescription)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigCustomIconTitleDescriptionSecondDescriptionLayout(_ title: String, _ description: String, _ secondDescription: String, _ customIcon: UIImage?, _ iconSize: CGFloat, _ cornerRadius: CGFloat, _ clipShape: AnyShape?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let customIcon = customIcon {
                    Image(uiImage: customIcon)
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(clipShape ?? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: iconSize, height: iconSize)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                
                Spacer()
            }
            
            Text(secondDescription)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigIconTitleDescriptionSecondDescriptionButtonLayout(_ title: String, _ description: String, _ secondDescription: String, _ iconName: String, _ iconSize: CGFloat, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize * 0.6, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: iconSize, height: iconSize)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                        
                        Spacer()
                        
                        UniversalButton(content: buttonContent, action: action)
                            .environmentObject(themeAccent)
                    }

                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
            }
            
            Text(secondDescription)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func bigCustomIconTitleDescriptionSecondDescriptionButtonLayout(_ title: String, _ description: String, _ secondDescription: String, _ customIcon: UIImage?, _ iconSize: CGFloat, _ cornerRadius: CGFloat, _ clipShape: AnyShape?, _ buttonContent: UniversalButton.ButtonContent, _ action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let customIcon = customIcon {
                    Image(uiImage: customIcon)
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(clipShape ?? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: iconSize, height: iconSize)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                        
                        Spacer()
                        
                        UniversalButton(content: buttonContent, action: action)
                            .environmentObject(themeAccent)
                    }
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
            }
            
            Text(secondDescription)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
    }
    
    private func textInputWrapper(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            TextField("", text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .textFieldStyle(PlainTextFieldStyle())
        }
    }
    
    // MARK: - Fluent API Methods
    func withIcon(_ iconName: String) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withIcon(title, iconName), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withValue(let title, let value):
            return UniversalLabelItem(content: .withIconAndValue(title, iconName, value), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withToggle(let title, let isOn):
            return UniversalLabelItem(content: .withIconAndToggle(title, iconName, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withTextInput(let title, let text, let placeholder):
            return UniversalLabelItem(content: .withIconAndTextInput(title, iconName, text, placeholder), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withButton(let title, let buttonContent, let action):
            return UniversalLabelItem(content: .withIconAndButton(title, iconName, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withDescription(let title, let description):
            return UniversalLabelItem(content: .withIconAndDescription(title, iconName, description), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withValue(_ value: String) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withValue(title, value), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIcon(let title, let iconName):
            return UniversalLabelItem(content: .withIconAndValue(title, iconName, value), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withButton(let title, let buttonContent, let action):
            return UniversalLabelItem(content: .withValueAndButton(title, value, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndButton(let title, let iconName, let buttonContent, let action):
            return UniversalLabelItem(content: .withIconValueAndButton(title, iconName, value, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withToggle(_ isOn: Binding<Bool>) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withToggle(title, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIcon(let title, let iconName):
            return UniversalLabelItem(content: .withIconAndToggle(title, iconName, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndDescription(let title, let iconName, let description):
            return UniversalLabelItem(content: .withIconDescriptionAndToggle(title, iconName, description, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withDescription(let title, let description):
            return UniversalLabelItem(content: .withDescriptionAndToggle(title, description, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withTextInput(_ text: Binding<String>, placeholder: String = "") -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withTextInput(title, text, placeholder), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIcon(let title, let iconName):
            return UniversalLabelItem(content: .withIconAndTextInput(title, iconName, text, placeholder), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withButton(let title, let buttonContent, let action):
            return UniversalLabelItem(content: .withTextInputAndButton(title, text, placeholder, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndButton(let title, let iconName, let buttonContent, let action):
            return UniversalLabelItem(content: .withIconTextInputAndButton(title, iconName, text, placeholder, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withButton(_ buttonContent: UniversalButton.ButtonContent, action: @escaping () -> Void) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withButton(title, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIcon(let title, let iconName):
            return UniversalLabelItem(content: .withIconAndButton(title, iconName, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withValue(let title, let value):
            return UniversalLabelItem(content: .withValueAndButton(title, value, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndValue(let title, let iconName, let value):
            return UniversalLabelItem(content: .withIconValueAndButton(title, iconName, value, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withTextInput(let title, let text, let placeholder):
            return UniversalLabelItem(content: .withTextInputAndButton(title, text, placeholder, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndTextInput(let title, let iconName, let text, let placeholder):
            return UniversalLabelItem(content: .withIconTextInputAndButton(title, iconName, text, placeholder, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withDescription(let title, let description):
            return UniversalLabelItem(content: .withDescriptionAndButton(title, description, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndDescription(let title, let iconName, let description):
            return UniversalLabelItem(content: .withIconDescriptionAndButton(title, iconName, description, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withCustomIcon(let title, let customIcon, _, _, _):
            return UniversalLabelItem(content: .withCustomIconAndButton(title, customIcon, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withDescription(_ description: String) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withDescription(title, description), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIcon(let title, let iconName):
            return UniversalLabelItem(content: .withIconAndDescription(title, iconName, description), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withToggle(let title, let isOn):
            return UniversalLabelItem(content: .withDescriptionAndToggle(title, description, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndToggle(let title, let iconName, let isOn):
            return UniversalLabelItem(content: .withIconDescriptionAndToggle(title, iconName, description, isOn), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withButton(let title, let buttonContent, let action):
            return UniversalLabelItem(content: .withDescriptionAndButton(title, description, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        case .withIconAndButton(let title, let iconName, let buttonContent, let action):
            return UniversalLabelItem(content: .withIconDescriptionAndButton(title, iconName, description, buttonContent, action), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withBigIconTitleAndDescription(_ description: String, iconName: String, iconSize: CGFloat = 40) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withBigIconTitleAndDescription(title, description, iconName, iconSize), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withBigCustomIconTitleAndDescription(_ description: String, customIcon: UIImage?, iconSize: CGFloat = 40, cornerRadius: CGFloat = 8, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withBigCustomIconTitleAndDescription(title, description, customIcon, iconSize, cornerRadius, clipShape), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withBigIconTitleDescriptionAndSecondDescription(_ description: String, _ secondDescription: String, iconName: String, iconSize: CGFloat = 40) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withBigIconTitleDescriptionAndSecondDescription(title, description, secondDescription, iconName, iconSize), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withBigCustomIconTitleDescriptionAndSecondDescription(_ description: String, _ secondDescription: String, customIcon: UIImage?, iconSize: CGFloat = 40, cornerRadius: CGFloat = 8, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        switch content {
        case .basic(let title):
            return UniversalLabelItem(content: .withBigCustomIconTitleDescriptionAndSecondDescription(title, description, secondDescription, customIcon, iconSize, cornerRadius, clipShape), isConnected: isConnected, showDivider: showDivider, isLastItem: isLastItem)
        default:
            return self
        }
    }
    
    func withoutDivider() -> UniversalLabelItem {
        UniversalLabelItem(content: content, isConnected: isConnected, showDivider: false, isLastItem: isLastItem)
    }
    
    func lastConnectedItem() -> UniversalLabelItem {
        UniversalLabelItem(content: content, isConnected: isConnected, showDivider: showDivider, isLastItem: true)
    }
}

// MARK: - Helper for type-erased shapes
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Simplified Universal Label API
struct UniversalLabel: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        UniversalLabelItem(content: .basic(title), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withIcon(_ iconName: String) -> UniversalLabelItem {
        UniversalLabelItem(content: .withIcon(title, iconName), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withValue(_ value: String) -> UniversalLabelItem {
        UniversalLabelItem(content: .withValue(title, value), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withToggle(_ isOn: Binding<Bool>) -> UniversalLabelItem {
        UniversalLabelItem(content: .withToggle(title, isOn), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withTextInput(_ text: Binding<String>, placeholder: String = "") -> UniversalLabelItem {
        UniversalLabelItem(content: .withTextInput(title, text, placeholder), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withButton(_ buttonContent: UniversalButton.ButtonContent, action: @escaping () -> Void) -> UniversalLabelItem {
        UniversalLabelItem(content: .withButton(title, buttonContent, action), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withDescription(_ description: String) -> UniversalLabelItem {
        UniversalLabelItem(content: .withDescription(title, description), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withCustomIcon(_ customIcon: UIImage?, iconSize: CGFloat = 20, cornerRadius: CGFloat = 4, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        UniversalLabelItem(content: .withCustomIcon(title, customIcon, iconSize, cornerRadius, clipShape), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withBigIconTitleAndDescription(_ description: String, iconName: String, iconSize: CGFloat = 40) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigIconTitleAndDescription(title, description, iconName, iconSize), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withBigCustomIconTitleAndDescription(_ description: String, customIcon: UIImage?, iconSize: CGFloat = 40, cornerRadius: CGFloat = 8, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigCustomIconTitleAndDescription(title, description, customIcon, iconSize, cornerRadius, clipShape), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withBigIconTitleDescriptionAndSecondDescription(_ description: String, _ secondDescription: String, iconName: String, iconSize: CGFloat = 40) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigIconTitleDescriptionAndSecondDescription(title, description, secondDescription, iconName, iconSize), isConnected: false, showDivider: true, isLastItem: false)
    }
    
    func withBigCustomIconTitleDescriptionAndSecondDescription(_ description: String, _ secondDescription: String, customIcon: UIImage?, iconSize: CGFloat = 40, cornerRadius: CGFloat = 8, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigCustomIconTitleDescriptionAndSecondDescription(title, description, secondDescription, customIcon, iconSize, cornerRadius, clipShape), isConnected: false, showDivider: true, isLastItem: false)
    }
}

struct ConnectedUniversalLabel: View {
    let title: String
    private var showDivider: Bool = true
    private var isLastItem: Bool = false
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        UniversalLabelItem(content: .basic(title), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withoutDivider() -> ConnectedUniversalLabel {
        var copy = self
        copy.showDivider = false
        return copy
    }
    
    func lastConnectedItem() -> ConnectedUniversalLabel {
        var copy = self
        copy.isLastItem = true
        return copy
    }
    
    func withIcon(_ iconName: String) -> UniversalLabelItem {
        UniversalLabelItem(content: .withIcon(title, iconName), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withValue(_ value: String) -> UniversalLabelItem {
        UniversalLabelItem(content: .withValue(title, value), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withToggle(_ isOn: Binding<Bool>) -> UniversalLabelItem {
        UniversalLabelItem(content: .withToggle(title, isOn), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withTextInput(_ text: Binding<String>, placeholder: String = "") -> UniversalLabelItem {
        UniversalLabelItem(content: .withTextInput(title, text, placeholder), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withButton(_ buttonContent: UniversalButton.ButtonContent, action: @escaping () -> Void) -> UniversalLabelItem {
        UniversalLabelItem(content: .withButton(title, buttonContent, action), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withDescription(_ description: String) -> UniversalLabelItem {
        UniversalLabelItem(content: .withDescription(title, description), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withCustomIcon(_ customIcon: UIImage?, iconSize: CGFloat = 20, cornerRadius: CGFloat = 4, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        UniversalLabelItem(content: .withCustomIcon(title, customIcon, iconSize, cornerRadius, clipShape), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withBigIconTitleAndDescription(_ description: String, iconName: String, iconSize: CGFloat = 40) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigIconTitleAndDescription(title, description, iconName, iconSize), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withBigCustomIconTitleAndDescription(_ description: String, customIcon: UIImage?, iconSize: CGFloat = 40, cornerRadius: CGFloat = 8, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigCustomIconTitleAndDescription(title, description, customIcon, iconSize, cornerRadius, clipShape), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withBigIconTitleDescriptionAndSecondDescription(_ description: String, _ secondDescription: String, iconName: String, iconSize: CGFloat = 40) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigIconTitleDescriptionAndSecondDescription(title, description, secondDescription, iconName, iconSize), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
    
    func withBigCustomIconTitleDescriptionAndSecondDescription(_ description: String, _ secondDescription: String, customIcon: UIImage?, iconSize: CGFloat = 40, cornerRadius: CGFloat = 8, clipShape: AnyShape? = nil) -> UniversalLabelItem {
        UniversalLabelItem(content: .withBigCustomIconTitleDescriptionAndSecondDescription(title, description, secondDescription, customIcon, iconSize, cornerRadius, clipShape), isConnected: true, showDivider: showDivider, isLastItem: isLastItem)
    }
}

// MARK: - Big Icon Title Description Component (Standalone)
struct BigIconTitleDescriptionLabel: View {
    @EnvironmentObject var themeAccent: Theme
    let title: String
    let description: String
    let iconName: String?
    let customIcon: UIImage?
    let iconSize: CGFloat
    let cornerRadius: CGFloat
    let clipShape: AnyShape?
    let isConnected: Bool
    let buttonContent: UniversalButton.ButtonContent?
    let buttonAction: (() -> Void)?
    let secondDescription: String?
    
    init(
        title: String,
        description: String,
        iconName: String? = nil,
        customIcon: UIImage? = nil,
        iconSize: CGFloat = 40,
        cornerRadius: CGFloat = 8,
        clipShape: AnyShape? = nil,
        isConnected: Bool = false,
        buttonContent: UniversalButton.ButtonContent? = nil,
        buttonAction: (() -> Void)? = nil,
        secondDescription: String? = nil
    ) {
        self.title = title
        self.description = description
        self.iconName = iconName
        self.customIcon = customIcon
        self.iconSize = iconSize
        self.cornerRadius = cornerRadius
        self.clipShape = clipShape
        self.isConnected = isConnected
        self.buttonContent = buttonContent
        self.buttonAction = buttonAction
        self.secondDescription = secondDescription
    }
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: secondDescription != nil ? 8 : 0) {
            HStack(spacing: 12) {
                iconView
                
                VStack(alignment: .leading, spacing: 4) {
                    if let buttonContent = buttonContent, let buttonAction = buttonAction {
                        HStack {
                            Text(title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                            
                            Spacer()
                            
                            UniversalButton(content: buttonContent, action: buttonAction)
                                .environmentObject(themeAccent)
                        }
                    } else {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                    }
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                
                if buttonContent == nil {
                    Spacer()
                }
            }
            
            if let secondDescription = secondDescription {
                Text(secondDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: max(iconSize + 24, 60))
        
        if isConnected {
            content.connectedLabelItem()
        } else {
            content.background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeAccent.labelBackgroundColor)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            )
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let iconName = iconName {
            Image(systemName: iconName)
                .font(.system(size: iconSize * 0.6, weight: .medium))
                .foregroundColor(.white)
                .frame(width: iconSize, height: iconSize)
        } else if let customIcon = customIcon {
            Image(uiImage: customIcon)
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .clipShape(clipShape ?? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.3))
                .frame(width: iconSize, height: iconSize)
        }
    }
}
