//
//  URLInputView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct URLInputView: View {
    @Binding var urlInput: String
    @Binding var isProcessing: Bool
    @Binding var isCancelled: Bool
    @ObservedObject var theme: Theme
    @ObservedObject var viewModel: RepositoryViewModel
    let dismiss: DismissAction
    
    // Progress tracking state
    @StateObject private var progressState = ProcessingProgress()
    @State private var startTime: Date?
    @StateObject private var performanceMonitor = PerformanceMonitor()
    
    // Focus state to control keyboard
    @FocusState private var isTextEditorFocused: Bool
    
    // Error handling state
    @State private var showErrorSummary = false
    @State private var errorSummary: ProcessingErrorSummary?
    @State private var showRetryDialog = false
    @State private var retryableErrors: [ValidationError] = []
    
    private var validUrls: [String] {
        // Check if input is an e-sign source before validation
        let inputToValidate = isESignSource(urlInput) ? convertESignSource(urlInput) : urlInput
        return ValidationManager.shared.validateURLs(inputToValidate)
    }
    
    private var buttonTitle: String {
        if isProcessing {
            return "Processing..."
        }
        return validUrls.count > 1 ? "Add Repositories" : "Add Repository"
    }
    
    private var estimatedTimeRemaining: String {
        guard let startTime = startTime,
              progressState.totalCount > 0,
              progressState.processedCount > 0 else {
            return "Calculating..."
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let rate = Double(progressState.processedCount) / elapsed
        let remaining = progressState.totalCount - progressState.processedCount
        let estimatedSeconds = Double(remaining) / rate
        
        if estimatedSeconds < 60 {
            return "\(Int(estimatedSeconds))s remaining"
        } else {
            let minutes = Int(estimatedSeconds / 60)
            let seconds = Int(estimatedSeconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s remaining"
        }
    }
    
    private func isESignSource(_ text: String) -> Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("source[")
    }
    
    private func convertESignSource(_ text: String) -> String {
        if let decryptedString = ESignManager.shared.decryptSource(text) {
            return decryptedString
        }
        return text
    }
    
    private func handleEsignSource(_ text: String) {
        if let decryptedString = ESignManager.shared.decryptSource(text) {
            urlInput = decryptedString
            theme.showToast("Converted to URLs")
        } else {
            theme.showToast("Failed to convert to URLs", isError: true)
        }
    }

    var body: some View {
        Section(
            header: Text("IMPORT").secondaryHeader(),
            footer: Text("Paste your URL list or eSign repo code above.")
        ) {
            if isProcessing {
                VStack(spacing: 12) {
                    // Progress bar
                    ProgressView(value: progressState.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: theme.accentColor))
                    
                    // Only show time remaining for larger batches
                    if progressState.totalCount > 5 {
                        HStack {
                            Text(estimatedTimeRemaining)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                Button(buttonTitle) {
                    Task {
                        await addURLs()
                    }
                }
                .foregroundColor(theme.accentColor)
                .disabled(validUrls.isEmpty)
            }
            
            TextEditor(text: $urlInput)
                .font(.body)
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .frame(minHeight: 60)
                .background(Color.clear)
                .disabled(isProcessing)
                .focused($isTextEditorFocused)
                .onChange(of: urlInput) { newValue in
                    if newValue.contains("\n") {
                        if newValue.hasPrefix("source[") {
                            handleEsignSource(newValue)
                        } else {
                            let (processedText, removedDuplicates) = ValidationManager.shared.processURLInput(newValue)
                            if processedText != newValue {
                                DispatchQueue.main.async {
                                    urlInput = processedText
                                    if !removedDuplicates.isEmpty {
                                        theme.showToast("\(removedDuplicates.count) duplicate \(removedDuplicates.count == 1 ? "URL" : "URLs") removed")
                                    }
                                }
                            }
                        }
                    }
                }
        }
        .sheet(isPresented: $showErrorSummary) {
            if let summary = errorSummary {
                ErrorSummaryView(
                    summary: summary,
                    theme: theme,
                    onRetry: { retryErrors in
                        retryableErrors = retryErrors
                        showRetryDialog = true
                    },
                    onExportErrors: { exportErrors in
                        exportFailedURLs(exportErrors)
                    }
                )
            }
        }
        .sheet(isPresented: $showRetryDialog) {
            RetryDialogView(
                errors: retryableErrors,
                theme: theme,
                onRetry: { urlsToRetry in
                    Task {
                        await retryURLs(urlsToRetry)
                    }
                }
            )
        }
    }
    
    private func addURLs() async {
        await MainActor.run {
            HapticManager.shared.medium()
        }
        
        // Handle e-sign conversion before processing
        let processedInput = isESignSource(urlInput) ? convertESignSource(urlInput) : urlInput
        if processedInput != urlInput {
            await MainActor.run {
                urlInput = processedInput
                theme.showToast("Converted to URLs")
            }
        }
        
        // Always use the processed input (converted URLs) for validation and processing
        let urlsToProcess = ValidationManager.shared.validateURLs(processedInput)
        
        if urlsToProcess.isEmpty {
            await MainActor.run {
                HapticManager.shared.medium()
                theme.showToast("Please enter valid URLs (http:// or https:// only)", isError: true)
            }
            return
        }
        
        await MainActor.run {
            isCancelled = false
            isProcessing = true
            startTime = Date()
            progressState.initialize(totalCount: urlsToProcess.count)
            performanceMonitor.startMonitoring()
        }
        
        let batchedProgressCallback = BatchedProgressCallback { updatedProgress in
            Task { @MainActor in
                progressState.updateFrom(updatedProgress)
            }
        }
        
        let result = await Task.detached(priority: .userInitiated) { () -> ProcessingResult in
            var addedURLs = [String]()
            var duplicateCount = 0
            var validationErrors = [ValidationError]()
            var localProgress = LocalProcessingProgress()
            
            let optimalConcurrency = await MainActor.run { 
                performanceMonitor.getOptimalConcurrency(for: urlsToProcess.count) 
            }
            
            var uniqueUrlsToValidate = [String]()
            for url in urlsToProcess {
                if await MainActor.run { isCancelled } {
                    return ProcessingResult(
                        addedURLs: [], duplicateCount: 0, validationErrors: [], 
                        wasCancelled: true
                    )
                }
                
                if await MainActor.run { isURLAlreadyAdded(url) } {
                    duplicateCount += 1
                } else if !uniqueUrlsToValidate.contains(url) {
                    uniqueUrlsToValidate.append(url)
                } else {
                    duplicateCount += 1
                }
            }
            
            localProgress.initialize(totalCount: uniqueUrlsToValidate.count)
            localProgress.duplicateCount = duplicateCount
            batchedProgressCallback.update(localProgress)
            
            if !uniqueUrlsToValidate.isEmpty {
                let maxConcurrent = optimalConcurrency
                await MainActor.run { 
                    performanceMonitor.currentConcurrency = maxConcurrent 
                }
                
                for chunkStart in stride(from: 0, to: uniqueUrlsToValidate.count, by: maxConcurrent) {
                    let currentConcurrency = await MainActor.run { 
                        performanceMonitor.getAdjustedConcurrency(baseConcurrency: maxConcurrent) 
                    }
                    
                    if await MainActor.run { isCancelled } {
                        return ProcessingResult(
                            addedURLs: addedURLs, duplicateCount: duplicateCount, 
                            validationErrors: validationErrors, wasCancelled: true
                        )
                    }
                    
                    let endIndex = min(chunkStart + currentConcurrency, uniqueUrlsToValidate.count)
                    let urlChunk = Array(uniqueUrlsToValidate[chunkStart..<endIndex])
                    
                    if await MainActor.run { performanceMonitor.shouldThrottle() } {
                        try? await Task.sleep(nanoseconds: 100_000_000) 
                    }
                    
                    await withTaskGroup(of: (url: String, isValid: Bool, error: Error?).self) { group in
                        for url in urlChunk {
                            if await MainActor.run { isCancelled } {
                                return
                            }
                            
                            group.addTask {
                                let result = await ValidationManager.shared.validateRepositoryURL(url)
                                switch result {
                                case .success(_):
                                    return (url: url, isValid: true, error: nil)
                                case .failure(let error):
                                    return (url: url, isValid: false, error: error)
                                }
                            }
                        }
                        
                        for await result in group {
                            if await MainActor.run { isCancelled } {
                                break
                            }
                            
                            if result.isValid {
                                addedURLs.append(result.url)
                                localProgress.successCount += 1
                            } else if let error = result.error {
                                let validationError = ValidationError(
                                    url: result.url,
                                    error: error,
                                    category: ErrorCategorizer.categorize(error),
                                    isRetryable: ErrorCategorizer.isRetryable(error),
                                    timestamp: Date()
                                )
                                validationErrors.append(validationError)
                                localProgress.failureCount += 1
                            }
                            
                            localProgress.processedCount += 1
                            batchedProgressCallback.update(localProgress)
                        }
                    }
                    
                    if await MainActor.run { performanceMonitor.shouldPauseBetweenChunks() } {
                        try? await Task.sleep(nanoseconds: 50_000_000) 
                    }
                }
            }
            
            return ProcessingResult(
                addedURLs: addedURLs, duplicateCount: duplicateCount,
                validationErrors: validationErrors, wasCancelled: await MainActor.run { isCancelled }
            )
        }.value
        
        await MainActor.run {
            performanceMonitor.stopMonitoring()
            handleProcessingResultWithErrorSummary(result, originalURLCount: urlsToProcess.count)
        }
    }
    
    @MainActor
    private func handleProcessingResultWithErrorSummary(_ result: ProcessingResult, originalURLCount: Int) {
        progressState.reset()
        startTime = nil
        
        // Dismiss keyboard and keep it dismissed
        isTextEditorFocused = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isTextEditorFocused = false
            self.hideKeyboard()
        }
        
        if !result.wasCancelled {
            for url in result.addedURLs {
                if !isURLAlreadyAdded(url) {
                    viewModel.addRepository(url: url)
                }
            }
            
            let successCount = result.addedURLs.count
            let duplicateCount = result.duplicateCount
            let errorCount = result.validationErrors.count
            
            // Create comprehensive log entry
            var logEntries: [String] = []
            
            if duplicateCount > 0 {
                logEntries.append("Duplicates:")
                // We need to track duplicate URLs - for now we'll show the count
                logEntries.append("\(duplicateCount) duplicate repositories were blocked")
            }
            
            if errorCount > 0 {
                logEntries.append("Errors:")
                for error in result.validationErrors {
                    logEntries.append("\(error.url) - \(error.error.localizedDescription)")
                }
            }
            
            if successCount > 0 {
                logEntries.append("Success:")
                for url in result.addedURLs {
                    logEntries.append(url)
                }
            }
            
            // Log the comprehensive summary
            if !logEntries.isEmpty {
                let fullLog = logEntries.joined(separator: "\n")
                ToastManager.shared.showToast.log(fullLog)
            }
            
            // Show individual toasts
            if duplicateCount > 0 {
                theme.showToast("Blocked \(duplicateCount) duplicate repositories", isError: false)
            }
            
            if errorCount > 0 {
                theme.showToast("\(errorCount) repositories failed to import", isError: true)
            }
            
            if successCount > 0 {
                theme.showToast("Added \(successCount) repositories", isError: false)
            }
            
            // Handle edge cases
            if originalURLCount == 1 && duplicateCount == 1 && successCount == 0 && errorCount == 0 {
                theme.showToast("Blocked 1 duplicate repository", isError: false)
            } else if successCount == 0 && duplicateCount == 0 && errorCount > 0 {
                // Already handled above with error toast
            }
        }
        
        isProcessing = false
    }
    
    private func exportFailedURLs(_ errors: [ValidationError]) {
        let urlList = errors.map { error in
            "\(error.url) - \(error.error.localizedDescription)"
        }.joined(separator: "\n")
        
        UIPasteboard.general.string = urlList
        HapticManager.shared.medium()
        theme.showToast("Failed URLs copied to clipboard!")
    }
    
    private func retryURLs(_ urls: [String]) async {
        let existingURLs = urlInput.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let allURLs = (existingURLs + urls).joined(separator: "\n")
        urlInput = allURLs
        
        await addURLs()
    }
    
    @MainActor
    private func isURLAlreadyAdded(_ url: String) -> Bool {
        return viewModel.repositories.contains { repository in
            viewModel.getRepositoryURL(for: repository.identifier) == url
        }
    }
    
    private func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}

// MARK: - Supporting Types

/// Tracks progress during repository processing operations
class ProcessingProgress: ObservableObject {
    @Published var totalCount: Int = 0
    @Published var processedCount: Int = 0
    @Published var successCount: Int = 0
    @Published var failureCount: Int = 0
    @Published var duplicateCount: Int = 0
    
    var progress: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(processedCount) / Double(totalCount)
    }
    
    func initialize(totalCount: Int) {
        self.totalCount = totalCount
        self.processedCount = 0
        self.successCount = 0
        self.failureCount = 0
        self.duplicateCount = 0
    }
    
    func reset() {
        initialize(totalCount: 0)
    }
    
    func updateFrom(_ other: LocalProcessingProgress) {
        totalCount = other.totalCount
        processedCount = other.processedCount
        successCount = other.successCount
        failureCount = other.failureCount
        duplicateCount = other.duplicateCount
    }
}

/// Local progress tracking for background thread operations
struct LocalProcessingProgress {
    var totalCount: Int = 0
    var processedCount: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var duplicateCount: Int = 0
    
    var progress: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(processedCount) / Double(totalCount)
    }
    
    mutating func initialize(totalCount: Int) {
        self.totalCount = totalCount
        self.processedCount = 0
        self.successCount = 0
        self.failureCount = 0
        self.duplicateCount = 0
    }
}

/// Monitors system performance and adjusts processing parameters accordingly
class PerformanceMonitor: ObservableObject {
    @Published var currentConcurrency: Int = 10
    @Published var isThrottled: Bool = false
    private var lastUpdateTime: Date = Date()
    
    func startMonitoring() {
        isThrottled = false
        lastUpdateTime = Date()
    }
    
    func stopMonitoring() {
        isThrottled = false
    }
    
    func getOptimalConcurrency(for batchSize: Int) -> Int {
        let processInfo = ProcessInfo.processInfo
        let baseConcurrency = 10
        
        var concurrency = baseConcurrency
        if batchSize > 100 {
            concurrency = 15 
        } else if batchSize < 20 {
            concurrency = 8  
        }
        
        switch processInfo.thermalState {
        case .nominal:
            return concurrency
        case .fair:
            return max(8, concurrency - 2)
        case .serious:
            isThrottled = true
            return max(5, concurrency - 5)
        case .critical:
            isThrottled = true
            return 3
        @unknown default:
            return baseConcurrency
        }
    }
    
    func getAdjustedConcurrency(baseConcurrency: Int) -> Int {
        let processInfo = ProcessInfo.processInfo
        
        switch processInfo.thermalState {
        case .nominal:
            isThrottled = false
            return baseConcurrency
        case .fair:
            isThrottled = false
            return max(6, baseConcurrency - 2)
        case .serious, .critical:
            isThrottled = true
            return max(3, baseConcurrency - 4)
        @unknown default:
            return baseConcurrency
        }
    }
    
    func shouldThrottle() -> Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.thermalState == .serious || processInfo.thermalState == .critical
    }
    
    func shouldPauseBetweenChunks() -> Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.thermalState == .serious || processInfo.thermalState == .critical
    }
}

/// Batches progress updates to optimize UI performance
class BatchedProgressCallback {
    private let callback: (LocalProcessingProgress) -> Void
    private var lastUpdate: Date = Date()
    private let batchInterval: TimeInterval = 0.3 
    private var pendingUpdate: LocalProcessingProgress?
    
    init(_ callback: @escaping (LocalProcessingProgress) -> Void) {
        self.callback = callback
    }
    
    func update(_ progress: LocalProcessingProgress) {
        let now = Date()
        pendingUpdate = progress
        
        if now.timeIntervalSince(lastUpdate) >= batchInterval || progress.processedCount == progress.totalCount {
            callback(progress)
            lastUpdate = now
            pendingUpdate = nil
        }
    }
}

/// Enhanced error handling structures
struct ValidationError {
    let url: String
    let error: Error
    let category: ErrorCategory
    let isRetryable: Bool
    let timestamp: Date
}

enum ErrorCategory {
    case network
    case validation
    case server
    case unknown
    
    var displayName: String {
        switch self {
        case .network: return "Network"
        case .validation: return "Validation"
        case .server: return "Server"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .network: return ""
        case .validation: return ""
        case .server: return ""
        case .unknown: return ""
        }
    }
}

struct ProcessingErrorSummary {
    let errors: [ValidationError]
    let totalProcessed: Int
    let networkErrors: Int
    let validationErrors: Int
    let serverErrors: Int
    let retryableCount: Int
    
    var successCount: Int {
        totalProcessed - errors.count
    }
}

/// Categorizes errors for better user understanding
struct ErrorCategorizer {
    static func categorize(_ error: Error) -> ErrorCategory {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("network") || errorDescription.contains("timeout") || 
           errorDescription.contains("connection") || errorDescription.contains("dns") {
            return .network
        } else if errorDescription.contains("invalid") || errorDescription.contains("malformed") || 
                  errorDescription.contains("format") {
            return .validation
        } else if errorDescription.contains("server") || errorDescription.contains("404") || 
                  errorDescription.contains("403") || errorDescription.contains("500") {
            return .server
        } else {
            return .unknown
        }
    }
    
    static func isRetryable(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("network") || errorDescription.contains("timeout") || 
           errorDescription.contains("connection") {
            return true
        }
        
        if errorDescription.contains("500") || errorDescription.contains("503") {
            return true
        }
        
        if errorDescription.contains("invalid") || errorDescription.contains("malformed") || 
           errorDescription.contains("404") {
            return false
        }
        
        return true 
    }
}

/// Encapsulates the results of background URL processing with enhanced error handling
private struct ProcessingResult {
    let addedURLs: [String]
    let duplicateCount: Int
    let validationErrors: [ValidationError]
    let wasCancelled: Bool
}