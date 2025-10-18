//
//  BrowseView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UniformTypeIdentifiers

struct BrowseView: View {
    @State var searchText: String = ""
    @StateObject var viewModel = RepositoryViewModel.shared
    @State var expandedRepositories: Set<String> = []
    @ObservedObject var iconManager = IconManager.shared
    @StateObject var themeManager = Theme.shared
    @StateObject var downloadManager = DownloadManager.shared
    @State var orderedRepositories: [String] = []
    @Binding var showingNewsOverlay: Bool
    @State private var appSortOption: AppSortOption = .aToZ
    @State private var repositorySortOption: RepositorySortOption = .aToZ
    @State private var hasLoadedInitialSortOptions = false
    @State private var hasAppeared = false
    
    @State private var navigationId = UUID()
    @State private var selectedTab: BrowseTab = .all
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasBeenInBackground = false
    
    @State private var isSearchActive = false
    @FocusState private var searchFieldIsFocused: Bool
    @ObservedObject private var keyboardManager = KeyboardManager.shared
    
    private let springResponse: Double = 0.6
    private let springDamping: Double = 0.7

    @State private var showingAddSheet = false
    @State private var sheetId = UUID()
    @AppStorage("ui_hideDragBar") private var hideDragBar = true
    
    // Static variable to track if Browse tab has appeared in this app session
    private static var hasAppearedInSession = false
    
    // Static variable to track app launch state
    private static var isAppLaunch = true

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if selectedTab == .all {
                    RepositoryListView(
                        viewModel: viewModel,
                        themeManager: themeManager,
                        downloadManager: downloadManager,
                        searchText: $searchText,
                        expandedRepositories: $expandedRepositories,
                        orderedRepositories: $orderedRepositories,
                        appSortOption: appSortOption,
                        repositorySortOption: repositorySortOption,
                        hasLoadedInitialSortOptions: hasLoadedInitialSortOptions
                    )
                    .id(navigationId)
                    .refreshable {
                        await viewModel.fetchRepositories()
                        // Clear fallback icons if the setting is disabled
                        await viewModel.clearFallbackIconsIfDisabled()
                    }
                    .accentColor(themeManager.accentColor)
                    .animation(PopoverAnimation.animation, value: showingNewsOverlay)
                    .onAppear {
                        loadFromUserDefaults()
                        ensureAllRepositoriesAreTracked()
                        loadSortOptions()
                        
                        if Self.isAppLaunch || !Self.hasAppearedInSession {
                            // App launch: start with all repositories collapsed
                            expandedRepositories = []
                            ToastManager.shared.showToast.log("App launched - starting with all repositories collapsed")
                            Self.hasAppearedInSession = true
                            Self.isAppLaunch = false
                        } else {
                            // Tab switch: restore previously expanded state
                            loadSavedExpandedState()
                            ToastManager.shared.showToast.log("Returned to Browse tab - restored expanded state")
                        }
                    }
                    .onDisappear {
                        UserDefaults.standard.set(orderedRepositories, forKey: "repositories_ordered")
                        saveExpandedRepositories()
                        UserDefaults.standard.synchronize()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        saveExpandedRepositories()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // App is reopening
                    }
                    .onChange(of: scenePhase) { phase in
                        switch phase {
                        case .background:
                            hasBeenInBackground = true
                            // Save current expanded state when going to background
                            UserDefaults.standard.set(Array(expandedRepositories), forKey: "expanded_repositories")
                            ToastManager.shared.showToast.log("App went to background - saved expanded state")
                        case .active:
                            if hasBeenInBackground {
                                hasBeenInBackground = false
                                ToastManager.shared.showToast.log("App reopened - maintaining expanded repositories")
                                // Reset the app launch state when coming back from background
                                Self.isAppLaunch = true
                                Self.hasAppearedInSession = false
                            }
                        default:
                            break
                        }
                    }
                } else {
                    NewsView()
                        .accentColor(themeManager.accentColor)
                        .onAppear {
                            ToastManager.shared.showToast.log("Switched to News tab")
                        }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 20)
            }
            
            NavigationManager.browseNavigation(
                selectedTab: $selectedTab,
                trailingItems: [
                    NavigationItem(
                        icon: "magnifyingglass",
                        name: "Search",
                        action: {
                            HapticManager.shared.medium()
                            ToastManager.shared.showToast.log("Clicked Search (toolbar) in Browse")
                            isSearchActive = true
                        }
                    ),
                    NavigationItem(
                        icon: "arrow.up.arrow.down",
                        name: "Sort",
                        menu: {
                            Group {
                                Menu {
                                    Button(action: {
                                        appSortOption = .default
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(AppSortOption.default.rawValue, forKey: "app_sort_option")
                                        ToastManager.shared.showToast.log("App sort changed to: Default")
                                    }) {
                                        if appSortOption == .default {
                                            Label("Default", systemImage: "checkmark")
                                        } else {
                                            Text("Default")
                                        }
                                    }
                                    Button(action: {
                                        appSortOption = .aToZ
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(AppSortOption.aToZ.rawValue, forKey: "app_sort_option")
                                        ToastManager.shared.showToast.log("App sort changed to: A-Z")
                                    }) {
                                        if appSortOption == .aToZ {
                                            Label("A-Z", systemImage: "checkmark")
                                        } else {
                                            Text("A-Z")
                                        }
                                    }
                                    Button(action: {
                                        appSortOption = .zToA
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(AppSortOption.zToA.rawValue, forKey: "app_sort_option")
                                        ToastManager.shared.showToast.log("App sort changed to: Z-A")
                                    }) {
                                        if appSortOption == .zToA {
                                            Label("Z-A", systemImage: "checkmark")
                                        } else {
                                            Text("Z-A")
                                        }
                                    }
                                    Button(action: {
                                        appSortOption = .latest
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(AppSortOption.latest.rawValue, forKey: "app_sort_option")
                                        ToastManager.shared.showToast.log("App sort changed to: Newest")
                                    }) {
                                        if appSortOption == .latest {
                                            Label("Newest", systemImage: "checkmark")
                                        } else {
                                            Text("Newest")
                                        }
                                    }
                                    Button(action: {
                                        appSortOption = .oldest
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(AppSortOption.oldest.rawValue, forKey: "app_sort_option")
                                        ToastManager.shared.showToast.log("App sort changed to: Oldest")
                                    }) {
                                        if appSortOption == .oldest {
                                            Label("Oldest", systemImage: "checkmark")
                                        } else {
                                            Text("Oldest")
                                        }
                                    }
                                } label: {
                                    Label("App Sort", systemImage: "rectangle.stack")
                                }
                                
                                Menu {
                                    Button(action: {
                                        repositorySortOption = .aToZ
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(RepositorySortOption.aToZ.rawValue, forKey: "repository_sort_option")
                                        ToastManager.shared.showToast.log("Repository sort changed to: A-Z")
                                    }) {
                                        if repositorySortOption == .aToZ {
                                            Label("A-Z", systemImage: "checkmark")
                                        } else {
                                            Text("A-Z")
                                        }
                                    }
                                    Button(action: {
                                        repositorySortOption = .zToA
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(RepositorySortOption.zToA.rawValue, forKey: "repository_sort_option")
                                        ToastManager.shared.showToast.log("Repository sort changed to: Z-A")
                                    }) {
                                        if repositorySortOption == .zToA {
                                            Label("Z-A", systemImage: "checkmark")
                                        } else {
                                            Text("Z-A")
                                        }
                                    }
                                    Button(action: {
                                        repositorySortOption = .mostApps
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(RepositorySortOption.mostApps.rawValue, forKey: "repository_sort_option")
                                        ToastManager.shared.showToast.log("Repository sort changed to: Most Apps")
                                    }) {
                                        if repositorySortOption == .mostApps {
                                            Label("Most Apps", systemImage: "checkmark")
                                        } else {
                                            Text("Most Apps")
                                        }
                                    }
                                    Button(action: {
                                        repositorySortOption = .leastApps
                                        HapticManager.shared.medium()
                                        UserDefaults.standard.set(RepositorySortOption.leastApps.rawValue, forKey: "repository_sort_option")
                                        ToastManager.shared.showToast.log("Repository sort changed to: Least Apps")
                                    }) {
                                        if repositorySortOption == .leastApps {
                                            Label("Least Apps", systemImage: "checkmark")
                                        } else {
                                            Text("Least Apps")
                                        }
                                    }
                                } label: {
                                    Label("Repository Sort", systemImage: "shippingbox")
                                }
                            }
                        }, action: {
                            ToastManager.shared.showToast.log("Clicked Sort (toolbar) in Browse")
                        }
                    ),
                    NavigationItem(
                        icon: "plus",
                        name: "Add",
                        action: {
                            HapticManager.shared.medium()
                            ToastManager.shared.showToast.log("Clicked Repository Manager (toolbar) in Browse")
                            sheetId = UUID()
                            showingAddSheet = true
                        }
                    )
                ]
            )
            .zIndex(1)

            if isSearchActive {
                VStack(spacing: 0) {
                    Spacer()
                    
                    TextField("Search IPAs", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.5))
                        .focused($searchFieldIsFocused)
                        .onSubmit {
                            isSearchActive = false
                        }
                }
                .edgesIgnoringSafeArea(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: isSearchActive)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .sheet(isPresented: $showingAddSheet,
              onDismiss: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    sheetId = UUID()
                }
              }) {
            AddView(
                viewModel: viewModel,
                themeManager: themeManager
            )
            .id(sheetId)
        }
        .onChange(of: isSearchActive) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFieldIsFocused = true
                }
            }
        }
    }
    
    private func loadFromUserDefaults() {
        orderedRepositories = UserDefaults.standard.array(forKey: "repositories_ordered") as? [String] ?? []
    }
    
    private func ensureAllRepositoriesAreTracked() {
        let allRepoIds = Set(viewModel.repositories.map { $0.id })
        
        for repoId in allRepoIds where !orderedRepositories.contains(repoId) {
            orderedRepositories.append(repoId)
        }
        
        orderedRepositories.removeAll { !allRepoIds.contains($0) }
        UserDefaults.standard.set(orderedRepositories, forKey: "repositories_ordered")
    }
    
    private func loadSortOptions() {
        if let savedAppSort = UserDefaults.standard.object(forKey: "app_sort_option") as? String {
            appSortOption = AppSortOption(rawValue: savedAppSort) ?? .aToZ
        }
        
        if let savedRepoSort = UserDefaults.standard.object(forKey: "repository_sort_option") as? String {
            repositorySortOption = RepositorySortOption(rawValue: savedRepoSort) ?? .aToZ
        }
        
        hasLoadedInitialSortOptions = true
    }
    
    private func loadSavedExpandedState() {
        if let savedExpanded = UserDefaults.standard.array(forKey: "expanded_repositories") as? [String] {
            expandedRepositories = Set(savedExpanded)
            ToastManager.shared.showToast.log("Loaded saved expanded state")
        } else {
            ToastManager.shared.showToast.log("No saved expanded state found")
        }
    }
    
    private func saveExpandedRepositories() {
        // Save current state when view disappears (but not on app termination)
        UserDefaults.standard.set(Array(expandedRepositories), forKey: "expanded_repositories")
        ToastManager.shared.showToast.log("Saved current expanded repository state")
    }
    
    func makeContextMenu(for repository: RepositoryFormat) -> some View {
        RepoMenu(
            repository: repository,
            viewModel: viewModel,
            themeManager: themeManager,
            downloadManager: downloadManager,
            orderedRepositories: $orderedRepositories
        )
    }
}
