//
//  RetryDialogView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct RetryDialogView: View {
    let errors: [ValidationError]
    @ObservedObject var theme: Theme
    let onRetry: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURLs: Set<String>
    
    init(errors: [ValidationError], theme: Theme, onRetry: @escaping ([String]) -> Void) {
        self.errors = errors
        self.theme = theme
        self.onRetry = onRetry
        // Initialize with all URLs selected by default
        self._selectedURLs = State(initialValue: Set(errors.map { $0.url }))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("SELECT URLS TO RETRY").secondaryHeader(),
                    footer: Text("Select the URLs you want to retry adding to your repositories.")
                ) {
                    ForEach(errors.indices, id: \.self) { index in
                        let error = errors[index]
                        
                        HStack {
                            Button(action: {
                                if selectedURLs.contains(error.url) {
                                    selectedURLs.remove(error.url)
                                } else {
                                    selectedURLs.insert(error.url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedURLs.contains(error.url) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedURLs.contains(error.url) ? theme.accentColor : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(error.url)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        
                                        HStack {
                                            Text(error.category.icon)
                                            Text(error.category.displayName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section {
                    HStack {
                        Button("Select All") {
                            selectedURLs = Set(errors.map { $0.url })
                        }
                        .foregroundColor(theme.accentColor)
                        
                        Spacer()
                        
                        Button("Select None") {
                            selectedURLs.removeAll()
                        }
                        .foregroundColor(theme.accentColor)
                    }
                }
            }
            .navigationTitle("Retry URLs")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary),
                trailing: Button("Retry Selected") {
                    HapticManager.shared.medium()
                    onRetry(Array(selectedURLs))
                    dismiss()
                }
                .foregroundColor(theme.accentColor)
                .disabled(selectedURLs.isEmpty)
            )
        }
    }
}