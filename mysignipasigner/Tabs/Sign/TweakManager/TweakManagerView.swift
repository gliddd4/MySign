import SwiftUI

struct TweakManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // State for tweak import workflow
    @StateObject private var tweakPickerCoordinator = FilePickerCoordinator()
    
    // State for tweak list management
    @State private var tweakFolders: [TweakFolder] = []
    @State private var isLoadingTweaks = false
    
    // State for deletion
    @State private var showDeleteConfirmation = false
    @State private var tweakToDelete: TweakFolder?
    
    @StateObject private var defaultTweakManager = DefaultTweakManager.shared
    
    private var defaultTweaks: [TweakFolder] {
        tweakFolders.filter { defaultTweakManager.isDefaultTweak($0.name) }
    }
    
    private var otherTweaks: [TweakFolder] {
        tweakFolders.filter { !defaultTweakManager.isDefaultTweak($0.name) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                List {
                    importSection()
                    
                    defaultTweaksSection()
                    
                    if !otherTweaks.isEmpty {
                        otherTweaksSection()
                    }
                    
                    // if tweakFolders.isEmpty && !isLoadingTweaks {
                    //     emptyStateSection()
                    // }
                }
                .listStyle(InsetGroupedListStyle())
                .padding(.horizontal, 2)
            }
            .navigationTitle("Tweak Manager")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in Tweak Manager")
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $tweakPickerCoordinator.isPresented) {
            UnifiedDocumentPicker(coordinator: tweakPickerCoordinator)
                .edgesIgnoringSafeArea(.bottom)
        }
        .alert("Delete Tweak", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let tweak = tweakToDelete {
                    deleteTweak(tweak)
                }
            }
            Button("Cancel", role: .cancel) {
                tweakToDelete = nil
            }
        } message: {
            if let tweak = tweakToDelete {
                Text("Are you sure you want to delete '\(tweak.name)'? This action cannot be undone.")
            }
        }
        .onAppear {
            loadTweaks()
        }
        .onChange(of: tweakPickerCoordinator.selectedFileURL) { newValue in
            if let url = newValue {
                Task {
                    let success = await TweakOperations.shared.handleMultipleTweakImport(urls: [url])
                    if success {
                        loadTweaks()
                    }
                    tweakPickerCoordinator.selectedFileURL = nil
                }
            }
        }
    }
    
    // MARK: - View Sections
    @ViewBuilder
    private func importSection() -> some View {
        Section(
            header: Text("IMPORT").secondaryHeader(),
            footer: Text("Select .dylib or .deb files to import tweaks. You can select multiple files at once.")
        ) {
            Button(action: {
                HapticManager.shared.medium()
                tweakPickerCoordinator.presentPicker(type: .tweak)
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import Tweaks")
                            .foregroundColor(.white)
                        
                        Text("Select .dylib or .deb files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private func defaultTweaksSection() -> some View {
        Section(
            header: HStack {
                Text("DEFAULT TWEAKS").secondaryHeader()
                Spacer()
                if defaultTweaks.count > 1 {
                    Button("Clear All") {
                        HapticManager.shared.medium()
                        defaultTweakManager.clearAllDefaultTweaks()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            },
            footer: Text("These tweaks will be automatically applied when signing apps.")
        ) {
            if defaultTweaks.isEmpty {
                Text("No default tweaks selected yet")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            } else {
                ForEach(defaultTweaks, id: \.name) { tweak in
                    TweakRowView(tweak: tweak, isDefault: true) {
                        // Tap action for default tweaks
                    }
                    .contextMenu {
                        defaultTweakContextMenu(for: tweak)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func otherTweaksSection() -> some View {
        Section(
            header: Text("TWEAKS").secondaryHeader()
        ) {
            ForEach(otherTweaks, id: \.name) { tweak in
                TweakRowView(tweak: tweak, isDefault: false) {
                    // Tap action for other tweaks
                }
                .contextMenu {
                    otherTweakContextMenu(for: tweak)
                }
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateSection() -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Tweaks Imported")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Import .dylib or .deb files to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Context Menus
    @ViewBuilder
    private func defaultTweakContextMenu(for tweak: TweakFolder) -> some View {
        Button(action: {
            HapticManager.shared.medium()
            defaultTweakManager.removeDefaultTweak(tweak.name)
        }) {
            HStack {
                Text("Remove from Defaults")
                Image(systemName: "star.slash")
            }
        }
        
        Button(action: {
            HapticManager.shared.medium()
            TweakOperations.shared.shareTweak(tweak)
        }) {
            HStack {
                Text("Share Tweak")
                Image(systemName: "square.and.arrow.up")
            }
        }
        
        Button(action: {
            HapticManager.shared.medium()
            tweakToDelete = tweak
            showDeleteConfirmation = true
        }) {
            HStack {
                Text("Delete Tweak")
                Image(systemName: "trash")
            }
        }
        .foregroundColor(.red)
    }
    
    @ViewBuilder
    private func otherTweakContextMenu(for tweak: TweakFolder) -> some View {
        Button(action: {
            HapticManager.shared.medium()
            defaultTweakManager.addDefaultTweak(tweak.name)
        }) {
            HStack {
                Text("Add to Defaults")
                Image(systemName: "star")
            }
        }
        
        Button(action: {
            HapticManager.shared.medium()
            TweakOperations.shared.shareTweak(tweak)
        }) {
            HStack {
                Text("Share Tweak")
                Image(systemName: "square.and.arrow.up")
            }
        }
        
        Button(action: {
            HapticManager.shared.medium()
            tweakToDelete = tweak
            showDeleteConfirmation = true
        }) {
            HStack {
                Text("Delete Tweak")
                Image(systemName: "trash")
            }
        }
        .foregroundColor(.red)
    }
    
    // MARK: - Private Methods
    private func loadTweaks() {
        isLoadingTweaks = true
        
        Task {
            let tweaks = await TweakOperations.shared.loadTweaks()
            await MainActor.run {
                self.tweakFolders = tweaks
                self.isLoadingTweaks = false
            }
        }
    }
    
    private func deleteTweak(_ tweak: TweakFolder) {
        Task {
            let success = await TweakOperations.shared.deleteTweak(tweak)
            if success {
                await MainActor.run {
                    loadTweaks()
                    tweakToDelete = nil
                }
            } else {
                await MainActor.run {
                    tweakToDelete = nil
                }
            }
        }
    }
}