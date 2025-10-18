import SwiftUI

// MARK: - Wide Toggle Style
struct WideToggle: ToggleStyle {
    @EnvironmentObject var themeAccent: Theme
    @Environment(\.isEnabled) private var isEnabled

    // Dimensions to match label height
    private let width: CGFloat = 103
    private let height: CGFloat = 23
    private let knobPadding: CGFloat = 2
    
    func makeBody(configuration: Configuration) -> some View {
        // Knob dimensions
        let knobHeight = height - (knobPadding * 2) 
        let knobWidth: CGFloat = 51

        // Calculate travel distance for the knob
        let maxTravel = (width / 2) - (knobWidth / 2) - knobPadding

        // The knob's position based on toggle state
        let knobPosition = configuration.isOn ? maxTravel : -maxTravel
        
        let tapGesture = TapGesture()
            .onEnded {
                HapticManager.shared.rigid()
                configuration.isOn.toggle()
            }

        return ZStack {
            // Background
            Capsule()
                .fill(backgroundGradient(isOn: configuration.isOn))
                .frame(width: width, height: height)

            // Knob
            Capsule() 
                .fill(Color.white)
                .frame(width: knobWidth, height: knobHeight)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                .offset(x: knobPosition)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isOn)
        .gesture(isEnabled ? tapGesture : nil)
        .allowsHitTesting(isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private func backgroundGradient(isOn: Bool) -> LinearGradient {
        // Create gradient colors based on theme
        let offColors = [
            Color(hex: "4A4A4A"),
            Color(hex: "363636"),
            Color(hex: "2A2A2A"),
            Color(hex: "1F1F1F")
        ]
        
        let onColors = [
            themeAccent.accentColor.lighter(by: 0.2),
            themeAccent.accentColor,
            themeAccent.accentColor.darker(by: 0.1),
            themeAccent.accentColor.darker(by: 0.2)
        ]
        
        // Use the appropriate gradient based on toggle state
        let finalColors = isOn ? onColors : offColors
        return LinearGradient(
            colors: finalColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Narrow Toggle Style
struct NarrowToggle: ToggleStyle {
    @EnvironmentObject var themeAccent: Theme
    @Environment(\.isEnabled) private var isEnabled

    // Dimensions - half the width of WideToggle
    private let width: CGFloat = 51.5
    private let height: CGFloat = 23
    private let knobPadding: CGFloat = 2
    
    func makeBody(configuration: Configuration) -> some View {
        // Knob dimensions
        let knobHeight = height - (knobPadding * 2) 
        let knobWidth: CGFloat = 25.5

        // Calculate travel distance for the knob
        let maxTravel = (width / 2) - (knobWidth / 2) - knobPadding

        // The knob's position based on toggle state
        let knobPosition = configuration.isOn ? maxTravel : -maxTravel
        
        let tapGesture = TapGesture()
            .onEnded {
                HapticManager.shared.rigid()
                configuration.isOn.toggle()
            }

        return ZStack {
            // Background
            Capsule()
                .fill(backgroundGradient(isOn: configuration.isOn))
                .frame(width: width, height: height)

            // Knob
            Capsule() 
                .fill(Color.white)
                .frame(width: knobWidth, height: knobHeight)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                .offset(x: knobPosition)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isOn)
        .gesture(isEnabled ? tapGesture : nil)
        .allowsHitTesting(isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private func backgroundGradient(isOn: Bool) -> LinearGradient {
        // Create gradient colors based on theme
        let offColors = [
            Color(hex: "4A4A4A"),
            Color(hex: "363636"),
            Color(hex: "2A2A2A"),
            Color(hex: "1F1F1F")
        ]
        
        let onColors = [
            themeAccent.accentColor.lighter(by: 0.2),
            themeAccent.accentColor,
            themeAccent.accentColor.darker(by: 0.1),
            themeAccent.accentColor.darker(by: 0.2)
        ]
        
        // Use the appropriate gradient based on toggle state
        let finalColors = isOn ? onColors : offColors
        return LinearGradient(
            colors: finalColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Adaptive Toggle Style
struct AdaptiveToggle: ToggleStyle {
    @EnvironmentObject var themeAccent: Theme
    
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if themeAccent.enableWideToggles {
                Toggle("", isOn: configuration.$isOn)
                    .toggleStyle(WideToggle())
                    .environmentObject(themeAccent)
            } else {
                Toggle("", isOn: configuration.$isOn)
                    .toggleStyle(NarrowToggle())
                    .environmentObject(themeAccent)
            }
        }
    }
}