import SwiftUI
import Combine

class StatusBarManager: ObservableObject {
    static let shared = StatusBarManager()
    
    @Published var colorfulClock: Bool = UserDefaults.standard.bool(forKey: "statusBar_colorfulClock") {
        didSet {
            UserDefaults.standard.set(colorfulClock, forKey: "statusBar_colorfulClock")
            shouldHideSystemStatusBar = colorfulClock
        }
    }
    
    @Published var hideAMPM: Bool = UserDefaults.standard.bool(forKey: "statusBar_hideAMPM") {
        didSet {
            UserDefaults.standard.set(hideAMPM, forKey: "statusBar_hideAMPM")
            updateTimeString()
        }
    }
    
    @Published var show24HourTime: Bool = UserDefaults.standard.bool(forKey: "statusBar_show24HourTime") {
        didSet {
            UserDefaults.standard.set(show24HourTime, forKey: "statusBar_show24HourTime")
            updateTimeString()
        }
    }
    
    @Published var currentTimeString: String = ""
    @Published var isLandscape: Bool = false
    @Published var shouldHideSystemStatusBar: Bool = false
    
    private var timerCancellable: AnyCancellable?
    private var orientationObserver: AnyCancellable?
    private var lastMinute: Int = -1
    
    private init() {
        shouldHideSystemStatusBar = colorfulClock
        updateTimeString()
        startTimer()
        startOrientationMonitoring()
    }
    
    deinit {
        orientationObserver?.cancel()
        timerCancellable?.cancel()
    }
    
    func updateStatusBar() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        updateTimeString()
    }
    
    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self = self else { return }
                let calendar = Calendar.current
                let newMinute = calendar.component(.minute, from: date)
                if newMinute != self.lastMinute {
                    self.lastMinute = newMinute
                    DispatchQueue.main.async {
                        self.updateTimeString()
                    }
                }
            }
    }
    
    private func updateTimeString() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if show24HourTime {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = hideAMPM ? "h:mm" : "h:mm a"
        }
        
        currentTimeString = formatter.string(from: Date())
    }
    
    private func startOrientationMonitoring() {
        orientationObserver = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { _ -> UIInterfaceOrientation? in
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
                return scene.interfaceOrientation
            }
            .removeDuplicates()
            .sink { [weak self] orientation in
                self?.isLandscape = orientation.isLandscape
            }
    }
}

struct StatusBarView: View {
    @EnvironmentObject var theme: Theme
    @ObservedObject private var statusBarManager = StatusBarManager.shared
    @ObservedObject private var paddingManager = PaddingManager.shared
    
    var body: some View {
        Group {
            if statusBarManager.colorfulClock && shouldShowInCurrentOrientation {
                statusBarContent
            }
        }
        .animation(.easeInOut(duration: 0.2), value: statusBarManager.colorfulClock)
        .animation(.easeInOut(duration: 0.2), value: statusBarManager.isLandscape)
        .onReceive(statusBarManager.$colorfulClock) { newValue in
        }
    }
    
    private var shouldShowInCurrentOrientation: Bool {
        if getDeviceType() == .iPadNoHomeButton || getDeviceType() == .iPadHomeButton {
            // For iPad devices (both home button and no home button), always show the clock regardless of orientation
            return true
        } else {
            // For other devices, hide in landscape mode
            return !statusBarManager.isLandscape
        }
    }
    
    private var statusBarContent: some View {
        HStack {
            Text(statusBarManager.currentTimeString)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.accentColor)
                .scaleEffect(paddingManager.clockScale)
                .fixedSize() // Prevent text from changing size during animations
                .padding(.horizontal)
                .padding(.top, paddingManager.clockYPadding)
                .padding(.leading, paddingManager.clockXPadding)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .edgesIgnoringSafeArea([.top, .leading, .trailing])
        .allowsHitTesting(false) // Prevent clock from interfering with touches
    }
}

struct StatusBarHiddenModifier: ViewModifier {
    let isHidden: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                updateStatusBarVisibility()
            }
            .onChange(of: isHidden) { _ in
                updateStatusBarVisibility()
            }
    }
    
    private func updateStatusBarVisibility() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            if let hostingController = window.rootViewController {
                // Force status bar update
                hostingController.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
}

extension View {
    func prefersStatusBarHidden(_ isHidden: Bool) -> some View {
        self.modifier(StatusBarHiddenModifier(isHidden: isHidden))
    }
}