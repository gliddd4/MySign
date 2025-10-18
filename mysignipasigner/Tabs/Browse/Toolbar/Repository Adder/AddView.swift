import SwiftUI
import UIKit

struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RepositoryViewModel
    @ObservedObject var themeManager: Theme
    @State private var urlInput = ""
    @State private var isProcessing = false
    @State private var showDeleteView = false
    @State private var isCancelled = false

    private var validUrls: [String] {
        ValidationManager.shared.validateURLs(urlInput)
    }

    private var buttonTitle: String {
        validUrls.count > 1 ? "Add Repositories" : "Add Repository"
    }

    private var repositoryUrls: [String] {
        viewModel.repositories.compactMap { repository in
            viewModel.getRepositoryURL(for: repository.identifier)
        }
    }

    private var lineCount: Int {
        urlInput.components(separatedBy: .newlines).count
    }

    private func handleEsignSource(_ text: String) {
        if let decryptedString = ESignManager.shared.decryptSource(text) {
            urlInput = decryptedString
            themeManager.showToast("Converted to URLs")
        } else {
            themeManager.showToast("Failed to convert to URLs", isError: true)
        }
    }

    private func exportAsESign() {
        hideKeyboard()
        let urls = repositoryUrls
        if urls.isEmpty {
            HapticManager.shared.medium()
            themeManager.showToast("No repositories to export", isError: true)
            return
        }

        let urlList = urls.joined(separator: "\n")
        let encoded = ESignManager.shared.encryptSource(urlList)
        UIPasteboard.general.string = encoded
        HapticManager.shared.medium()
        themeManager.showToast("Copied eSign code!")
    }

    private func exportAsUrls() {
        hideKeyboard()
        let urls = repositoryUrls
        if urls.isEmpty {
            HapticManager.shared.medium()
            themeManager.showToast("No repositories to export", isError: true)
            return
        }

        let urlList = urls.joined(separator: "\n")
        UIPasteboard.general.string = urlList
        HapticManager.shared.medium()
        themeManager.showToast("Copied URLs!")
    }

    private func isURLAlreadyAdded(_ url: String) -> Bool {
        return viewModel.repositories.contains { repository in
            viewModel.getRepositoryURL(for: repository.identifier) == url
        }
    }
    
    private func cancelProcessing() {
        isCancelled = true
        isProcessing = false
    }

    var body: some View {
        NavigationView {
            Form {
                URLInputView(
                    urlInput: $urlInput,
                    isProcessing: $isProcessing,
                    isCancelled: $isCancelled,
                    theme: themeManager,
                    viewModel: viewModel,
                    dismiss: dismiss
                )
                
                ExportOptionsView(
                    theme: themeManager,
                    viewModel: viewModel
                )
                
                
                Section(
                    header: Text("DANGER").secondaryHeader(),
                ) {
                    Button(action: {
                        showDeleteView = true
                    }) {
                        HStack {
                            Text("Delete Repositories")
                        }
                    }
                    .foregroundColor(themeManager.accentColor)
                }
            }
            .navigationTitle("Repository Manager")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in Repository Manager")
                    dismiss()
                }
                .foregroundColor(themeManager.accentColor)
            )
            .sheet(isPresented: $showDeleteView) {
                DeleteView(viewModel: viewModel, themeManager: themeManager)
            }
        }
    }

}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}