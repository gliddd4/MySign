//
//  SearchPopover.swift
//  mysignipasigner
//
//  Created by gliddd4

import SwiftUI
import BezelKit

struct SearchPopover: View {
    @Environment(\.dismiss) private var dismiss
    let searchDirectory: FileItem?
    let isSystemDirectory: Bool
    let systemPath: String?
    let onSearchActive: ((String) -> Void)?
    @ObservedObject private var themeManager = Theme.shared
    
    @State private var searchText = ""
    @State private var searchResults: [FileItem] = []
    @State private var systemSearchResults: [FileDetails] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var imagesInResults: [FileItem] = []
    @State private var showImagePreview = false
    @State private var selectedImageIndex = 0
    @State private var expandedFolders: Set<String> = []
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var hasAppeared = false
    
    // Default initializer to maintain compatibility
    init(searchDirectory: FileItem?, isSystemDirectory: Bool, systemPath: String?) {
        self.searchDirectory = searchDirectory
        self.isSystemDirectory = isSystemDirectory
        self.systemPath = systemPath
        self.onSearchActive = nil
    }
    
    // New initializer with callback
    init(searchDirectory: FileItem?, isSystemDirectory: Bool, systemPath: String?, onSearchActive: ((String) -> Void)?) {
        self.searchDirectory = searchDirectory
        self.isSystemDirectory = isSystemDirectory
        self.systemPath = systemPath
        self.onSearchActive = onSearchActive
    }
    
    private func dottedPrefix(for path: String) -> String {
        let comps = path.split(separator: "/")
        // Depth from root minus 1 gives 1 dot for first level, 2 for second, etc.
        let dotCount = max(1, comps.count - 1)
        return String(repeating: ".", count: dotCount)
    }
    
    private var searchPrompt: String {
        if let directory = searchDirectory {
            let prefix = dottedPrefix(for: directory.url.path)
            return "searching \(prefix)/\(directory.name)"
        } else if let systemPath,
                  !systemPath.isEmpty {
            let prefix = dottedPrefix(for: systemPath)
            let lastComponent = (systemPath as NSString).lastPathComponent
            return "searching \(prefix)/\(lastComponent)"
        } else {
            return "Search files"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search results
                if isSearching {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    VStack(spacing: 12) {
                        // Empty state - no content needed
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if (isSystemDirectory ? systemSearchResults.isEmpty : searchResults.isEmpty) {
                    List {
                        Section {
                            Text("No files found")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    List {
                        if isSystemDirectory {
                            ForEach(systemSearchResults) { result in
                                SystemSearchResultRow(file: result)
                            }
                        } else {
                            ForEach(searchResults) { result in
                                SearchResultRow(
                                    item: result,
                                    imagesInResults: imagesInResults,
                                    showImagePreview: $showImagePreview,
                                    selectedImageIndex: $selectedImageIndex,
                                    expandedFolders: $expandedFolders
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: searchPrompt)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 34)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Search Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        print("[SearchPopover] Done button tapped - dismissing popover")
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Clicked Done (toolbar) in Search")
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onChange(of: searchText) { newSearchText in
            // Only proceed if the view has appeared
            guard hasAppeared else {
                return
            }
            
            // Notify parent about search activity for system-wide search
            if isSystemDirectory, let onSearchActive = onSearchActive {
                onSearchActive(newSearchText)
            }
            
            // Debounce search for local popover results
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                if !Task.isCancelled {
                    await performSearch()
                }
            }
        }
        .sheet(isPresented: $showImagePreview) {
            if !imagesInResults.isEmpty {
                ImagePreview(
                    currentIndex: selectedImageIndex,
                    images: imagesInResults,
                    isPresented: $showImagePreview
                )
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { 
            searchResults = []
            systemSearchResults = []
            return 
        }
        
        isSearching = true
        
        Task {
            if isSystemDirectory {
                await performSystemSearch()
            } else {
                performAppSearch()
            }
            
            await MainActor.run {
                isSearching = false
            }
        }
    }
    
    private func performSystemSearch() async {
        guard let systemPath = systemPath else { return }
        
        // For system directory searches, use 8-level deep search
        let results = await searchSystemDirectory(path: systemPath, searchText: searchText, maxDepth: 8)
        
        await MainActor.run {
            systemSearchResults = results
        }
    }
    
    private func performAppSearch() {
        guard let directory = searchDirectory else { return }
        
        // Search within the directory's children, not the directory itself
        let searchItems = directory.children ?? []
        let results = searchFileItems(in: searchItems, searchText: searchText)
        let images = results.filter { $0.isImage && !$0.isAnimatedImage }
        
        // This can be called directly as we are not on a background thread.
        // If performSearch was not on a Task, we would need MainActor.run
        self.searchResults = results
        self.imagesInResults = images
    }
    
    private func searchFileItems(in items: [FileItem], searchText: String) -> [FileItem] {
        var results: [FileItem] = []
        
        for item in items {
            // Check if current item matches
            if item.name.localizedCaseInsensitiveContains(searchText) {
                results.append(item)
            }
            
            // Recursively search in children if it's a directory
            if item.isDirectory, let children = item.children {
                let childResults = searchFileItems(in: children, searchText: searchText)
                results.append(contentsOf: childResults)
            }
        }
        
        return results
    }
    
    private func searchSystemDirectory(path: String, searchText: String, maxDepth: Int = 8) async -> [FileDetails] {
        return await withTaskGroup(of: [FileDetails].self, returning: [FileDetails].self) { group in
            var results: [FileDetails] = []
            
            group.addTask {
                return await self.recursiveSystemSearch(in: path, searchText: searchText, maxDepth: maxDepth)
            }
            
            for await groupResults in group {
                results.append(contentsOf: groupResults)
            }
            
            return Array(results.prefix(500)) // Increased limit for 8-level search
        }
    }
    
    private func recursiveSystemSearch(in path: String, searchText: String, maxDepth: Int, currentDepth: Int = 0) async -> [FileDetails] {
        guard currentDepth < maxDepth && !Task.isCancelled else { return [] }
        
        var results: [FileDetails] = []
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue else {
            return []
        }
        
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            
            for item in items {
                if Task.isCancelled { break }
                
                let fullPath = (path as NSString).appendingPathComponent(item)
                let fileDetail = FileDetails(path: fullPath)
                
                // Check if this item matches the search
                if fileDetail.name.localizedCaseInsensitiveContains(searchText) {
                    results.append(fileDetail)
                }
                
                // If it's a directory, search inside (now goes 8 levels deep)
                if fileDetail.isDirectory && currentDepth < maxDepth - 1 {
                    let nestedResults = await recursiveSystemSearch(
                        in: fullPath,
                        searchText: searchText,
                        maxDepth: maxDepth,
                        currentDepth: currentDepth + 1
                    )
                    results.append(contentsOf: nestedResults)
                }
            }
        } catch {
            // Silently handle access errors
        }
        
        return results
    }
}

struct SearchResultRow: View {
    let item: FileItem
    let imagesInResults: [FileItem]
    @Binding var showImagePreview: Bool
    @Binding var selectedImageIndex: Int
    @Binding var expandedFolders: Set<String>
    @ObservedObject private var themeManager = Theme.shared
    
    private var imageIndex: Int? {
        guard item.isImage else { return nil }
        return imagesInResults.firstIndex(where: { $0.url == item.url })
    }
    
    var body: some View {
        HStack {
            if item.isDirectory {
                Image("folderdark")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else if item.isImage && !item.isAnimatedImage {
                Image("imagedark")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image("filedark")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.url.path)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isImage, let index = imageIndex {
                selectedImageIndex = index
                showImagePreview = true
            }
        }
        .contextMenu {
            Button("Copy Path") {
                UIPasteboard.general.string = item.url.path
                ToastManager.shared.showToast.log("Copied path: \(item.url.path)")
            }
            
            Button("Copy Name") {
                UIPasteboard.general.string = item.name
                ToastManager.shared.showToast.log("Copied name: \(item.name)")
            }
        }
    }
}

struct SystemSearchResultRow: View {
    let file: FileDetails
    @ObservedObject private var themeManager = Theme.shared
    
    var body: some View {
        HStack {
            if file.isDirectory {
                Image("folderdark")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image("filedark")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy Path") {
                UIPasteboard.general.string = file.path
                ToastManager.shared.showToast.log("Copied path: \(file.path)")
            }
            
            Button("Copy Name") {
                UIPasteboard.general.string = file.name
                ToastManager.shared.showToast.log("Copied name: \(file.name)")
            }
        }
    }
}