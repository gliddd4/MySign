//
//  FilesView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileItem]?
    
    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    var isAnimatedImage: Bool {
        let animatedExtensions = ["gif"]
        return animatedExtensions.contains(url.pathExtension.lowercased())
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct FilesView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @StateObject private var systemFileManager = SystemFileManagerModel()
    @ObservedObject private var themeManager = Theme.shared
    
    @State private var showImportTypeSelection = false
    @State private var expandedFolders: Set<String> = []
    @State private var showSearchPopover = false
    @State private var searchDirectory: FileItem?
    @State private var searchSystemPath: String?
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var isSearchActive = false
    @FocusState private var searchFieldIsFocused: Bool
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedFileForInfo: FileDetails?
    @State private var isPopoverPresenting = false
    @State private var pendingSearchPath: String?
    @State private var presentationAttempts: Int = 0
    
    class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
        var documentsPath: URL? {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Implementation handled by SwiftUI
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Implementation handled by SwiftUI
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, shouldPresentAt url: URL) -> Bool {
            // Don't show files from Documents directory
            guard let documentsPath = documentsPath else { return true }
            return !url.path.contains(documentsPath.path)
        }
    }
    
    func showImportToast(originalName: String, result: (newName: String?, alreadyExists: Bool), delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if result.alreadyExists {
                ToastManager.shared.showToast.error("\(originalName) already exists")
            } else if let newName = result.newName {
                ToastManager.shared.showToast("Imported \(newName)")
            } else {
                ToastManager.shared.showToast.error("Failed to import \(originalName)")
            }
        }
    }
    
    // Simple filter items based on debounced search text
    private var filteredItems: [FileItem] {
        if debouncedSearchText.isEmpty {
            return viewModel.items
        } else {
            return filterItemsRecursively(viewModel.items)
        }
    }
    
    private func filterItemsRecursively(_ items: [FileItem]) -> [FileItem] {
        return items.compactMap { item in
            let nameMatches = item.name.localizedCaseInsensitiveContains(debouncedSearchText)
            
            if item.isDirectory {
                // Recursively filter children if they exist
                var filteredChildren: [FileItem] = []
                if let children = item.children {
                    filteredChildren = filterItemsRecursively(children)
                }
                
                // Include directory if name matches or has matching children
                let hasMatchingChildren = !filteredChildren.isEmpty
                
                if nameMatches || hasMatchingChildren {
                    var newItem = item
                    newItem.children = nameMatches ? item.children : filteredChildren
                    
                    // Auto-expand folders that contain search results
                    if hasMatchingChildren {
                        DispatchQueue.main.async {
                            expandedFolders.insert(item.name)
                        }
                    }
                    
                    return newItem
                }
                return nil
            } else {
                // For files, check if name matches
                return nameMatches ? item : nil
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                List {
                    Section(header: Text("APP").secondaryHeader()) {
                        let rootImages = filteredItems.filter { $0.isImage && !$0.isAnimatedImage }
                        ForEach(filteredItems) { item in
                            FileItemView(
                                item: item,
                                imagesInCurrentFolder: rootImages,
                                viewModel: viewModel,
                                expandedFolders: $expandedFolders,
                                showSearchPopover: $showSearchPopover,
                                searchDirectory: $searchDirectory
                            )
                        }
                    }
                    SystemFilesSection(
                        viewModel: systemFileManager,
                        showSearchPopover: .constant(false),
                        searchSystemPath: .constant(nil),
                        selectedFileForInfo: $selectedFileForInfo,
                        searchText: debouncedSearchText,
                        isSearchActive: isSearchActive
                    )
                }
                .padding(.horizontal, 2)
                .sheet(item: $selectedFileForInfo) { file in
                    FileInfoPopover(file: file, viewModel: systemFileManager)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 20)
            }

            NavigationManager.customNavigation(
                title: "Files",
                trailingItems: [
                    NavigationItem(
                        icon: "square.and.arrow.down",
                        name: "Import",
                        action: {
                            HapticManager.shared.medium()
                            ToastManager.shared.showToast.log("Clicked Import (toolbar) in Files")
                            showImportTypeSelection = true
                        }
                    )
                ]
            )
            .zIndex(1)
            
            if isSearchActive {
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack {
                        TextField("Search", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .focused($searchFieldIsFocused)
                        
                        Button("Cancel") {
                            isSearchActive = false
                        }
                        .foregroundColor(themeManager.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                }
                .padding(.bottom, -34)
                .edgesIgnoringSafeArea(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: isSearchActive)
            }

        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .actionSheet(isPresented: $showImportTypeSelection) {
            ActionSheet(
                title: Text("Select Import Type"),
                message: Text("Choose the type of files you want to import"),
                buttons: [
                    .default(Text("Import IPA")) {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Selected Import IPA from action sheet")
                        viewModel.selectedFilter = .ipa
                        viewModel.isImporting = true
                    },
                    .default(Text("Import Dylib/Deb")) {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Selected Import Dylib/Deb from action sheet")
                        viewModel.selectedFilter = .dylib
                        viewModel.isImporting = true
                    },
                    .default(Text("Import Media")) {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Selected Import Media from action sheet")
                        viewModel.selectedFilter = .image
                        viewModel.isImporting = true
                    },
                    .cancel()
                ]
            )
        }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: viewModel.selectedFilter.contentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { @MainActor in
                    for (index, url) in urls.enumerated() {
                        let importResult = await viewModel.importFile(url)
                        showImportToast(
                            originalName: url.lastPathComponent,
                            result: importResult,
                            delay: Double(index) * 0.5
                        )
                    }
                }
            case .failure(_):
                ToastManager.shared.showToast.error("Import failed")
            }
            viewModel.selectedFilter = .ipa
        }
        .background {
            DocumentPickerView(delegate: FilePickerDelegate())
        }
        .onAppear {
            viewModel.loadDocumentsDirectory()
            systemFileManager.loadDirectory(path: "/System")
            loadExpandedFolders()
        }
        .onDisappear {
            saveExpandedFolders()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ExpandRepositoryJSONFolder"))) { _ in
            expandRepositoryJSONFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("TriggerSystemSearch"))) { notification in
            if let userInfo = notification.userInfo,
               let path = userInfo["path"] as? String {
                
                ToastManager.shared.showToast.log("Received search trigger for \(path)")
                
                // Prevent multiple presentation attempts and duplicate requests
                guard !isPopoverPresenting && !showSearchPopover && pendingSearchPath != path else {
                    return
                }
                
                // Reset presentation attempts counter
                presentationAttempts = 0
                
                // Reset any existing presentation state first
                showSearchPopover = false
                searchSystemPath = nil
                
                // Set presenting state and pending path to prevent duplicates
                isPopoverPresenting = true
                pendingSearchPath = path
                
                // Much longer delay to ensure context menu is fully dismissed and system is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Double check we still want to present for this path
                    guard pendingSearchPath == path && !showSearchPopover && isPopoverPresenting else {
                        isPopoverPresenting = false
                        pendingSearchPath = nil
                        return
                    }
                    
                    searchSystemPath = path
                    presentationAttempts += 1
                    
                    // Use a longer additional delay for the actual presentation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard pendingSearchPath == path && !showSearchPopover && isPopoverPresenting else {
                            isPopoverPresenting = false
                            pendingSearchPath = nil
                            return
                        }
                        
                        showSearchPopover = true
                        isPopoverPresenting = false
                        pendingSearchPath = nil
                        ToastManager.shared.showToast.log("Presented search popover for \(path)")
                    }
                }
            }
        }
        .onChange(of: debouncedSearchText) { newValue in
            // The search is automatically triggered by SystemFilesSection
        }
        .onChange(of: isSearchActive) { newValue in
            if(newValue) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFieldIsFocused = true
                }
            } else {
                // Clear search when dismissing
                searchText = ""
                debouncedSearchText = ""
                searchDebounceTask?.cancel()
            }
        }
        .onChange(of: searchText) { newValue in
            // Cancel previous debounce task
            searchDebounceTask?.cancel()
            
            // Create new debounce task
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                
                if !Task.isCancelled {
                    await MainActor.run {
                        debouncedSearchText = newValue
                    }
                }
            }
        }
        .onChange(of: showSearchPopover) { isShowing in
            if !isShowing {
                // Clear search parameters when popover is dismissed
                searchDirectory = nil
                searchSystemPath = nil
                isPopoverPresenting = false
                pendingSearchPath = nil
            }
        }
        .tint(themeManager.accentColor)
        .sheet(isPresented: $showSearchPopover) {
            SearchPopover(
                searchDirectory: searchDirectory,
                isSystemDirectory: searchSystemPath != nil,
                systemPath: searchSystemPath,
                onSearchActive: { searchText in
                    // This callback is handled by SystemFilesSection now
                    // The search trigger is managed there
                }
            )
        }
        .fullScreenCover(isPresented: $showSearchPopover) {
            SearchPopover(
                searchDirectory: searchDirectory,
                isSystemDirectory: searchSystemPath != nil,
                systemPath: searchSystemPath,
                onSearchActive: { searchText in
                    // This callback is handled by SystemFilesSection now
                    // The search trigger is managed there
                }
            )
        }
    }
    
    private func loadExpandedFolders() {
        if let savedExpanded = UserDefaults.standard.array(forKey: "expanded_folders") as? [String] {
            expandedFolders = Set(savedExpanded)
        }
    }
    
    private func saveExpandedFolders() {
        UserDefaults.standard.set(Array(expandedFolders), forKey: "expanded_folders")
    }
    
    func expandRepositoryJSONFolder() {
        expandedFolders.insert("Repository JSON")
    }
}

struct FileItemView: View {
    let item: FileItem
    let imagesInCurrentFolder: [FileItem]
    let viewModel: DirectoryViewModel
    @ObservedObject private var themeManager = Theme.shared
    @State private var showImagePreview = false
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var showMoveSheet = false
    @State private var itemToMove: FileItem?
    @Binding var expandedFolders: Set<String>
    @Binding var showSearchPopover: Bool
    @Binding var searchDirectory: FileItem?

    // New state for image loading
    @State private var loadedImage: UIImage?
    @State private var isSquareImage: Bool = false
    @State private var hasCheckedImage: Bool = false

    private var imageIndex: Int? {
        guard item.isImage else { return nil }
        return imagesInCurrentFolder.firstIndex(where: { $0.url == item.url })
    }
    
    private var isZipFile: Bool {
        item.url.pathExtension.lowercased() == "zip"
    }
    
    // Function to check if image is square and load it
    private func loadAndCheckImage() {
        guard item.isImage && !item.isAnimatedImage && !hasCheckedImage else { return }
        hasCheckedImage = true
        
        Task {
            do {
                let data = try Data(contentsOf: item.url)
                if let image = UIImage(data: data) {
                    let isSquare = abs(image.size.width - image.size.height) < 1.0 // Allow for small rounding differences
                    
                    await MainActor.run {
                        self.loadedImage = image
                        self.isSquareImage = isSquare
                    }
                }
            } catch {
                // Handle error silently, will use default icon
            }
        }
    }
    
    var body: some View {
        if item.isDirectory {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedFolders.contains(item.name) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedFolders.insert(item.name)
                        } else {
                            expandedFolders.remove(item.name)
                        }
                    }
                ),
                content: {
                    if let children = item.children {
                        let imageItems = children.filter { $0.isImage && !$0.isAnimatedImage }
                        ForEach(children) { child in
                            FileItemView(
                                item: child,
                                imagesInCurrentFolder: imageItems,
                                viewModel: viewModel,
                                expandedFolders: $expandedFolders,
                                showSearchPopover: $showSearchPopover,
                                searchDirectory: $searchDirectory
                            )
                                .padding(.leading, -4)
                        }
                    }
                },
                label: {
                    Label(
                        title: {
                            Text(item.name)
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
                        FilesMenu(
                            item: item,
                            viewModel: viewModel,
                            showRenameAlert: $showRenameAlert,
                            newName: $newName,
                            showMoveSheet: $showMoveSheet,
                            itemToMove: $itemToMove,
                            showSearchPopover: $showSearchPopover,
                            searchDirectory: $searchDirectory
                        )
                    }
                }
            )
            .accentColor(themeManager.accentColor)
            .alert("Rename Item", isPresented: $showRenameAlert) {
                TextField("Name", text: $newName)
                Button("Rename") {
                    MenuRenameHelper.renameItem(item.url, to: newName, viewModel: viewModel)
                }
                Button("Cancel", role: .cancel) {
                    newName = ""
                }
            } message: {
                Text("Enter a new name for this item")
            }
        } else {
            Label(
                title: {
                    Text(item.name)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                },
                icon: {
                    if item.isImage && !item.isAnimatedImage {
                        Group {
                            if isSquareImage, let image = loadedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image("imagedark")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .cornerRadius(6)
                            }
                        }
                        .onAppear {
                            loadAndCheckImage()
                        }
                    } else {
                        Image("filedark")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                    }
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
            .onTapGesture {
                if item.isImage {
                    showImagePreview = true
                }
            }
            .contextMenu {
                FilesMenu(
                    item: item,
                    viewModel: viewModel,
                    showRenameAlert: $showRenameAlert,
                    newName: $newName,
                    showMoveSheet: $showMoveSheet,
                    itemToMove: $itemToMove,
                    showSearchPopover: $showSearchPopover,
                    searchDirectory: $searchDirectory
                )
            }
            .sheet(isPresented: $showImagePreview) {
                if let index = imageIndex {
                    ImagePreview(
                        currentIndex: index,
                        images: imagesInCurrentFolder,
                        isPresented: $showImagePreview
                    )
                }
            }
            .alert("Rename Item", isPresented: $showRenameAlert) {
                TextField("Name", text: $newName)
                Button("Rename") {
                    MenuRenameHelper.renameItem(item.url, to: newName, viewModel: viewModel)
                }
                Button("Cancel", role: .cancel) {
                    newName = ""
                }
            } message: {
                Text("Enter a new name for this item")
            }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let delegate: UIDocumentPickerDelegate
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let picker = uiViewController.presentedViewController as? UIDocumentPickerViewController {
            picker.delegate = delegate
        }
    }
}
