import SwiftUI

// MARK: - Hold and Release Button Style
struct HoldAndReleaseButtonStyle: ButtonStyle {
    let color: Color
    let accentColor: Color
    let icon: String?
    
    init(color: Color, accentColor: Color, icon: String? = nil) {
        self.color = color
        self.accentColor = accentColor
        self.icon = icon
    }
    
    @State private var visualProgress: CGFloat = 0.0
    @State private var hapticProgress: CGFloat = 0.0
    @State private var pressTimer: Timer?
    @State private var releaseTimer: Timer?
    @State private var holdTimer: Timer?
    @State private var currentPhase: AnimationPhase = .idle
    @State private var shouldStartReleaseAfterPress = false
    @State private var isHoldRegistered = false
    
    enum AnimationPhase {
        case idle, holding, pressing, pressed, releasing
    }
    
    private func backgroundGradient(progress: CGFloat) -> LinearGradient {
        let pressedColors = [
            Color.black, Color.black, Color.black, Color.black, Color.black,
            Color.black, Color.black, Color.black, Color.black
        ]
        
        let unpressedColors = [
            Color(red: 0.20, green: 0.20, blue: 0.20),
            Color(red: 0.15, green: 0.15, blue: 0.15),
            Color(red: 0.10, green: 0.10, blue: 0.10),
            Color(red: 0.05, green: 0.05, blue: 0.05),
            Color.black, Color.black, Color.black, Color.black, Color.black, Color.black
        ]
        
        let interpolatedColors = zip(unpressedColors, pressedColors).map { unpressed, pressed in
            unpressed.mixWith(pressed, by: Double(progress))
        }
        
        return LinearGradient(
            colors: interpolatedColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func outlineGradient(progress: CGFloat) -> LinearGradient {
        let startY = 0.5 + (progress * (-2.0))
        let endY = 1.1 + (progress * (-0.2))
        
        return LinearGradient(
            colors: [
                Color.clear,
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.6),
                Color.gray.opacity(0.8),
                Color.gray.opacity(1.0),
                Color.gray.opacity(1.0),
                Color.gray.opacity(1.0)
            ],
            startPoint: UnitPoint(x: 0.5, y: startY),
            endPoint: UnitPoint(x: 0.5, y: endY)
        )
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            configuration.label
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(buttonBackground)
        .shadow(
            color: Color.black.opacity(0.4 + (visualProgress * 0.2)),
            radius: 6 - (visualProgress * 2),
            x: 0,
            y: 3 - (visualProgress * 1)
        )
        .onChange(of: configuration.isPressed) { isPressed in
            handlePressChange(isPressed)
        }
    }
    
    private var buttonBackground: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundGradient(progress: visualProgress))
            
            // Static outline
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(red: 0.196, green: 0.196, blue: 0.196), lineWidth: 2.5)
            
            // Animated outline
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(outlineGradient(progress: visualProgress), lineWidth: 2.5)
        }
    }
    
    private func handlePressChange(_ isPressed: Bool) {
        if isPressed {
            releaseTimer?.invalidate()
            holdTimer?.invalidate()
            HapticManager.shared.stopDynamicHaptic()

            if currentPhase == .idle {
                currentPhase = .holding
                isHoldRegistered = false
                startHoldDetection()
            } else if currentPhase == .releasing {
                currentPhase = .holding
                isHoldRegistered = false
                startHoldDetection()
            }
        } else {
            // Stop all timers and haptics immediately
            holdTimer?.invalidate()
            pressTimer?.invalidate()
            HapticManager.shared.stopDynamicHaptic()
            
            // If no visual progress, just reset to idle
            if visualProgress == 0.0 {
                currentPhase = .idle
            } else {
                // Otherwise start release immediately from current position
                startReleaseAnimation()
            }
        }
    }
    
    private func startHoldDetection() {
        let holdDuration: TimeInterval = 0.1
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
            self.isHoldRegistered = true
            HapticManager.shared.medium()
            self.startPressAnimation()
        }
    }
    
    private func startPressAnimation() {
        print("▶️ Starting press animation - currentPhase: \(currentPhase), visualProgress: \(visualProgress)")
        currentPhase = .pressing
        let startTime = Date()
        let startProgress = visualProgress
        let duration: TimeInterval = 3.0
        
        HapticManager.shared.startDynamicIncreaseLinearWithSharpness()
        
        pressTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            let easedProgress = self.easeInOut(progress)
            let targetProgress = startProgress + (1.0 - startProgress) * easedProgress
            
            self.visualProgress = targetProgress
            
            if progress >= 1.0 {
                timer.invalidate()
                print("🎯 Press animation COMPLETED - setting currentPhase to .pressed, visualProgress: \(self.visualProgress)")
                self.currentPhase = .pressed
                self.visualProgress = 1.0
                self.hapticProgress = 1.0
                if self.shouldStartReleaseAfterPress {
                    self.shouldStartReleaseAfterPress = false
                    self.startReleaseAnimation()
                }
            }
        }
    }
    
    private func scheduleReleaseAfterPress() {
        shouldStartReleaseAfterPress = true
    }
    
    private func startReleaseAnimation() {
        print("🔄 Starting release animation - currentPhase: \(currentPhase), visualProgress: \(visualProgress)")
        
        // Check if button appears fully charged based on visual progress
        let appearsFullyCharged = (visualProgress >= 0.4)
        
        currentPhase = .releasing
        let startTime = Date()
        let startProgress: CGFloat = visualProgress
        let duration: TimeInterval = 0.12
        
        // Success haptic when button appears fully charged
        if appearsFullyCharged {
            print("✅ SUCCESS HAPTIC TRIGGERED - button appears fully charged (progress: \(visualProgress))")
            HapticManager.shared.success()
        } else {
            print("❌ No success haptic - button not fully charged (progress: \(visualProgress), needed: 0.4+)")
        }
        
        releaseTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min( elapsed / duration, 1.0)
            
            let easedProgress = self.easeInOut(progress)
            self.visualProgress = startProgress * (1.0 - easedProgress)
            self.hapticProgress = startProgress * (1.0 - easedProgress)
            
            if progress >= 1.0 {
                timer.invalidate()
                print("🏁 Release animation completed - setting currentPhase to .idle")
                self.currentPhase = .idle
                self.visualProgress = 0.0
                self.hapticProgress = 0.0
            }
        }
    }
    
    private func easeInOut(_ t: Double) -> CGFloat {
        let t = CGFloat(t)
        return t * t * (3.0 - 2.0 * t)
    }
}