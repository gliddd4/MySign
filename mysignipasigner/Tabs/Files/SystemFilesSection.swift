import SwiftUI
import Combine

struct SystemFilesSection: View {
    @ObservedObject var viewModel: SystemFileManagerModel
    @ObservedObject private var themeManager = Theme.shared
    @Binding var showSearchPopover: Bool
    @Binding var searchSystemPath: String?
    @Binding var selectedFileForInfo: FileDetails?
    
    // Add parameters to receive search state from parent
    let searchText: String
    let isSearchActive: Bool
    
    @State private var searchResults: [FileDetails] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    // Show search results if search is active and has results, nothing if search is active but no results
    private var displayedFiles: [FileDetails] {
        if isSearchActive {
            return searchResults // This will be empty if no matches, showing nothing
        } else {
            return viewModel.files // Normal hierarchical view when not searching
        }
    }

    // Check if we should show the section at all
    private var shouldShowSection: Bool {
        if isSearchActive {
            return !searchResults.isEmpty // Only show if we have search results
        } else {
            return true // Always show when not searching
        }
    }

    var body: some View {
        Group {
            if shouldShowSection {
                Section(header: Text("SYSTEM").secondaryHeader()) {
                    if viewModel.isLoading || isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(isSearching ? "Deep searching system files (8 levels)..." : "Loading...")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        .padding(.vertical, 8)
                    } else if displayedFiles.isEmpty && !isSearchActive {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Access restricted or directory empty")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                            
                            Text("Path: \(viewModel.currentPath)")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            
                            Button("Retry Loading") {
                                viewModel.loadDirectory(path: viewModel.currentPath)
                            }
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.accentColor)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(displayedFiles) { file in
                            if isSearchActive {
                                // Flat search result view (no dropdown)
                                SystemFileSearchResultRow(
                                    file: file,
                                    selectedFileForInfo: $selectedFileForInfo
                                )
                            } else {
                                // Normal hierarchical view with dropdowns
                                SystemFileRow(
                                    file: file, 
                                    viewModel: viewModel,
                                    showSearchPopover: $showSearchPopover,
                                    searchSystemPath: $searchSystemPath,
                                    selectedFileForInfo: $selectedFileForInfo
                                )
                            }
                        }
                        
                        if isSearchActive && !searchResults.isEmpty {
                            Text("Found \(searchResults.count) results (8 levels deep)")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                                .padding(.top, 8)
                        }
                    }
                }
                .sheet(isPresented: $showSearchPopover) {
                    SearchPopover(
                        searchDirectory: nil,
                        isSystemDirectory: searchSystemPath != nil,
                        systemPath: searchSystemPath
                    )
                }
            }
        }
        .onChange(of: searchText) { newSearchText in
            if isSearchActive {
                performSystemSearch(query: newSearchText)
            }
        }
        .onChange(of: isSearchActive) { newValue in
            if !newValue {
                // Clear search results when search becomes inactive
                searchResults = []
                searchTask?.cancel()
            }
        }
    }
    
    // Perform search based on query
    private func performSystemSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchResults = []
        
        searchTask?.cancel()
        searchTask = Task {
            await performSystemWideSearch(searchText: query)
        }
    }

    // Perform system-wide 8-level deep search
    private func performSystemWideSearch(searchText: String) async {
        let systemPaths = [
            "/System",
            "/usr",
            "/var", 
            "/Library",
            "/Applications"
        ]
        
        var allResults: [FileDetails] = []
        let maxResults = 1000 // Higher limit to show ALL matching results
        
        // Search all major system directories with depth 8
        for path in systemPaths {
            if Task.isCancelled { return }
            
            let results = await searchInDirectory(path: path, searchText: searchText, maxDepth: 8, maxResults: maxResults - allResults.count)
            allResults.append(contentsOf: results)
            
            // Update UI progressively
            await MainActor.run {
                self.searchResults = allResults
            }
            
            if allResults.count >= maxResults {
                break
            }
        }
        
        await MainActor.run {
            self.isSearching = false
        }
    }

    private func searchInDirectory(path: String, searchText: String, maxDepth: Int, maxResults: Int) async -> [FileDetails] {
        return await withTaskGroup(of: [FileDetails].self, returning: [FileDetails].self) { group in
            var results: [FileDetails] = []
            
            group.addTask {
                return await self.recursiveSearch(in: path, searchText: searchText, maxDepth: maxDepth, maxResults: maxResults)
            }
            
            for await groupResults in group {
                results.append(contentsOf: groupResults)
                if results.count >= maxResults {
                    break
                }
            }
            
            return Array(results.prefix(maxResults))
        }
    }

    private func recursiveSearch(in path: String, searchText: String, maxDepth: Int, maxResults: Int, currentDepth: Int = 0) async -> [FileDetails] {
        guard currentDepth < maxDepth && !Task.isCancelled else { return [] }
        
        var results: [FileDetails] = []
        let fileManager = FileManager.default
        
        // Fast path - check if directory exists and is accessible
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue else {
            return []
        }
        
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            
            // Sort items to prioritize certain file types
            let sortedItems = items.sorted { item1, item2 in
                let ext1 = URL(fileURLWithPath: item1).pathExtension.lowercased()
                let ext2 = URL(fileURLWithPath: item2).pathExtension.lowercased()
                
                // Prioritize common file types
                let priorityExtensions = ["plist", "txt", "log", "json", "xml"]
                let priority1 = priorityExtensions.contains(ext1) ? 0 : 1
                let priority2 = priorityExtensions.contains(ext2) ? 0 : 1
                
                if priority1 != priority2 {
                    return priority1 < priority2
                }
                return item1.localizedCaseInsensitiveCompare(item2) == .orderedAscending
            }
            
            for item in sortedItems {
                if Task.isCancelled || results.count >= maxResults {
                    break
                }
                
                let fullPath = (path as NSString).appendingPathComponent(item)
                let fileDetail = FileDetails(path: fullPath)
                
                // Check if this item matches the search (case-insensitive)
                if fileDetail.name.localizedCaseInsensitiveContains(searchText) {
                    results.append(fileDetail)
                }
                
                // If it's a directory and we haven't reached max depth, search inside
                if fileDetail.isDirectory && currentDepth < maxDepth - 1 && results.count < maxResults {
                    let nestedResults = await recursiveSearch(
                        in: fullPath,
                        searchText: searchText,
                        maxDepth: maxDepth,
                        maxResults: max(0, maxResults - results.count),
                        currentDepth: currentDepth + 1
                    )
                    results.append(contentsOf: nestedResults)
                }
            }
        } catch {
            // Silently handle access errors - many system directories are restricted
            return []
        }
        
        return results
    }
}

struct SystemFileSearchResultRow: View {
    let file: FileDetails
    @ObservedObject private var themeManager = Theme.shared
    @Binding var selectedFileForInfo: FileDetails?

    var body: some View {
        Label(
            title: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text(file.path)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            },
            icon: {
                if file.isDirectory {
                    Image("folderdark")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                } else if isImageFile(file: file) {
                    Image("imagedark")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                } else {
                    Image("filedark")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                }
            }
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.string = file.path
                ToastManager.shared.showToast.log("Copied path: \(file.path)")
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            
            Button {
                UIPasteboard.general.string = file.name
                ToastManager.shared.showToast.log("Copied name: \(file.name)")
            } label: {
                Label("Copy Name", systemImage: "textformat")
            }
            
            Divider()
            
            Button {
                selectedFileForInfo = file
                ToastManager.shared.showToast.log("Clicked File Info for \(file.name)")
            } label: {
                Label("File Info", systemImage: "info.circle")
            }
        }
    }
    
    private func isImageFile(file: FileDetails) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        return imageExtensions.contains(URL(fileURLWithPath: file.path).pathExtension.lowercased())
    }
}

struct SystemFileRow: View {
    let file: FileDetails
    @ObservedObject var viewModel: SystemFileManagerModel
    @ObservedObject private var themeManager = Theme.shared
    @State private var isExpanded = false
    @State private var children: [FileDetails] = []
    @State private var isLoadingChildren = false
    @Binding var showSearchPopover: Bool
    @Binding var searchSystemPath: String?
    @Binding var selectedFileForInfo: FileDetails?

    var body: some View {
        if file.isDirectory {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    if isLoadingChildren {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading...")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(children) { child in
                            SystemFileRow(
                                file: child, 
                                viewModel: viewModel,
                                showSearchPopover: $showSearchPopover,
                                searchSystemPath: $searchSystemPath,
                                selectedFileForInfo: $selectedFileForInfo
                            )
                            .padding(.leading, -4)
                            .id(child.path)
                        }
                    }
                },
                label: {
                    Label(
                        title: {
                            Text(file.name)
                                .foregroundColor(.white)
                                .bold()
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        icon: {
                            Image("folderdark")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .cornerRadius(6)
                        }
                    )
                    .contextMenu {
                        SystemFileContextMenu(
                            file: file, 
                            viewModel: viewModel,
                            showSearchPopover: $showSearchPopover,
                            searchSystemPath: $searchSystemPath,
                            selectedFileForInfo: $selectedFileForInfo
                        )
                    }
                }
            )
            .accentColor(themeManager.accentColor)
            .onChange(of: isExpanded) { newValue in
                if newValue && children.isEmpty {
                    loadChildren()
                }
            }
        } else {
            Label(
                title: {
                    Text(file.name)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                },
                icon: {
                    if isImageFile(file: file) {
                        Image("imagedark")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                    } else {
                        Image("filedark")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                    }
                }
            )
            .contextMenu {
                SystemFileContextMenu(
                    file: file, 
                    viewModel: viewModel,
                    showSearchPopover: $showSearchPopover,
                    searchSystemPath: $searchSystemPath,
                    selectedFileForInfo: $selectedFileForInfo
                )
            }
        }
    }

    private func isImageFile(file: FileDetails) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        return imageExtensions.contains(URL(fileURLWithPath: file.path).pathExtension.lowercased())
    }

    private func loadChildren() {
        isLoadingChildren = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var childFiles: [FileDetails] = []
            
            let fm = FileManager.default
            do {
                let items = try fm.contentsOfDirectory(atPath: file.path)
                for item in items {
                    let fullPath = (file.path as NSString).appendingPathComponent(item)
                    childFiles.append(FileDetails(path: fullPath))
                }
                
                childFiles.sort { a, b in
                    if a.isDirectory && !b.isDirectory { return true }
                    if !a.isDirectory && b.isDirectory { return false }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
                
                DispatchQueue.main.async {
                    self.children = childFiles
                    self.isLoadingChildren = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.children = []
                    self.isLoadingChildren = false
                }
            }
        }
    }
}

struct SystemFileContextMenu: View {
    let file: FileDetails
    @ObservedObject var viewModel: SystemFileManagerModel
    @Binding var showSearchPopover: Bool
    @Binding var searchSystemPath: String?
    @Binding var selectedFileForInfo: FileDetails?

    var body: some View {
        Group {
            if file.isDirectory {
                Button {
                    // Check if directory is accessible before presenting search
                    let fileManager = FileManager.default
                    if fileManager.isReadableFile(atPath: file.path) {
                        // Use NotificationCenter to decouple from context menu presentation
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TriggerSystemSearch"),
                            object: nil,
                            userInfo: ["path": file.path]
                        )
                        ToastManager.shared.showToast.log("Clicked Search this directory for \(file.path)")
                        print("SystemFileContextMenu: file.path = \(file.path), file.name = \(file.name)")
                    } else {
                        ToastManager.shared.showToast.error("Cannot search \(file.name) - Access denied")
                    }
                } label: {
                    Label("Search this directory", systemImage: "magnifyingglass")
                }
                Divider()
            }
            
            Button {
                UIPasteboard.general.string = file.path
                ToastManager.shared.showToast.log("Copied path: \(file.path)")
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            
            Button {
                UIPasteboard.general.string = file.name
                ToastManager.shared.showToast.log("Copied name: \(file.name)")
            } label: {
                Label("Copy Name", systemImage: "textformat")
            }
            
            Divider()
            
            Button {
                selectedFileForInfo = file
                ToastManager.shared.showToast.log("Clicked File Info for \(file.name)")
            } label: {
                Label("File Info", systemImage: "info.circle")
            }
        }
    }
}

struct FileInfoPopover: View {
    @Environment(\.dismiss) private var dismiss
    let file: FileDetails
    @ObservedObject var viewModel: SystemFileManagerModel
    @ObservedObject private var themeManager = Theme.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("FILE INFORMATION").foregroundColor(.secondary)) {
                    CompactInfoRow(title: "Name:", content: file.name)
                    CompactInfoRow(title: "Path:", content: file.path)
                    CompactInfoRow(title: "Type:", content: file.isDirectory ? "Directory" : viewModel.detectFileType(for: file.path))
                    CompactInfoRow(title: "Size:", content: viewModel.formattedFileSize(size: file.size))
                    CompactInfoRow(title: "Owner:", content: file.owner)
                    CompactInfoRow(title: "Permissions:", content: file.permissions)
                    
                    if let creationDate = file.creationDate {
                        CompactInfoRow(title: "Created:", content: formatDate(creationDate))
                    }
                    
                    if let modificationDate = file.modificationDate {
                        CompactInfoRow(title: "Modified:", content: formatDate(modificationDate))
                    }
                }
                
                Section(header: Text("ACTIONS").foregroundColor(.secondary)) {
                    Button {
                        UIPasteboard.general.string = file.path
                        ToastManager.shared.showToast.success("Path copied to clipboard")
                        HapticManager.shared.medium()
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        UIPasteboard.general.string = file.name
                        ToastManager.shared.showToast.success("Name copied to clipboard")
                        HapticManager.shared.medium()
                    } label: {
                        Label("Copy Name", systemImage: "textformat")
                    }
                    
                    Button {
                        let info = """
                        Name: \(file.name)
                        Path: \(file.path)
                        Type: \(file.isDirectory ? "Directory" : viewModel.detectFileType(for: file.path))
                        Size: \(viewModel.formattedFileSize(size: file.size))
                        Owner: \(file.owner)
                        Permissions: \(file.permissions)
                        Created: \(file.creationDate.map(formatDate) ?? "Unknown")
                        Modified: \(file.modificationDate.map(formatDate) ?? "Unknown")
                        """
                        UIPasteboard.general.string = info
                        ToastManager.shared.showToast.success("File info copied to clipboard")
                        HapticManager.shared.medium()
                    } label: {
                        Label("Copy All Info", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 34)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in File Info")
                    dismiss()
                }
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}