//
//  RepositoryListView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Combine

struct RepositorySectionType: Equatable, Identifiable {
    static let favorites = RepositorySectionType(id: "favorites")
    static let repositories = RepositorySectionType(id: "repositories")
    let id: String
}

struct SectionFrame: Equatable {
    let type: RepositorySectionType
    let frame: CGRect
}

struct SectionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [SectionFrame] = []
    
    static func reduce(value: inout [SectionFrame], nextValue: () -> [SectionFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct RepositoryListView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @ObservedObject var downloadManager: DownloadManager
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Binding var searchText: String
    @Binding var expandedRepositories: Set<String>
    @Binding var orderedRepositories: [String]
    let appSortOption: AppSortOption
    let repositorySortOption: RepositorySortOption
    let hasLoadedInitialSortOptions: Bool
    @AppStorage("browse_hideRepositorySectionCounts") private var hideRepositorySectionCounts = false

    var body: some View {
        List {
            if !filteredFavorites.isEmpty {
                Section(header: Text(favoritesHeaderText).secondaryHeader()) {
                    ForEach(filteredFavorites) { repository in
                        repositoryRow(for: repository)
                    }
                }
            }
            
            if !filteredNonFavorites.isEmpty {
                Section(header: Text(repositoriesHeaderText).secondaryHeader()) {
                    ForEach(filteredNonFavorites) { repository in
                        repositoryRow(for: repository)
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }
    
    private var filteredFavorites: [RepositoryFormat] {
        let repositories = searchText.isEmpty ? sortedRepositories : searchFilteredRepositories
        return repositories.filter { favoritesManager.isFavorite($0) }
    }
    
    private var filteredNonFavorites: [RepositoryFormat] {
        let repositories = searchText.isEmpty ? sortedRepositories : searchFilteredRepositories
        return repositories.filter { !favoritesManager.isFavorite($0) }
    }
    
    private var sortedRepositories: [RepositoryFormat] {
        let sorted: [RepositoryFormat]
        switch repositorySortOption {
        case .aToZ:
            sorted = viewModel.repositories.sorted { a, b in
                let aIsLetter = a.name.range(of: "^[A-Za-z]", options: .regularExpression) != nil
                let bIsLetter = b.name.range(of: "^[A-Za-z]", options: .regularExpression) != nil
                if aIsLetter == bIsLetter {
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                } else {
                    return aIsLetter // Letters first
                }
            }
        case .zToA:
            sorted = viewModel.repositories.sorted { a, b in
                let aIsLetter = a.name.range(of: "^[A-Za-z]", options: .regularExpression) != nil
                let bIsLetter = b.name.range(of: "^[A-Za-z]", options: .regularExpression) != nil
                if aIsLetter == bIsLetter {
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedDescending
                } else {
                    return !aIsLetter // Non-letters first, then Z-A for letters
                }
            }
        case .mostApps:
            sorted = viewModel.repositories.sorted { a, b in
                if a.apps.count != b.apps.count {
                    return a.apps.count > b.apps.count // Most apps first
                } else {
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending // Fallback to A-Z
                }
            }
        case .leastApps:
            sorted = viewModel.repositories.sorted { a, b in
                if a.apps.count != b.apps.count {
                    return a.apps.count < b.apps.count // Least apps first
                } else {
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending // Fallback to A-Z
                }
            }
        }
        return sorted
    }
    
    private var searchFilteredRepositories: [RepositoryFormat] {
        viewModel.repositories.filter { repository in
            repository.apps.contains { app in
                app.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var repositoriesHeaderText: String {
        if hideRepositorySectionCounts {
            return "REPOSITORIES"
        }
        let count = filteredNonFavorites.count
        return count == 1 ? "1 REPOSITORY" : "\(count) REPOSITORIES"
    }
    
    private var favoritesHeaderText: String {
        if hideRepositorySectionCounts {
            return "FAVORITES"
        }
        let count = filteredFavorites.count
        return count == 1 ? "1 FAVORITE" : "\(count) FAVORITES"
    }
    
    private func repositoryRow(for repository: RepositoryFormat) -> some View {
        RepositoryRowView(
            repository: repository,
            isExpanded: expandedRepositories.contains(repository.id),
            expandedRepositories: $expandedRepositories,
            viewModel: viewModel,
            themeManager: themeManager,
            downloadManager: downloadManager,
            orderedRepositories: $orderedRepositories,
            searchText: searchText,
            appSortOption: appSortOption,
            repositorySortOption: repositorySortOption,
            hasLoadedInitialSortOptions: hasLoadedInitialSortOptions
        )
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
        .id(repository.id)
    }
}

struct AppRowContent: View {
    let app: App
    let repositoryIdentifier: String?
    let repositoryName: String?
    @AppStorage("app_hideDescriptions") private var hideAppDescriptions = false
    @AppStorage("browse_hideClockIcon") private var hideClockIcon = false
    
    let formattedDate: String?
    let shouldShowDate: Bool
    
    init(app: App, repositoryIdentifier: String? = nil, repositoryName: String? = nil) {
        self.app = app
        self.repositoryIdentifier = repositoryIdentifier
        self.repositoryName = repositoryName
        
        if let versionDate = app.versionDate, let date = DateFormatting.parseDate(versionDate) {
            self.formattedDate = DateFormatting.formatRelativeDate(date)
            self.shouldShowDate = true
        } else {
            self.formattedDate = nil
            self.shouldShowDate = false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let iconURLString = app.iconURL, let _ = URL(string: iconURLString) {
                    AppIconView(app: app) // Pass the whole app object as AppIconView expects it
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                } else {
                    Image("unknowndark") // Fallback if no iconURL
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.body)
                    
                    metadataView
                }
                
                Spacer()
            }
            
            if !hideAppDescriptions, let description = app.localizedDescription, !description.isEmpty {
                Text(truncatedDescription(description))
                    .foregroundColor(.gray)
                    .font(.caption)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var metadataView: some View {
        HStack(spacing: 4) {
            if repositoryIdentifier != nil && repositoryName != nil {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.gray)
                    .font(.caption2)
                    .opacity(0.6)
                    .frame(width: 12, height: 12)
            }
            
            if shouldShowDate, let formattedDate = formattedDate {
                Text(formattedDate)
                    .foregroundColor(.gray)
                    .font(.caption)
                
                if !hideClockIcon {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            
            if let version = app.version {
                Text(versionText(version))
                    .foregroundColor(.gray)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
    
    private func versionText(_ version: String) -> String {
        if shouldShowDate {
            return hideClockIcon ? "- \(version)" : " - \(version)"
        } else {
            return version
        }
    }
    
    private func truncatedDescription(_ description: String) -> String {
        if description.count > 750 {
            let index = description.index(description.startIndex, offsetBy: 750)
            return String(description[..<index]) + "..."
        }
        return description
    }
}

struct RepositoryRowView: View {
    let repository: RepositoryFormat
    let isExpanded: Bool
    @Binding var expandedRepositories: Set<String>
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @ObservedObject var downloadManager: DownloadManager
    @Binding var orderedRepositories: [String]
    let searchText: String
    let appSortOption: AppSortOption
    let repositorySortOption: RepositorySortOption
    let hasLoadedInitialSortOptions: Bool
    
    @State private var cachedDisplayedApps: [App] = []
    @State private var isProcessing = false
    @State private var lastSortOption: AppSortOption?
    @State private var lastSearchText: String = ""
    @State private var hasLoggedSortChange = false
    @ObservedObject private var iconManager = IconManager.shared
    @State private var extractedTintColor: Color?
    @AppStorage("browse_hideRepositoryAppCounts") private var hideRepositoryAppCounts = false
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding<Bool>(
                get: { isExpanded },
                set: { newValue in
                    if newValue {
                        expandedRepositories.insert(repository.id)
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Opened dropdown for \(repository.name)")
                        processAppsAsync()
                    } else {
                        expandedRepositories.remove(repository.id)
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Closed dropdown for \(repository.name)")
                    }
                }
            ),
            content: {
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading apps...")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 26)
                } else if !cachedDisplayedApps.isEmpty {
                    ForEach(cachedDisplayedApps, id: \.bundleIdentifier) { app in
                        AppRowView(app: app)
                            .padding(.leading, -4)
                    }
                }
            },
            label: {
                Label(
                    title: {
                        HStack {
                            Text(repository.name)
                                .foregroundColor(.white)
                                .bold()
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if !hideRepositoryAppCounts {
                                Text("\(repository.apps.count)")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    },
                    icon: {
                        repositoryIconView
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                    }
                )
                .contextMenu {
                    RepoMenu(
                        repository: repository,
                        viewModel: viewModel,
                        themeManager: themeManager,
                        downloadManager: downloadManager,
                        orderedRepositories: $orderedRepositories
                    )
                }
            }
        )
        .tint(repositoryTintColor)
        .onAppear {
            if isExpanded && cachedDisplayedApps.isEmpty {
                processAppsAsync()
            }
            if iconManager.getCachedIcon(for: repository.name) == nil {
                // Use the new fallback method that tries repository icon first, then first app icon
                Task(priority: .userInitiated) {
                    await iconManager.saveIconWithFallback(for: repository)
                    // Extract tint color after icon is loaded (only if not disabled)
                    if !UserDefaults.standard.bool(forKey: "browse_disableTintColorExtraction") {
                        _ = await iconManager.extractAndCacheTintColor(for: repository.name)
                    }
                }
            } else if repository.tintColor == nil && iconManager.getExtractedTintColor(for: repository.name) == nil && !UserDefaults.standard.bool(forKey: "browse_disableTintColorExtraction") {
                // Icon exists but no tint color extracted yet - extract it once (only if not disabled)
                Task(priority: .background) {
                    _ = await iconManager.extractAndCacheTintColor(for: repository.name)
                }
            }
        }
        .onChange(of: iconManager.getCachedIcon(for: repository.name)) { _ in
            // When icon becomes available, extract tint color if needed
            extractTintColorIfNeeded()
        }
        .onChange(of: isExpanded) { newValue in
            if newValue && cachedDisplayedApps.isEmpty {
                processAppsAsync()
            }
        }
        .onChange(of: appSortOption) { newSortOption in
            if isExpanded {
                ToastManager.shared.showToast.log("Sort option changed to \(newSortOption.rawValue) for \(repository.name), reloading apps.")
                processAppsSync(sortOption: newSortOption) // Pass the new sort option directly
            }
        }
        .onChange(of: repositorySortOption) { newSortOption in
            // Only log if this is not the initial load to prevent spam
            if hasLoadedInitialSortOptions {
                ToastManager.shared.showToast.log("Repository sort option changed to \(newSortOption.rawValue)")
            }
        }
        .onChange(of: searchText) { _ in
            if isExpanded {
                processAppsAsync()
            }
        }
        .onDisappear {
            hasLoggedSortChange = false
        }
    }

    @ViewBuilder
    private var repositoryIconView: some View {
        if let cachedIcon = iconManager.getCachedIcon(for: repository.name) {
            Image(uiImage: cachedIcon)
                .resizable()
                .interpolation(.low)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image("unknowndark")
                .resizable()
                .interpolation(.low)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
    
    private var repositoryTintColor: Color {
        // First check if repository has a defined tint color
        if let tintColorString = repository.tintColor {
            let cleanHex = tintColorString.hasPrefix("#") ? String(tintColorString.dropFirst()) : tintColorString
            return Color(hex: cleanHex)
        }
        
        // If no tint color defined, use cached extracted color from icon
        if let extractedColor = iconManager.getExtractedTintColor(for: repository.name) {
            return Color(extractedColor)
        }
        
        // When tint color extraction is disabled or no extracted color available,
        // use tertiaryLabel which matches NavigationLink chevron color
        return Color(UIColor.tertiaryLabel)
    }
    
    private func processAppsAsync() {
        guard !isProcessing else { 
            return
        }
        
        isProcessing = true
        
        Task.detached(priority: .userInitiated) {
            let appsWithProperIDs = repository.appsWithRepositoryID()
            let sortedApps = AppSorting.sortApps(appsWithProperIDs, by: appSortOption, searchText: searchText)
            
            await MainActor.run {
                cachedDisplayedApps = sortedApps
                isProcessing = false
            }
        }
    }
    
    private func processAppsSync(sortOption: AppSortOption? = nil) {
        // For sort changes, process immediately without async delay
        let effectiveSortOption = sortOption ?? appSortOption
        
        // Check if we can optimize by reversing existing sort
        if let lastSort = lastSortOption,
           searchText == lastSearchText,
           !cachedDisplayedApps.isEmpty,
           canReverseSort(from: lastSort, to: effectiveSortOption) {
            
            // Simply reverse the existing order for instant flip
            cachedDisplayedApps = cachedDisplayedApps.reversed()
            lastSortOption = effectiveSortOption
            return
        }
        
        // Clear and process normally
        cachedDisplayedApps = []
        
        let appsWithProperIDs = repository.appsWithRepositoryID()
        let sortedApps = AppSorting.sortApps(appsWithProperIDs, by: effectiveSortOption, searchText: searchText)
        
        // Update immediately
        cachedDisplayedApps = sortedApps
        lastSortOption = effectiveSortOption
        lastSearchText = searchText
    }
    
    private func canReverseSort(from oldOption: AppSortOption, to newOption: AppSortOption) -> Bool {
        // Check if the new sort is just the reverse of the old sort
        switch (oldOption, newOption) {
        case (.aToZ, .zToA), (.zToA, .aToZ):
            return true
        case (.latest, .oldest), (.oldest, .latest):
            return true
        case (.default, _), (_, .default):
            return false // Default should always trigger full re-sort
        default:
            return false
        }
        return false
    }
    
    private func extractTintColorIfNeeded() {
        // Only extract color if repository doesn't have a tint color defined
        guard repository.tintColor == nil,
              extractedTintColor == nil,
              let cachedIcon = iconManager.getCachedIcon(for: repository.name) else {
            return
        }
        
        Task.detached(priority: .background) {
            if let dominantUIColor = await iconManager.extractDominantColor(from: cachedIcon) {
                await MainActor.run {
                    extractedTintColor = Color(dominantUIColor)
                }
            }
        }
    }
}

struct AppRowView: View {
    let app: App
    @AppStorage("app_hideDescriptions") private var hideAppDescriptions = false
    
    var body: some View {
        NavigationLink(destination: BrowseIPADetailsWrapper(app: app)) {
            AppRowContent(app: app)
        }
        .transition(.opacity)
        .contextMenu {
            AppMenu(app: app)
        }
    }
}

struct BrowseIPADetailsWrapper: View {
    let app: App
    
    var body: some View {
        IPADetailsView(app: app)
            .onAppear {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.log("Clicked app: \(app.name)")
            }
    }
}

struct AppIconView: View {
    let app: App
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadingFailed = false
    @State private var retryCount = 0
    @State private var isVisible = false
    @State private var loadingTask: Task<Void, Never>?
    private let maxRetries = 1
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image("unknowndark")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .onAppear {
            isVisible = true
            loadingTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
                if isVisible && !Task.isCancelled {
                    await loadAppIcon()
                }
            }
        }
        .onDisappear {
            isVisible = false
            isLoading = false
            loadingTask?.cancel()
            loadingTask = nil
            
            image = nil
            loadingFailed = false
            retryCount = 0
        }
    }
    
    private func loadAppIcon() async {
        guard let iconURLString = app.iconURL,
              let iconURL = URL(string: iconURLString),
              isVisible else {
            await MainActor.run {
                isLoading = false
                loadingFailed = true
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        await loadIconWithRetry(from: iconURL)
    }
    
    private func loadIconWithRetry(from url: URL) async {
        guard isVisible && !Task.isCancelled else {
            await MainActor.run {
                isLoading = false
                loadingFailed = true
            }
            return
        }
        
        do {
            let session = URLSession.shared
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0  // Reduced timeout
            request.cachePolicy = .returnCacheDataElseLoad
            
            let (data, response) = try await session.data(for: request)
            
            guard isVisible && !Task.isCancelled else { return }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    if isVisible && !Task.isCancelled {
                        self.image = uiImage
                        self.isLoading = false
                        self.loadingFailed = false
                    }
                }
            } else {
                throw URLError(.cannotDecodeContentData)
            }
        } catch {
            await MainActor.run {
                if isVisible && !Task.isCancelled && retryCount < maxRetries {
                    retryCount += 1
                    
                    loadingTask = Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        if isVisible && !Task.isCancelled {
                            await loadIconWithRetry(from: url)
                        }
                    }
                } else {
                    self.isLoading = false
                    self.loadingFailed = true
                }
            }
        }
    }
}