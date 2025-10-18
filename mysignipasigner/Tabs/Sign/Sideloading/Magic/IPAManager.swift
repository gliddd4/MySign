import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import Swifter
import Combine

@MainActor
class IPAManager: ObservableObject {
    // File selection
    @Published var selectedFileURL: URL?
    @Published var fileImported = false
    @Published var mobileProvisionImported = false
    @Published var tweakImported = false
    @Published var p12Imported = false
    @Published var selectedMobileProvisionURL: URL?
    @Published var selectedTweakURL: URL?
    @Published var selectedP12URL: URL?
    
    @Published var showURLInputAlert = false
    
    // App customization
    @Published var customApp = false
    @Published var customAppLink = ""
    @Published var customAppName = ""
    @Published var extractedPath = ""
    
    // Signing inputs
    @Published var bundleidInput: String = ""
    @Published var appNameInput: String = ""
    @Published var p12PasswordInput: String = ""
    @Published var appVersionInput: String = ""
    
    // UI state
    @Published var isPresentingPopup: Bool = false
    @Published var presentingPopupTitle: String = ""
    @Published var visSigningPercent = 0
    @Published var p12Error: String = ""
    @Published var showP12Error: Bool = false
    
    // Managers
    private weak var sideloadingViewModel: SideloadingViewModel?
    let timerManager: TimerManager
    private let installationManager: InstallationManager
    private let signingManager: SigningManager
    private var cancellables = Set<AnyCancellable>()
    
    init(sideloadingViewModel: SideloadingViewModel) {
        self.sideloadingViewModel = sideloadingViewModel
        self.timerManager = TimerManager()
        self.installationManager = InstallationManager()
        self.signingManager = SigningManager(sideloadingViewModel: sideloadingViewModel)
        
        setupFileSelectionHandler()
    }
    
    private func setupFileSelectionHandler() {
        //
        $selectedFileURL
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] url in
                guard let self, let url else { return }
                Task { await self.handleFileSelection(url: url) }
            }
            .store(in: &cancellables)
    }
    
    private func handleFileSelection(url: URL) async {
        do {
            let appName = try await IPAParser.extractAppNameFromZIP(fileURL: url)
            await MainActor.run {
                self.appNameInput = appName
            }
        } catch {
            ToastManager.shared.showToast.error("App name extraction error: \(error)")
            ToastManager.shared.showToast.error("Failed to extract app name")
            await MainActor.run {
                self.appNameInput = ""
            }
        }
    }
    
    func downloadFileAndSideload(from urlString: String) async {
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                ToastManager.shared.showToast.error("Invalid URL provided")
            }
            return
        }

        do {
            await MainActor.run {
                ToastManager.shared.showToast("Starting IPA download...")
                globalSideloadingPercentage = 7
                globalSideloadingStatus?.sideloadingPercentage = 7
            }

            let session = URLSession.shared
            let (localURL, _) = try await session.download(from: url)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent("downloaded-file.ipa")
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: localURL, to: destinationURL)
            
            await MainActor.run {
                self.selectedFileURL = destinationURL
            }
            
            await resetSideloadingState()
            let success = await sideload(ipaPath: destinationURL)
            
            await MainActor.run {
                if !success {
                    ToastManager.shared.showToast.error("Sideloading process failed")
                }
            }
            
        } catch {
            ToastManager.shared.showToast.error("Download process error: \(error)")
            await MainActor.run {
                ToastManager.shared.showToast.error("Download failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetSideloadingState() async {
        await MainActor.run {
            currentSignedTweaks = 0
            totalTweaks = 1
            globalSideloadingPercentage = 0
            globalSideloadingStatus?.sideloadingPercentage = 0
            globalSideloadingStatus?.resetSignedTweaks()
            progress = 0
        }
    }
    
    func sideload(ipaPath: URL, skipInstallation: Bool = false) async -> Bool {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ToastManager.shared.showToast.error("Cannot access documents directory")
            return false
        }
        
        do {
            try await FileUtilities.clearTemporaryFiles(deleteCertificates: true)
            
            let signedIPAPath = documentsDirectory.appendingPathComponent("debugger.ipa")
            
            ToastManager.shared.showToast.silentWarning("Starting installation")
            ToastManager.shared.showToast.silentWarning("Extracting IPA from: \(ipaPath.path)")
            let extractedPayloadPath = try await FileUtilities.extractIPAPayload(ipaFilePath: ipaPath)
            
            guard fileManager.fileExists(atPath: extractedPayloadPath.path) else {
                ToastManager.shared.showToast.error("Error: Payload directory not found after extraction")
                return false
            }
            
            ToastManager.shared.showToast.silentWarning("Processing IPA at \(ipaPath.lastPathComponent)")
            ToastManager.shared.showToast.silentWarning("Extracting IPA")
            ToastManager.shared.showToast.silentSuccess("Finished extracting")
            ToastManager.shared.showToast.silentWarning("Packaging")
            
            guard let appFolderURL = try fileManager.contentsOfDirectory(at: extractedPayloadPath, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }) else {
                // Keep error visible
                ToastManager.shared.showToast.error("Missing application bundle")
                return false
            }
            
            await injectDefaultTweaks(into: appFolderURL)
            
            await timerManager.startTimer(fileURL: ipaPath)
            
            let tweakPath = selectedTweakURL == ipaPath ? "" : selectedTweakURL?.path ?? ""
            
            self.visSigningPercent = 30
            
            let finalBundleId = bundleidInput.isEmpty ? await IPAParser.extractBundleId(fromPayloadFolder: extractedPayloadPath.path) : bundleidInput
            let finalAppName = appNameInput.isEmpty ? await IPAParser.extractAppName(fromPayloadFolder: extractedPayloadPath.path) : appNameInput
            let finalVersion = appVersionInput.isEmpty ? await IPAParser.extractBundleVersion(fromPayloadFolder: extractedPayloadPath.path) : appVersionInput
            
            guard !finalBundleId.isEmpty else {
                ToastManager.shared.showToast.error("Bundle ID is required for signing")
                timerManager.stopTimer()
                return false
            }
            
            guard !finalAppName.isEmpty else {
                ToastManager.shared.showToast.error("App name is required for signing")
                timerManager.stopTimer()
                return false
            }
            
            let validatedVersion = finalVersion.isEmpty ? "1" : finalVersion
            
            // File size calculation
            let fileSize = FileUtilities.getFileSize(url: ipaPath)
            ToastManager.shared.showToast.silentWarning("File size: \(fileSize)")
            
            if tweakImported {
                try await FileUtilities.countDylibsAndFrameworks(
                    inPayloadFolderPath: extractedPayloadPath.path,
                    tweakImported: tweakImported,
                    sideloadingViewModel: sideloadingViewModel
                )
            }
            
            let (certificateP12Path, certificateMPPath, certificatePassword): (String?, String?, String?) = {
                if let manualP12 = selectedP12URL?.path, let manualMP = selectedMobileProvisionURL?.path {
                    // Use manually selected certificates
                    return (manualP12, manualMP, p12PasswordInput)
                } else {
                    // Use default certificate
                    let defaultCert = getDefaultCertificateFiles()
                    ToastManager.shared.showToast.silentWarning("Using default certificate: \(DefaultCertificateManager.shared.getDefaultCertificate() ?? "Unknown")")
                    return (defaultCert.p12Path, defaultCert.mpPath, p12PasswordInput.isEmpty ? (defaultCert.password ?? "") : p12PasswordInput)
                }
            }()
            
            guard let p12Path = certificateP12Path, let mpPath = certificateMPPath else {
                ToastManager.shared.showToast.error("No certificate available. Please import a certificate first.")
                timerManager.stopTimer()
                return false
            }
            
            let code = await signingManager.sign(
                appFolderURL: appFolderURL,
                p12Path: p12Path,
                provisioningProfilePath: mpPath,
                password: certificatePassword ?? "",
                bundleId: finalBundleId,
                appName: finalAppName,
                appVersion: validatedVersion,
                tweakPath: tweakPath
            )
            
            if code != 0 {
                await handleCirclefySigningFailure()
            }
            
            if code == 0 {
                ToastManager.shared.showToast.silentSuccess("Signing successful, creating IPA...")
                
                self.visSigningPercent = 60
                
                try await Task.detached(priority: .background) {
                    try FileManager.default.zipItem(at: extractedPayloadPath, to: signedIPAPath)
                }.value

                let bundleId = await IPAParser.extractBundleId(fromPayloadFolder: extractedPayloadPath.path)
                let bundleVersion = await IPAParser.extractBundleVersion(fromPayloadFolder: extractedPayloadPath.path)
                let iconPath = await IPAParser.extractAppIcon(fromPayloadFolder: extractedPayloadPath.path) ?? ""
                let hasIcon = !iconPath.isEmpty && FileManager.default.fileExists(atPath: iconPath)
                
                if !hasIcon {
                    ToastManager.shared.showToast.warning("No app icon found, using default")
                }
                
                ToastManager.shared.showToast.silentWarning("Creating installation files...")
                ToastManager.shared.showToast.silentWarning("Bundle ID: \(bundleId)")
                ToastManager.shared.showToast.silentWarning("Bundle Version: \(bundleVersion)")
                ToastManager.shared.showToast.silentSuccess("Created installation manifest")
                
                self.visSigningPercent = 80
                
                let plistPath = try await installationManager.createPlistFile(
                    bundleId: bundleId,
                    bundleVersion: bundleVersion,
                    appName: finalAppName,
                    hasIcon: hasIcon
                )
                
                ToastManager.shared.showToast.silentWarning("Installation server stopped")
                try await installationManager.startServer()
                ToastManager.shared.showToast.silentSuccess("Installation server started")
                
                try installationManager.setupFileRoutes(
                    signedIPAPath: signedIPAPath.path,
                    iconPath: iconPath,
                    plistPath: plistPath
                )
                ToastManager.shared.showToast.silentSuccess("File routes configured")
                ToastManager.shared.showToast.silentWarning("Routes configured:")
                ToastManager.shared.showToast.silentWarning("IPA: http://127.0.0.1:8080/debugger.ipa")
                ToastManager.shared.showToast.silentWarning("Icon: http://127.0.0.1:8080/appIcon.png")
                ToastManager.shared.showToast.silentWarning("Plist: http://127.0.0.1:8080/install.plist")
                ToastManager.shared.showToast.silentSuccess("Signing process completed")
                
                if !skipInstallation {
                    if let url = URL(string: "itms-services://?action=download-manifest&url=https://loyah.dev/install") {
                        Task {
                            await UIApplication.shared.open(url)
                            ToastManager.shared.showToast.silentSuccess("Installation started successfully")
                            
                            Task {
                                try await Task.sleep(nanoseconds: 60_000_000_000)
                                await self.cleanupAfterInstallation()
                            }
                        }
                    }
                } else {
                    ToastManager.shared.showToast.silentWarning("Installation delayed - waiting for Circlefy processing")
                }
                
                timerManager.stopTimer()
                return true
            }
            
            timerManager.stopTimer()
            return false
            
        } catch {
            ToastManager.shared.showToast.error("Sideloading technical error: \(error)")
            ToastManager.shared.showToast.error("Sideloading error: \(error.localizedDescription)")
            timerManager.stopTimer()
            return false
        }
    }
    
    private func injectDefaultTweaks(into appFolderURL: URL) async {
        let defaultTweaks = DefaultTweakManager.shared.getDefaultTweaks()
        
        guard !defaultTweaks.isEmpty else {
            ToastManager.shared.showToast.silentWarning("No default tweaks to inject")
            return
        }
        
        ToastManager.shared.showToast.silentWarning("Injecting \(defaultTweaks.count) default tweak(s)...")
        
        guard let tweaksDirectory = DirectoryManager.shared.getURL(for: .importedTweaks) else {
            ToastManager.shared.showToast.error("Cannot access tweaks directory")
            return
        }
        
        let frameworksURL = appFolderURL.appendingPathComponent("Frameworks")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: frameworksURL.path) {
            do {
                try fileManager.createDirectory(at: frameworksURL, withIntermediateDirectories: true)
                ToastManager.shared.showToast.silentSuccess("Created Frameworks directory")
            } catch {
                ToastManager.shared.showToast.error("Failed to create Frameworks directory: \(error.localizedDescription)")
                return
            }
        }
        
        for tweakName in defaultTweaks {
            do {
                let contents = try fileManager.contentsOfDirectory(at: tweaksDirectory, includingPropertiesForKeys: nil)
                
                if let tweakFile = contents.first(where: { url in
                    let fileName = url.deletingPathExtension().lastPathComponent
                    return fileName == tweakName || fileName.hasSuffix("_\(tweakName)")
                }) {
                    let destinationURL = frameworksURL.appendingPathComponent(tweakFile.lastPathComponent)
                    
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    
                    try fileManager.copyItem(at: tweakFile, to: destinationURL)
                    
                    FixSubstrate(destinationURL.path)
                    
                    ToastManager.shared.showToast.silentSuccess("Injected default tweak: \(tweakName)")
                } else {
                    ToastManager.shared.showToast.warning("Default tweak not found: \(tweakName)")
                }
            } catch {
                ToastManager.shared.showToast.error("Failed to inject tweak \(tweakName): \(error.localizedDescription)")
            }
        }
        
        ToastManager.shared.showToast.silentSuccess("Default tweak injection completed")
    }

    private func handleCirclefySigningFailure() async {
        // Check if this might be a Circlefy-related failure
        let circlefyRelatedErrors = [
            "Can't Find CodeSignature Segment",
            "Failed to initialize signing asset",
            "App folder not found"
        ]
        
        // This is likely a Circlefy-related signing failure
        await MainActor.run {
            ToastManager.shared.showToast.error("Circlefy modification made the app unsignable")
            ToastManager.shared.showToast.warning("The ModifyExecutable function corrupted the app's code signature structure")
            ToastManager.shared.showToast.warning("Circlefy is currently incompatible with the signing process")
        }
    }

    func cleanupAfterInstallation() async {
        ToastManager.shared.showToast.silentWarning("Cleaning up installation files...")
        
        installationManager.stopServer()
        
        do {
            try await FileUtilities.clearTemporaryFiles(deleteCertificates: false)
            ToastManager.shared.showToast.silentSuccess("Installation files cleaned up")
        } catch {
            ToastManager.shared.showToast.error("Error cleaning up installation files: \(error.localizedDescription)")
        }
    }
    
    private func getDefaultCertificateFiles() -> (p12Path: String?, mpPath: String?, password: String?) {
        guard let defaultTeamName = DefaultCertificateManager.shared.getDefaultCertificate(),
              let certificatesURL = DirectoryManager.shared.getURL(for: .importedCertificates) else {
            return (nil, nil, nil)
        }
        
        let teamFolderURL = certificatesURL.appendingPathComponent(defaultTeamName)
        
        guard FileManager.default.fileExists(atPath: teamFolderURL.path) else {
            return (nil, nil, nil)
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: teamFolderURL, includingPropertiesForKeys: nil)
            
            let p12File = files.first { $0.pathExtension.lowercased() == "p12" }
            let mpFile = files.first { $0.pathExtension.lowercased() == "mobileprovision" }
            let passwordFile = files.first { $0.lastPathComponent == "password.txt" }
            
            var password: String?
            if let passwordFile = passwordFile {
                password = try String(contentsOf: passwordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return (p12File?.path, mpFile?.path, password)
            
        } catch {
            ToastManager.shared.showToast.error("Error reading default certificate folder: \(error.localizedDescription)")
            return (nil, nil, nil)
        }
    }
}