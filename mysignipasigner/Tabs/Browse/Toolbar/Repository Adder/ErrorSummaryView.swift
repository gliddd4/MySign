//
//  ErrorSummaryView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ErrorSummaryView: View {
    let summary: ProcessingErrorSummary
    @ObservedObject var theme: Theme
    let onRetry: ([ValidationError]) -> Void
    let onExportErrors: ([ValidationError]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var retryableErrors: [ValidationError] {
        summary.errors.filter { $0.isRetryable }
    }
    
    private var nonRetryableErrors: [ValidationError] {
        summary.errors.filter { !$0.isRetryable }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Summary Section
                Section(header: Text("PROCESSING SUMMARY").secondaryHeader()) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("✅ Successfully Added:")
                            Spacer()
                            Text("\(summary.successCount)")
                                .bold()
                        }
                        
                        HStack {
                            Text("❌ Failed:")
                            Spacer()
                            Text("\(summary.errors.count)")
                                .bold()
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            Text("🔄 Can Retry:")
                            Spacer()
                            Text("\(summary.retryableCount)")
                                .bold()
                                .foregroundColor(summary.retryableCount > 0 ? theme.accentColor : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Error Breakdown Section
                if summary.networkErrors > 0 || summary.validationErrors > 0 || summary.serverErrors > 0 {
                    Section(header: Text("ERROR BREAKDOWN").secondaryHeader()) {
                        if summary.networkErrors > 0 {
                            HStack {
                                Text("📡 Network Errors")
                                Spacer()
                                Text("\(summary.networkErrors)")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        if summary.validationErrors > 0 {
                            HStack {
                                Text("⚠️ Validation Errors")
                                Spacer()
                                Text("\(summary.validationErrors)")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if summary.serverErrors > 0 {
                            HStack {
                                Text("🖥️ Server Errors")
                                Spacer()
                                Text("\(summary.serverErrors)")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
                
                // Retryable Errors Section
                if !retryableErrors.isEmpty {
                    Section(
                        header: Text("RETRYABLE ERRORS").secondaryHeader(),
                        footer: Text("These errors might be temporary and worth retrying.")
                    ) {
                        ForEach(retryableErrors.indices, id: \.self) { index in
                            let error = retryableErrors[index]
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(error.category.icon)
                                    Text(error.url)
                                        .font(.caption)
                                        .foregroundColor(theme.accentColor)
                                    Spacer()
                                }
                                
                                Text(error.error.localizedDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Non-Retryable Errors Section
                if !nonRetryableErrors.isEmpty {
                    Section(
                        header: Text("PERMANENT ERRORS").secondaryHeader(),
                        footer: Text("These errors require manual correction of the URLs.")
                    ) {
                        ForEach(nonRetryableErrors.indices, id: \.self) { index in
                            let error = nonRetryableErrors[index]
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(error.category.icon)
                                    Text(error.url)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                
                                Text(error.error.localizedDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Actions Section
                Section(header: Text("ACTIONS").secondaryHeader()) {
                    if summary.retryableCount > 0 {
                        Button(action: {
                            HapticManager.shared.medium()
                            onRetry(retryableErrors)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry \(summary.retryableCount) Failed URLs")
                            }
                        }
                        .foregroundColor(theme.accentColor)
                    }
                    
                    Button(action: {
                        HapticManager.shared.medium()
                        onExportErrors(summary.errors)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Copy Failed URLs to Clipboard")
                        }
                    }
                    .foregroundColor(theme.accentColor)
                }
            }
            .navigationTitle("Processing Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in Processing Results")
                    dismiss()
                }
                .foregroundColor(theme.accentColor)
            )
        }
    }
}