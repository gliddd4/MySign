//
//  DeleteView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct DeleteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @State private var selectedRepositories = Set<String>()
    @State private var showingConfirmation = false
    @State private var isDeleting = false
    
    private var sortedRepositories: [RepositoryFormat] {
        viewModel.repositories.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private func handleDelete() async {
        isDeleting = true
        let repositoriesToDelete = viewModel.repositories.enumerated()
            .filter { selectedRepositories.contains($0.element.identifier) }
        
        let indices = repositoriesToDelete.map(\.offset).sorted(by: >)
        
        for index in indices {
            viewModel.removeRepository(at: index)
        }
        
        isDeleting = false
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            RepositorySelectionList(
                repositories: sortedRepositories,
                selectedRepositories: $selectedRepositories,
                themeManager: themeManager
            )
            .navigationTitle("Delete Repositories")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Delete", role: .destructive) {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Delete (toolbar) in Delete Repositories")
                    showingConfirmation = true
                }
                .disabled(selectedRepositories.isEmpty),
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in Delete Repositories")
                    dismiss()
                }
            )
            .alert("Confirm Deletion", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await handleDelete() }
                }
            } message: {
                Text("Are you sure you want to delete \(selectedRepositories.count) repositories?")
            }
            .overlay {
                if isDeleting {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
    }
}

struct RepositorySelectionList: View {
    let repositories: [RepositoryFormat]
    @Binding var selectedRepositories: Set<String>
    let themeManager: Theme
    @ObservedObject private var iconManager = IconManager.shared
    
    private var isAllSelectedProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                !repositories.isEmpty && Set(repositories.map(\.identifier)) == selectedRepositories
            },
            set: { shouldSelectAll in
                if shouldSelectAll {
                    selectedRepositories = Set(repositories.map(\.identifier))
                } else {
                    selectedRepositories.removeAll()
                }
            }
        )
    }

    private var selectAllToggle: some View {
        
        Toggle("Select All", isOn: isAllSelectedProxy)
            .tint(themeManager.accentColor)
    }
    
    var body: some View {
        List(selection: $selectedRepositories) {
            Section {
                selectAllToggle
            }
            
            Section {
                ForEach(repositories, id: \.identifier) { repository in
                    HStack {
                        IconManager.RepositoryIconView(repository: repository)
                            .frame(width: 30, height: 30)
                        Text(repository.name)
                        Spacer()
                    }
                    .tag(repository.identifier)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }
}