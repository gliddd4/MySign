//
//  LogsView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct LogsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: Theme
    @State private var searchText = ""
    @ObservedObject private var toastManager = ToastManager.shared

    private var filteredLogs: [String] {
        let logsToShow = toastManager.logs.reversed()
        guard !searchText.isEmpty else { return Array(logsToShow) }
        return logsToShow.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredLogs, id: \.self) { log in
                    Text(log)
                        .textSelection(.enabled)
                        .onTapGesture {
                            HapticManager.shared.medium()
                            UIPasteboard.general.string = log
                            ToastManager.shared.showToast.success("Copied log")
                        }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 34)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: HStack {
                    Button(action: {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Clicked Copy (toolbar) in Logs")
                        UIPasteboard.general.string = toastManager.logs.joined(separator: "\n")
                        ToastManager.shared.showToast.success("Copied logs")
                    }) {
                        Image(systemName: "doc.on.doc")
                    }

                    Button(action: {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Clicked Delete (toolbar) in Logs")
                        ToastManager.shared.clearLogs()
                    }) {
                        Image(systemName: "trash")
                    }
                },
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in Logs")
                    dismiss()
                }
            )
        }
    }
}
