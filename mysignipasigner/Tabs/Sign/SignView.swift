//
//  SignView.swift
//  mysignipasigner
//
//  Created by gliddd4 eee
//

import Foundation
import SwiftUI
import UIKit
import ZIPFoundation
import Swifter
import UniformTypeIdentifiers
import MachO
import MetalKit
import BezelKit

struct SignView: SwiftUI.View {
    @ObservedObject var viewModel: SideloadingViewModel
    @ObservedObject var ipaManager: IPAManager
    @ObservedObject var pickerCoordinator: FilePickerCoordinator
    @EnvironmentObject var theme: Theme
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showingCertificateManager = false
    @State private var showingTweakManager = false
    @State private var circlefyEnabled: Bool = false
    @State private var selectedPlatform: Int32 = PLATFORM_VISIONOS
    @State private var isProcessingCirclefy: Bool = false
    @State private var circlefyProcessed: Bool = false
    @FocusState private var isAppNameFieldFocused: Bool
    @FocusState private var isBundleIdFieldFocused: Bool
    @FocusState private var isVersionFieldFocused: Bool
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                List {
                    mainSection
                    customizationSection
                    experimentalSection
                }
                .listStyle(InsetGroupedListStyle())
                .padding(.horizontal, 2)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 20)
            }

            NavigationManager.customNavigation(
                title: "Signer",
                trailingItems: [
                    NavigationItem(
                        icon: "person.text.rectangle",
                        name: "Certificate Manager",
                        action: {
                            HapticManager.shared.medium()
                            ToastManager.shared.showToast.log("Clicked Certificate Manager (toolbar) in Sign")
                            showingCertificateManager = true
                        }
                    ),
                    NavigationItem(
                        icon: "wrench.adjustable",
                        name: "Tweak Manager",
                        action: {
                            HapticManager.shared.medium()
                            ToastManager.shared.showToast.log("Clicked Tweak Manager (toolbar) in Sign")
                            showingTweakManager = true
                        }
                    )
                ]
            )
            .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 34)
        }
        .sheet(isPresented: $pickerCoordinator.isPresented) {
            UnifiedDocumentPicker(coordinator: pickerCoordinator)
                .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(isPresented: $showingCertificateManager) {
            CertificateManagerView()
        }
        .sheet(isPresented: $showingTweakManager) {
            TweakManagerView()
        }
        .onChange(of: pickerCoordinator.selectedFileURL) { newValue in
            if let url = newValue {
                handleIPASelection(url: url)
            }
        }
        .onChange(of: pickerCoordinator.selectedMPURL) { newValue in
            if let url = newValue {
                ToastManager.shared.showToast.silentWarning("Updating MP in IPAManager: \(url.lastPathComponent)")
                ipaManager.selectedMobileProvisionURL = url
                ipaManager.mobileProvisionImported = true
            }
        }
        .onChange(of: pickerCoordinator.selectedP12URL) { newValue in
            if let url = newValue {
                ToastManager.shared.showToast.silentWarning("Updating P12 in IPAManager: \(url.lastPathComponent)")
                ipaManager.selectedP12URL = url
                ipaManager.p12Imported = true
            }
        }
        .onChange(of: pickerCoordinator.selectedTweakURL) { newValue in
            if let url = newValue {
                ToastManager.shared.showToast.silentWarning("Updating Tweak in IPAManager: \(url.lastPathComponent)")
                ipaManager.selectedTweakURL = url
                ipaManager.tweakImported = true
            }
        }
        .onChange(of: ipaManager.fileImported) { newValue in
            if newValue {
                ToastManager.shared.showToast.success("IPA Selected")
            }
        }
        .alert("Enter IPA URL", isPresented: $ipaManager.showURLInputAlert) {
            TextField("URL", text: $ipaManager.customAppName)
            Button("OK") {
                if !ipaManager.customAppName.isEmpty {
                    Task {
                        await ipaManager.downloadFileAndSideload(from: ipaManager.customAppName)
                        ipaManager.fileImported = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                ipaManager.customAppName = ""
            }
        } message: {
            Text("If the IPA doesn't automatically download when you open the URL in your browser, this won't work")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleIPASelection(url: URL) {
        Task {
            let copiedURL = await IPAOperations.shared.copyIPAToAppContainer(url: url)
            
            guard let finalURL = copiedURL else {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Failed to process selected IPA.")
                }
                return
            }
            
            await MainActor.run {
                ipaManager.selectedFileURL = finalURL
                ipaManager.fileImported = true
                ipaManager.customApp = false
            }

            do {
                let (appName, bundleID, version) = try await IPAOperations.shared.parseIPAInfo(url: finalURL)
                
                await MainActor.run {
                    ipaManager.appNameInput = appName
                    
                    if !bundleID.isEmpty {
                        ipaManager.bundleidInput = bundleID
                    }
                    
                    if !version.isEmpty {
                        ipaManager.appVersionInput = version
                    }
                }
                
            } catch {
                await MainActor.run {
                    ToastManager.shared.showToast.error("Error extracting app info: \(error.localizedDescription)")
                    if ipaManager.appNameInput.isEmpty {
                        ipaManager.appNameInput = url.deletingPathExtension().lastPathComponent
                    }
                }
            }
        }
    }
    
    private func handleSideloadButtonTap() {
        guard !isProcessingCirclefy else {
            ToastManager.shared.showToast.warning("Circlefy processing in progress, please wait...")
            return
        }
        
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Sideload button tapped, starting installation.")
        Task {
            await performSideload()
        }
    }
    
    private func performSideload() async {
        do {
            guard let ipaURL = ipaManager.selectedFileURL else {
                throw NSError(domain: "SigningError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No IPA selected"])
            }
            
            var finalIpaURL = ipaURL
            
            // Apply Circlefy BEFORE signing (not after)
            if circlefyEnabled && !circlefyProcessed {
                await MainActor.run {
                    isProcessingCirclefy = true
                }
                
                do {
                    ToastManager.shared.showToast.success("Applying Circlefy to original IPA...")
                    let modifiedIpaURL = try await applyCirclefyToOriginalIPA(ipaURL)
                    finalIpaURL = modifiedIpaURL
                    
                    await MainActor.run {
                        circlefyProcessed = true
                        isProcessingCirclefy = false
                    }
                    
                    ToastManager.shared.showToast.success("Circlefy applied successfully! Now signing modified IPA...")
                    
                } catch {
                    await MainActor.run {
                        isProcessingCirclefy = false
                        ToastManager.shared.showToast.error("Circlefy failed: \(error.localizedDescription)")
                        ToastManager.shared.showToast.warning("Proceeding with original IPA...")
                    }
                    // Continue with original IPA if Circlefy fails
                }
            }
            
            // Now sign the final IPA (either original or Circlefy-modified)
            ToastManager.shared.showToast.success("Starting signing process...")
            let success = await ipaManager.sideload(ipaPath: finalIpaURL, skipInstallation: false)
            
            guard success else {
                throw NSError(domain: "SigningError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Signing failed"])
            }
            
            // Reset Circlefy state after completion
            await MainActor.run {
                circlefyProcessed = false
            }
            
        } catch {
            await MainActor.run {
                isProcessingCirclefy = false
                circlefyProcessed = false
            }
            ToastManager.shared.showToast.error(error.localizedDescription)
        }
    }
    
    private func applyCirclefyToOriginalIPA(_ originalIpaURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let modifiedIpaPath = try CirclefyOperations.shared.modifyIPA(originalIpaURL.path, self.selectedPlatform)
                    let modifiedURL = URL(fileURLWithPath: modifiedIpaPath)
                    continuation.resume(returning: modifiedURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var ipaSelectionView: some View {
        Button(action: {
            HapticManager.shared.medium()
            ToastManager.shared.showToast.silentWarning("Tapped Select IPA button")
            pickerCoordinator.presentPicker(type: .ipa)
        }) {
            HStack {
                Image("selectipa")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Select IPA")
                        .foregroundColor(.white)
                    
                    if let selectedFileURL = ipaManager.selectedFileURL {
                        Text(selectedFileURL.lastPathComponent)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No file selected")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                
                if ipaManager.fileImported {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                HapticManager.shared.medium()
                ipaManager.showURLInputAlert = true
            }) {
                HStack {
                    Text("Direct Download")
                    Image(systemName: "arrow.down.circle")
                }
            }
        }
    }
    
    private var signButton: some View {
        Button(action: handleSideloadButtonTap) {
            HStack {
                if isProcessingCirclefy {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "signature")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(getSignButtonText())
                    .font(.headline.weight(.medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !isProcessingCirclefy {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .contentShape(Rectangle())
        .disabled(isProcessingCirclefy)
    }
    
    private func getSignButtonText() -> String {
        if isProcessingCirclefy {
            return "Applying Circlefy..."
        } else if circlefyEnabled {
            return "Sign & Apply Circlefy"
        } else {
            return "Sign & Install"
        }
    }
    
    private var mainSection: some View {
        Section(header: Text("MAIN").secondaryHeader()) {
            ipaSelectionView
            
            if ipaManager.fileImported {
                signButton
            }
        }
    }
    
    private var customizationSection: some View {
        Section(header: Text("CUSTOMIZATION").secondaryHeader()) {
            AppCustomizationView(ipaManager: ipaManager)
        }
    }
    
    private var experimentalSection: some View {
        Section(header: Text("EXPERIMENTAL").secondaryHeader()) {
            circlefyToggleView
        }
    }

    private var circlefyToggleView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Enable Circlefy")
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $circlefyEnabled)
            }
            .onChange(of: circlefyEnabled) { newValue in
                HapticManager.shared.medium()
                ToastManager.shared.showToast.silentWarning("Circlefy \(newValue ? "enabled" : "disabled")")
            }
            
            if circlefyEnabled {
                Divider()
                
                VStack(spacing: 0) {
                    Picker("Icon Mask", selection: $selectedPlatform) {
                        Text("Circle Mask").tag(PLATFORM_VISIONOS)
                        Text("No Mask").tag(PLATFORM_MACOS)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .onChange(of: selectedPlatform) { newValue in
                    HapticManager.shared.medium()
                    let maskType = newValue == PLATFORM_VISIONOS ? "Circle" : "No Mask"
                    ToastManager.shared.showToast.silentWarning("Selected \(maskType) mask")
                }
            }
        }
    }
}

struct AppCustomizationView: View {
    @ObservedObject var ipaManager: IPAManager
    
    var body: some View {
        Group {
            HStack {
                Image("appname")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                    .foregroundColor(.white)
                TextField("App Name", text: $ipaManager.appNameInput)
            }
            
            HStack {
                Image("appbundleid")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                    .foregroundColor(.white)
                TextField("Bundle Identifier", text: $ipaManager.bundleidInput)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            HStack {
                Image("appversion")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .cornerRadius(6)
                    .foregroundColor(.white)
                TextField("App Version", text: $ipaManager.appVersionInput)
            }
        }
    }
}
