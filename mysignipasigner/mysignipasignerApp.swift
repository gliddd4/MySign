import SwiftUI
import CryptoKit

@main
struct mysignipasignerApp: SwiftUI.App {
    
    init() {
        DirectoryManager.shared.createAppFolders()
        // creates folders in documents folder on each app launch
    }

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    @StateObject var themeManagement = Theme.shared
    @StateObject private var tabStateManager = TabStateManager.shared // RENAMED: tabManager to tabStateManager for clarity
    @StateObject private var tabSelectionManager = TabSelectionManager.shared
    @StateObject private var installManager = NewInstall.shared
    @StateObject private var statusManager = StatusBarManager.shared
    @StateObject private var iconManager = IconManager.shared
    
    @AppStorage("app_installationID") private var installationID = ""
    
    var body: some Scene {
        WindowGroup {
            // Capture original safe area at the root level
            GeometryReader { rootGeometry in
                ZStack {
                    WelcomePopover()
                        .zIndex(100)
                    
                    MainContentView()
                        .environmentObject(themeManagement)
                        .environmentObject(tabStateManager)
                        .environmentObject(tabSelectionManager)
                        .environmentObject(statusManager)
                        .environmentObject(iconManager)
                }
                .environment(\.originalSafeArea, rootGeometry.safeAreaInsets)
            }
            .preferredColorScheme(.dark)
            .statusBar(hidden: statusManager.shouldHideSystemStatusBar)
            .buttonStyle(MainButtonStyle()) // Apply default button style app-wide
            .environmentObject(themeManagement)
            .environmentObject(RepositoryViewModel.shared)
            .environmentObject(tabStateManager)
            .environmentObject(tabSelectionManager)
            .environmentObject(installManager)
            .environmentObject(statusManager)
            .environmentObject(iconManager)
            .onAppear {
                setupInstallationID()
            }
            .onReceive(statusManager.$colorfulClock) { newValue in
                print("🔴 WindowGroup: Applying statusBar(hidden: \(newValue))")
            }
            .withThemeCursour()
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
    }
    
    private func setupInstallationID() {
        if installationID.isEmpty {
            installationID = UUID().uuidString
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        // Check if it's an IPA file
        if url.pathExtension.lowercased() == "ipa" {
            Task { @MainActor in
                DirectoryManager.shared.importIPAFile(from: url)
                // Switch to Files tab after importing
                TabSelectionManager.shared.selectTab(1)
            }
        }
    }
    
    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            DefaultSettings.initialize()
            return true
        }
        
        func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            return .all
        }
    }
}

private struct MainContentView: View {
    @State private var showingNewsOverlay = false
    @EnvironmentObject var statusManager: StatusBarManager

    var body: some View {
        ZStack(alignment: .top) {
            NavigationContent(showingNewsOverlay: $showingNewsOverlay)

            StatusBarView()
            
            FixedTabSwitcher()

            if showingNewsOverlay {
                NewsOverlayView(dismissAction: {
                    showingNewsOverlay = false
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(101)
            }
        }
    }
}

private struct NavigationContent: View {
    @EnvironmentObject var tabSelectionManager: TabSelectionManager
    @EnvironmentObject var statusManager: StatusBarManager
    @Binding var showingNewsOverlay: Bool
    
    @StateObject private var sideloadingViewModel = SideloadingViewModel()
    @StateObject private var ipaManager: IPAManager
    @StateObject private var pickerCoordinator = FilePickerCoordinator()
    
    init(showingNewsOverlay: Binding<Bool>) {
        self._showingNewsOverlay = showingNewsOverlay
        let viewModelInstance = SideloadingViewModel()
        self._sideloadingViewModel = StateObject(wrappedValue: viewModelInstance)
        self._ipaManager = StateObject(wrappedValue: IPAManager(sideloadingViewModel: viewModelInstance))
    }

    var body: some View {
        NavigationView {
            Group {
                switch tabSelectionManager.selectedTab {
                case 0:
                    SignView(
                        viewModel: sideloadingViewModel,
                        ipaManager: ipaManager,
                        pickerCoordinator: pickerCoordinator
                    )
                case 1:
                    FilesView()
                case 2:
                    BrowseView(showingNewsOverlay: $showingNewsOverlay)
                case 3:
                    DownloadsView()
                case 4:
                    SettingsView()
                default:
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
