import UIKit
import CoreHaptics
import AVFoundation

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?
    private var supportsHaptics: Bool {
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    private init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        guard supportsHaptics else {
            print("Device does not support haptics")
            return
        }
        
        do {
            // Configure AVAudioSession first
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            // Create haptic engine with audio session
            hapticEngine = try CHHapticEngine(audioSession: audioSession)
            
            // Configure engine to play haptics only (no audio)
            hapticEngine?.playsHapticsOnly = true
            
            // Start the engine
            try hapticEngine?.start()
            print("Haptic engine started successfully with playsHapticsOnly = true")
            
            // Add reset handler
            hapticEngine?.resetHandler = {
                print("Haptic engine reset - restarting...")
                DispatchQueue.main.async {
                    self.restartEngine()
                }
            }
            
            // Add stopped handler
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped with reason: \(reason)")
                switch reason {
                case .audioSessionInterrupt:
                    print("Audio session was interrupted")
                case .applicationSuspended:
                    print("Application was suspended")
                case .idleTimeout:
                    print("Engine idle timeout")
                case .systemError:
                    print("System error occurred")
                case .notifyWhenFinished:
                    print("Playback finished")
                case .gameControllerDisconnect:
                    print("Game controller disconnected")
                case .engineDestroyed:
                    print("Engine was destroyed")
                @unknown default:
                    print("Unknown stop reason")
                }
                
                // Attempt restart for recoverable errors
                if reason != .engineDestroyed && reason != .applicationSuspended {
                    DispatchQueue.main.async {
                        self.restartEngine()
                    }
                }
            }
            
        } catch {
            print("Failed to setup haptic engine: \(error)")
        }
    }
    
    private func restartEngine() {
        print("Attempting to restart haptic engine...")
        hapticPlayer = nil // Clear any existing player
        
        do {
            if let engine = hapticEngine {
                try engine.start()
                print("Haptic engine restarted successfully")
            } else {
                // Engine was destroyed, recreate it
                setupHapticEngine()
            }
        } catch {
            print("Failed to restart haptic engine: \(error)")
            // If restart fails, try to recreate the entire engine
            hapticEngine = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupHapticEngine()
            }
        }
    }
    
    private func ensureEngineRunning() -> Bool {
        guard supportsHaptics else { return false }
        
        guard let engine = hapticEngine else {
            print("Haptic engine is nil, attempting to recreate...")
            setupHapticEngine()
            return hapticEngine != nil
        }
        
        // Check if engine is running and restart if needed
        do {
            if engine.currentTime == 0 {
                // Engine might not be running
                try engine.start()
                print("Restarted haptic engine")
            }
            return true
        } catch {
            print("Engine not running, error: \(error)")
            restartEngine()
            return hapticEngine != nil
        }
    }
    
    // MARK: - Basic Feedback
    
    // Light feedback for most interactions
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Medium feedback for more significant changes
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Heavy feedback for important changes
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Rigid feedback - sharp, defined haptic feel (iOS 13+)
    func rigid() {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred()
        } else {
            heavy()
        }
    }
    
    // Soft feedback - gentler than light (iOS 13+)
    func soft() {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred()
        } else {
            light()
        }
    }
    
    // Success feedback
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    // Error feedback
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // Warning feedback
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    // MARK: - Dynamic Core Haptics Using Your Method
    
    struct Haptic: Hashable {
        var intensity: CGFloat
        var sharpness: CGFloat
        var interval: CGFloat
    }
    
    private func dynamicHaptic(haptics: [Haptic]) {
        guard ensureEngineRunning() else {
            print("Cannot start dynamic haptic - engine not available")
            return
        }
        
        guard let engine = hapticEngine else {
            print("Haptic engine not available after ensure check")
            return
        }
        
        print("Starting dynamic haptic with \(haptics.count) steps")
        
        // Stop any existing player first
        stopDynamicHaptic()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0)
        let intervals: [CGFloat] = haptics.map({ $0.interval })
        let totalDuration: TimeInterval = TimeInterval(intervals.reduce(0, +))
        var dynamicIntensity = [CHHapticDynamicParameter]()
        var dynamicSharpness = [CHHapticDynamicParameter]()
        
        for haptic in haptics {
            dynamicIntensity.append(CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(haptic.intensity), relativeTime: 0))
            dynamicSharpness.append(CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Float(haptic.sharpness), relativeTime: 0))
        }
        
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: totalDuration)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            hapticPlayer = player
            try player.start(atTime: 0)
            
            for index in 0..<haptics.count {
                let relativeInterval: TimeInterval = TimeInterval(intervals[0...index].reduce(-intervals[index], +))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + relativeInterval) {
                    // Check if player is still valid before sending parameters
                    guard let currentPlayer = self.hapticPlayer, currentPlayer === player else {
                        print("Haptic player was replaced or stopped, skipping parameter update")
                        return
                    }
                    
                    do {
                        try currentPlayer.sendParameters([dynamicIntensity[index], dynamicSharpness[index]], atTime: CHHapticTimeImmediate)
                        print("Sent haptic parameters: intensity=\(haptics[index].intensity), sharpness=\(haptics[index].sharpness)")
                    } catch {
                        print("Error sending parameters: \(error.localizedDescription)")
                        // If parameters fail to send, try to restart engine
                        if error.localizedDescription.contains("-4805") || error.localizedDescription.contains("not running") {
                            self.restartEngine()
                        }
                    }
                }
            }
        } catch {
            print("Error creating haptic pattern: \(error.localizedDescription)")
            // If pattern creation fails due to engine issues, try to restart
            if error.localizedDescription.contains("-4805") || error.localizedDescription.contains("not running") {
                restartEngine()
            }
        }
    }
    
    // Variation 1: Linear increase from 0 to 80% intensity
    func startDynamicIncreaseLinear() {
        let haptics: [Haptic] = [
            Haptic(intensity: 0.0, sharpness: 0.3, interval: 0.0),
            Haptic(intensity: 0.1, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.2, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.3, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.4, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.5, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.6, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.7, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.8, sharpness: 0.3, interval: 0.2)
        ]
        dynamicHaptic(haptics: haptics)
    }
    
    // Variation 1b: Linear increase with increasing sharpness
    func startDynamicIncreaseLinearWithSharpness() {
        let haptics: [Haptic] = [
            Haptic(intensity: 0.0, sharpness: 0.2, interval: 0.0),
            Haptic(intensity: 0.1, sharpness: 0.2, interval: 0.2),
            Haptic(intensity: 0.2, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.4, sharpness: 0.4, interval: 0.2),
            Haptic(intensity: 0.6, sharpness: 0.5, interval: 0.2),
            Haptic(intensity: 0.8, sharpness: 0.6, interval: 0.2),
            Haptic(intensity: 1.0, sharpness: 0.8, interval: 0.2),
            Haptic(intensity: 0.0, sharpness: 0.2, interval: 0.05)
        ]
        dynamicHaptic(haptics: haptics)
    }
    
    // Variation 2: Exponential increase - starts slow, builds quickly
    func startDynamicIncreaseExponential() {
        let haptics: [Haptic] = [
            Haptic(intensity: 0.0, sharpness: 0.4, interval: 0.0),
            Haptic(intensity: 0.05, sharpness: 0.4, interval: 0.3),
            Haptic(intensity: 0.1, sharpness: 0.4, interval: 0.3),
            Haptic(intensity: 0.2, sharpness: 0.4, interval: 0.2),
            Haptic(intensity: 0.4, sharpness: 0.4, interval: 0.2),
            Haptic(intensity: 0.6, sharpness: 0.4, interval: 0.15),
            Haptic(intensity: 0.8, sharpness: 0.4, interval: 0.15),
            Haptic(intensity: 1.0, sharpness: 0.4, interval: 0.1)
        ]
        dynamicHaptic(haptics: haptics)
    }
    
    // Variation 2b: Exponential increase with increasing sharpness
    func startDynamicIncreaseExponentialWithSharpness() {
        let haptics: [Haptic] = [
            Haptic(intensity: 0.0, sharpness: 0.1, interval: 0.0),
            Haptic(intensity: 0.05, sharpness: 0.2, interval: 0.3),
            Haptic(intensity: 0.1, sharpness: 0.3, interval: 0.3),
            Haptic(intensity: 0.2, sharpness: 0.4, interval: 0.2),
            Haptic(intensity: 0.4, sharpness: 0.5, interval: 0.2),
            Haptic(intensity: 0.6, sharpness: 0.6, interval: 0.15),
            Haptic(intensity: 0.8, sharpness: 0.8, interval: 0.15),
            Haptic(intensity: 1.0, sharpness: 1.0, interval: 0.1)
        ]
        dynamicHaptic(haptics: haptics)
    }

    
    // Build up and dramatic drop
    func startDynamicBuildAndDrop() {
        let haptics: [Haptic] = [
            Haptic(intensity: 0.0, sharpness: 0.2, interval: 0.0),
            Haptic(intensity: 0.1, sharpness: 0.2, interval: 0.2),
            Haptic(intensity: 0.2, sharpness: 0.3, interval: 0.2),
            Haptic(intensity: 0.4, sharpness: 0.4, interval: 0.2),
            Haptic(intensity: 0.6, sharpness: 0.5, interval: 0.2),
            Haptic(intensity: 0.8, sharpness: 0.6, interval: 0.2),
            Haptic(intensity: 1.0, sharpness: 0.8, interval: 0.2),
            Haptic(intensity: 0.0, sharpness: 0.2, interval: 0.05)
        ]
        dynamicHaptic(haptics: haptics)
    }

    // Stop any currently playing dynamic haptic
    func stopDynamicHaptic() {
        guard let player = hapticPlayer else {
            return // No message needed if no player exists
        }
        
        print("Stopping dynamic haptic")
        do {
            try player.stop(atTime: CHHapticTimeImmediate)
            print("Dynamic haptic stopped successfully")
        } catch {
            print("Failed to stop haptic player: \(error)")
            // Don't restart engine just for stop failures
        }
        hapticPlayer = nil
    }
    
    // MARK: - Continuous Haptic for Button Release
    
    func continuousHaptic(haptics: [Haptic]) {
        guard ensureEngineRunning() else {
            print("Cannot start continuous haptic - engine not available")
            return
        }
        
        guard let engine = hapticEngine else {
            print("Haptic engine not available after ensure check")
            return
        }
        
        let intervals: [CGFloat] = haptics.map { $0.interval }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0)
        let totalDuration: TimeInterval = TimeInterval(intervals[1..<haptics.count].reduce(0, +))
        var intensityControlPoints = [CHHapticParameterCurve.ControlPoint]()
        var sharpnessControlPoints = [CHHapticParameterCurve.ControlPoint]()
        
        for index in 0..<haptics.count {
            let relativeInterval: TimeInterval = TimeInterval(intervals[0...index].reduce(0, +))
            
            intensityControlPoints.append(CHHapticParameterCurve.ControlPoint(relativeTime: relativeInterval, value: Float(haptics[index].intensity)))
            sharpnessControlPoints.append(CHHapticParameterCurve.ControlPoint(relativeTime: relativeInterval, value: Float(haptics[index].sharpness)))
        }
    
        let intensityCurve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: intensityControlPoints, relativeTime: TimeInterval(intervals[0]))
        let sharpnessCurve = CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: sharpnessControlPoints, relativeTime: TimeInterval(intervals[0]))
    
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: TimeInterval(intervals[0]), duration: totalDuration)
    
        do {
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [intensityCurve, sharpnessCurve])
    
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Error creating continuous haptic pattern: \(error.localizedDescription)")
        }
    }
    
    // Predefined release haptic for MainButton - very light and soft
    func buttonReleaseHaptic() {
        let haptics: [Haptic] = [
            Haptic(intensity: 0.15, sharpness: 0.1, interval: 0.0),
            Haptic(intensity: 0.1, sharpness: 0.05, interval: 0.05)
        ]
        continuousHaptic(haptics: haptics)
    }
}