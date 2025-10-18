import SwiftUI
import Combine
import ZIPFoundation

struct CertificateManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // State for certificate import workflow
    @StateObject private var certificatePickerCoordinator = FilePickerCoordinator()
    @State private var showPasswordAlert = false
    @State private var tempPasswordInput = ""
    @State private var importInProgress = false
    
    // State for certificate list management
    @State private var certificateFolders: [CertificateFolder] = []
    @State private var isLoadingCertificates = false
    
    // State for sharing and deletion
    @State private var showDeleteConfirmation = false
    @State private var certificateToDelete: CertificateFolder?
    
    // State for individual certificate import
    @State private var pendingP12URL: URL?
    @State private var pendingMPURL: URL?
    @State private var showIndividualImportAlert = false
    
    @StateObject private var defaultCertificateManager = DefaultCertificateManager.shared
    
    private var defaultCertificate: CertificateFolder? {
        guard let defaultTeamName = defaultCertificateManager.defaultCertificateTeamName else { return nil }
        return certificateFolders.first { $0.teamName == defaultTeamName }
    }
    
    private var otherCertificates: [CertificateFolder] {
        guard let defaultTeamName = defaultCertificateManager.defaultCertificateTeamName else {
            return certificateFolders
        }
        return certificateFolders.filter { $0.teamName != defaultTeamName }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                List {
                    importSection()
                    defaultCertificateSection()
                    
                    if !otherCertificates.isEmpty {
                        otherCertificatesSection()
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .padding(.horizontal, 2)
            }
            .navigationTitle("Certificate Manager")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    HapticManager.shared.medium()
                    ToastManager.shared.showToast.log("Clicked Done (toolbar) in Certificate Manager")
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $certificatePickerCoordinator.isPresented) {
            UnifiedDocumentPicker(coordinator: certificatePickerCoordinator)
                .edgesIgnoringSafeArea(.bottom)
        }
        .alert("Enter P12 Password", isPresented: $showPasswordAlert) {
            TextField("Password", text: $tempPasswordInput)
            Button("OK") {
                handlePasswordInput()
            }
            Button("Cancel", role: .cancel) {
                tempPasswordInput = ""
                importInProgress = false
            }
        } message: {
            Text("Please enter the password for your P12 certificate")
        }
        .alert("Delete Certificate", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let certificate = certificateToDelete {
                    deleteCertificate(certificate)
                }
            }
            Button("Cancel", role: .cancel) {
                certificateToDelete = nil
            }
        } message: {
            if let certificate = certificateToDelete {
                Text("Are you sure you want to delete the certificate for \(certificate.teamName)? This action cannot be undone.")
            }
        }
        .alert("Import Certificate", isPresented: $showIndividualImportAlert) {
            Button("Import") {
                handleIndividualCertificateImport()
            }
            Button("Cancel", role: .cancel) {
                resetIndividualImportState()
            }
        } message: {
            if let p12URL = pendingP12URL, let mpURL = pendingMPURL {
                Text("Ready to import certificate with:\n• P12: \(p12URL.lastPathComponent)\n• Mobile Provision: \(mpURL.lastPathComponent)")
            } else if pendingP12URL != nil {
                Text("P12 file selected. Please select a Mobile Provision file to continue.")
            } else if pendingMPURL != nil {
                Text("Mobile Provision file selected. Please select a P12 file to continue.")
            }
        }
        .onAppear {
            loadCertificates()
        }
        .onChange(of: certificatePickerCoordinator.certificatePairImported) { newValue in
            if newValue {
                Task {
                    guard let p12URL = certificatePickerCoordinator.selectedCertificatePairP12URL,
                          let mpURL = certificatePickerCoordinator.selectedCertificatePairMPURL else { return }
                    
                    // Copy files to Imported Certificates folder first
                    let copiedFiles = await copyFilesToImportedCertificates(p12URL: p12URL, mpURL: mpURL)
                    
                    if let (copiedP12URL, copiedMPURL) = copiedFiles {
                        // Update the coordinator with the new URLs
                        certificatePickerCoordinator.selectedCertificatePairP12URL = copiedP12URL
                        certificatePickerCoordinator.selectedCertificatePairMPURL = copiedMPURL
                        
                        // Now try common passwords on the copied files
                        let commonPasswordSuccess = await CertificateManager.shared.tryCommonPasswords(p12URL: copiedP12URL)
                        
                        await MainActor.run {
                            if commonPasswordSuccess {
                                // Common password worked, proceed with import
                                handlePasswordInput()
                            } else {
                                // Common passwords failed, show manual password input
                                showPasswordAlert = true
                            }
                        }
                    } else {
                        await MainActor.run {
                            ToastManager.shared.showToast.error("Failed to copy certificate files")
                            resetImportState()
                        }
                    }
                }
            }
        }
        .onChange(of: certificatePickerCoordinator.individualP12Imported) { newValue in
            if newValue {
                handleIndividualFileImport()
            }
        }
        .onChange(of: certificatePickerCoordinator.individualMPImported) { newValue in
            if newValue {
                handleIndividualFileImport()
            }
        }
        .onChange(of: certificatePickerCoordinator.esigncertImported) { newValue in
            if newValue {
                handleEsigncertImport()
            }
        }
    }
    
    // MARK: - View Sections
    @ViewBuilder
    private func importSection() -> some View {
        Section(
            header: Text("IMPORT").secondaryHeader(),
            footer: Text("Import the .p12 & .mobileprovision files seperately or upload a .esigncert file")
        ) {
            Button(action: {
                HapticManager.shared.medium()
                certificatePickerCoordinator.startIndividualP12Import()
            }) {
                HStack {
                    Image("certificate")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import .p12 file")
                            .foregroundColor(.white)
                        
                        if certificatePickerCoordinator.individualP12Imported {
                            Text(".p12 certificate file selected")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .lineLimit(1)
                        } else {
                            Text("Select a .p12 certificate file")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            
            Button(action: {
                HapticManager.shared.medium()
                certificatePickerCoordinator.startIndividualMPImport()
            }) {
                HStack {
                    Image("certificate")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import .mobileprovision file")
                            .foregroundColor(.white)
                        
                        if certificatePickerCoordinator.individualMPImported {
                            Text(".mobileprovision certificate file selected")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .lineLimit(1)
                        } else {
                            Text("Select a .mobileprovision file")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            
            Button(action: {
                HapticManager.shared.medium()
                certificatePickerCoordinator.startEsigncertImport()
            }) {
                HStack {
                    Image("selectipa")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import .esigncert")
                            .foregroundColor(.white)
                        
                        if importInProgress {
                            Text("Importing...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else if certificatePickerCoordinator.esigncertImported {
                            Text(".p12 & .mobileprovision extracted from .esigncert file")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .lineLimit(1)
                        } else {
                            Text("Select a .esigncert file")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private func defaultCertificateSection() -> some View {
        Section(
            header: Text("DEFAULT CERTIFICATE").secondaryHeader(),
            footer: Text("This certificate will be used by default for signing apps.")
        ) {
            if let defaultCert = defaultCertificate {
                CertificateRowView(certificate: defaultCert, isDefault: true) {
                    // TODO: Add certificate selection/management actions
                }
                .contextMenu {
                    defaultCertificateContextMenu(for: defaultCert)
                }
            } else {
                Text("No certificates imported yet")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
        }
    }
    
    @ViewBuilder
    private func otherCertificatesSection() -> some View {
        Section(
            header: Text("CERTIFICATES").secondaryHeader()
        ) {
            ForEach(otherCertificates, id: \.teamName) { certificate in
                CertificateRowView(certificate: certificate, isDefault: false) {
                    // TODO: Add certificate selection/management actions
                }
                .contextMenu {
                    otherCertificateContextMenu(for: certificate)
                }
            }
        }
    }
    
    // MARK: - Context Menus
    @ViewBuilder
    private func defaultCertificateContextMenu(for certificate: CertificateFolder) -> some View {
        Button(action: {
            CertificateOperations.shared.shareCertificate(certificate)
        }) {
            HStack {
                Text("Share Certificate")
                Image(systemName: "square.and.arrow.up")
            }
        }
        
        if !otherCertificates.isEmpty {
            Button(action: {
                defaultCertificateManager.removeDefaultCertificate()
            }) {
                HStack {
                    Text("Remove as Default")
                    Image(systemName: "star.slash")
                }
            }
        }
        
        Button(role: .destructive) {
            certificateToDelete = certificate
            showDeleteConfirmation = true
        } label: {
            HStack {
                Text("Delete Certificate")
                Image(systemName: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func otherCertificateContextMenu(for certificate: CertificateFolder) -> some View {
        Button(action: {
            defaultCertificateManager.setDefaultCertificate(certificate.teamName)
        }) {
            HStack {
                Text("Set as Default")
                Image(systemName: "star")
            }
        }
        
        Button(action: {
            CertificateOperations.shared.shareCertificate(certificate)
        }) {
            HStack {
                Text("Share Certificate")
                Image(systemName: "square.and.arrow.up")
            }
        }
        
        Button(role: .destructive) {
            certificateToDelete = certificate
            showDeleteConfirmation = true
        } label: {
            HStack {
                Text("Delete Certificate")
                Image(systemName: "trash")
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadCertificates() {
        isLoadingCertificates = true
        
        Task {
            let certificates = await CertificateOperations.shared.loadCertificates()
            await MainActor.run {
                self.certificateFolders = certificates
                self.isLoadingCertificates = false
            }
        }
    }
    
    private func deleteCertificate(_ certificate: CertificateFolder) {
        Task {
            let success = await CertificateOperations.shared.deleteCertificate(certificate)
            if success {
                await MainActor.run {
                    loadCertificates()
                    certificateToDelete = nil
                }
            } else {
                await MainActor.run {
                    certificateToDelete = nil
                }
            }
        }
    }
    
    private func handlePasswordInput() {
        guard let p12URL = certificatePickerCoordinator.selectedCertificatePairP12URL,
              let mpURL = certificatePickerCoordinator.selectedCertificatePairMPURL else {
            ToastManager.shared.showToast.error("Certificate files not found")
            tempPasswordInput = ""
            return
        }
        
        importInProgress = true
        
        Task {
            // If we have a validated password from common passwords, use it
            // Otherwise use the manual password input
            let passwordToUse = CertificateManager.shared.hasValidP12Password() ?
                (CertificateManager.shared.getValidatedPassword() ?? tempPasswordInput) :
                tempPasswordInput
            
            CertificateOperations.shared.handlePasswordInput(
                password: passwordToUse,
                p12URL: p12URL,
                mpURL: mpURL,
                onSuccess: { teamName in
                    defaultCertificateManager.autoSetFirstCertificateAsDefault(teamName)
                    loadCertificates()
                    resetImportState()
                },
                onFailure: {
                    importInProgress = false
                    showPasswordAlert = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showPasswordAlert = true
                    }
                }
            )
        }
        tempPasswordInput = ""
    }
    
    private func resetImportState() {
        importInProgress = false
        certificatePickerCoordinator.certificatePairImported = false
        certificatePickerCoordinator.selectedCertificatePairP12URL = nil
        certificatePickerCoordinator.selectedCertificatePairMPURL = nil
        certificatePickerCoordinator.esigncertImported = false
        certificatePickerCoordinator.selectedEsigncertURL = nil
        resetIndividualImportState()
    }
    
    private func resetIndividualImportState() {
        pendingP12URL = nil
        pendingMPURL = nil
        certificatePickerCoordinator.individualP12Imported = false
        certificatePickerCoordinator.individualMPImported = false
        certificatePickerCoordinator.selectedIndividualP12URL = nil
        certificatePickerCoordinator.selectedIndividualMPURL = nil
    }
    
    private func copyFilesToImportedCertificates(p12URL: URL, mpURL: URL) async -> (URL, URL)? {
        guard let importedCertificatesURL = DirectoryManager.shared.getURL(for: .importedCertificates) else {
            await MainActor.run {
                ToastManager.shared.showToast.error("Cannot access Imported Certificates directory")
            }
            return nil
        }
        
        do {
            // Create unique filenames to avoid conflicts
            let timestamp = Int(Date().timeIntervalSince1970)
            let p12FileName = "\(timestamp)_\(p12URL.lastPathComponent)"
            let mpFileName = "\(timestamp)_\(mpURL.lastPathComponent)"
            
            let destinationP12URL = importedCertificatesURL.appendingPathComponent(p12FileName)
            let destinationMPURL = importedCertificatesURL.appendingPathComponent(mpFileName)
            
            // Remove existing files if they exist
            try? FileManager.default.removeItem(at: destinationP12URL)
            try? FileManager.default.removeItem(at: destinationMPURL)
            
            // Copy files
            try FileManager.default.copyItem(at: p12URL, to: destinationP12URL)
            try FileManager.default.copyItem(at: mpURL, to: destinationMPURL)
            
            await MainActor.run {
                ToastManager.shared.addLog("P12 copied to: \(destinationP12URL.path)")
                ToastManager.shared.addLog("MP copied to: \(destinationMPURL.path)")
            }
            
            return (destinationP12URL, destinationMPURL)
            
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.error("Failed to copy certificate files: \(error.localizedDescription)")
                ToastManager.shared.addLog("Copy error: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    private func handleIndividualFileImport() {
        // Update pending URLs based on what was imported
        if certificatePickerCoordinator.individualP12Imported,
           let p12URL = certificatePickerCoordinator.selectedIndividualP12URL {
            pendingP12URL = p12URL
        }
        
        if certificatePickerCoordinator.individualMPImported,
           let mpURL = certificatePickerCoordinator.selectedIndividualMPURL {
            pendingMPURL = mpURL
        }
        
        // Check if we have both files
        if pendingP12URL != nil && pendingMPURL != nil {
            showIndividualImportAlert = true
        } else {
            // Show status message
            if pendingP12URL != nil {
                ToastManager.shared.showToast.warning("P12 file selected. Please select a Mobile Provision file.")
            } else if pendingMPURL != nil {
                ToastManager.shared.showToast.warning("Mobile Provision file selected. Please select a P12 file.")
            }
        }
    }
    
    private func handleIndividualCertificateImport() {
        guard let p12URL = pendingP12URL, let mpURL = pendingMPURL else { return }
        
        importInProgress = true
        
        Task {
            // Copy files to Imported Certificates folder first
            let copiedFiles = await copyFilesToImportedCertificates(p12URL: p12URL, mpURL: mpURL)
            
            if let (copiedP12URL, copiedMPURL) = copiedFiles {
                // Update the coordinator with the new URLs for password handling
                certificatePickerCoordinator.selectedCertificatePairP12URL = copiedP12URL
                certificatePickerCoordinator.selectedCertificatePairMPURL = copiedMPURL
                
                // Now try common passwords on the copied files
                let commonPasswordSuccess = await CertificateManager.shared.tryCommonPasswords(p12URL: copiedP12URL)
                
                await MainActor.run {
                    resetIndividualImportState()
                    
                    if commonPasswordSuccess {
                        // Common password worked, proceed with import
                        handlePasswordInput()
                    } else {
                        // Common passwords failed, show manual password input
                        showPasswordAlert = true
                    }
                }
            } else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to copy certificate files")
                    resetIndividualImportState()
                    importInProgress = false
                }
            }
        }
    }
    
    private func handleEsigncertImport() {
        guard let esigncertURL = certificatePickerCoordinator.selectedEsigncertURL else { return }
        
        importInProgress = true
        ToastManager.shared.showToast.success("Processing certificate package...")
        
        Task {
            let success = await extractAndImportEsigncert(esigncertURL: esigncertURL)
            
            await MainActor.run {
                if success {
                    loadCertificates()
                    resetImportState()
                    ToastManager.shared.showToast.success("Certificate package imported successfully")
                } else {
                    importInProgress = false
                    ToastManager.shared.showToast.error("Failed to import certificate package")
                }
            }
        }
    }
    
    private func extractAndImportEsigncert(esigncertURL: URL) async -> Bool {
        guard let certificatesPath = DirectoryManager.shared.getURL(for: .importedCertificates) else {
            await MainActor.run {
                ToastManager.shared.showToast.error("Cannot access Imported Certificates directory")
            }
            return false
        }
        
        do {
            // Create a temporary directory for extraction
            let tempDir = certificatesPath.appendingPathComponent("temp_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            defer {
                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            // Extract the .esigncert file (it's a zip file)
            let archive = try Archive(url: esigncertURL, accessMode: .read)
            
            var p12URL: URL?
            var mpURL: URL?
            var password: String?
            
            // Extract all files and identify them
            for entry in archive {
                let entryURL = tempDir.appendingPathComponent(entry.path)
                
                // Create parent directories if needed
                let parentDir = entryURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                
                // Extract the file
                _ = try archive.extract(entry, to: entryURL)
                
                let fileName = entryURL.lastPathComponent.lowercased()
                
                if fileName.hasSuffix(".p12") {
                    p12URL = entryURL
                } else if fileName.hasSuffix(".mobileprovision") {
                    mpURL = entryURL
                } else if fileName == "password.txt" {
                    password = try String(contentsOf: entryURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Validate that we have all required files
            guard let p12 = p12URL, let mp = mpURL, let pwd = password else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Invalid certificate package: Missing required files")
                }
                return false
            }
            
            // Validate the P12 with the password
            let validationResult = CertificateManager.shared.validateP12Password(p12URL: p12, password: pwd)
            
            switch validationResult {
            case .success(let teamName):
                await MainActor.run {
                    ToastManager.shared.showToast.success("Certificate validated for team: \(teamName)")
                }
                
                // Create the certificate folder and copy files
                let success = await CertificateManager.shared.createCertificateFolder(mpURL: mp, p12URL: p12)
                
                if success {
                    await MainActor.run {
                        DefaultCertificateManager.shared.autoSetFirstCertificateAsDefault(teamName)
                    }
                    return true
                } else {
                    return false
                }
                
            case .failure:
                await MainActor.run {
                    ToastManager.shared.showToast.error("Invalid certificate package: Password validation failed")
                }
                return false
            }
            
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.error("Failed to extract certificate package: \(error.localizedDescription)")
            }
            return false
        }
    }
}
