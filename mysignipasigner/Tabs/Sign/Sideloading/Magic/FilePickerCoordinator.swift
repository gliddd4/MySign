//
//  FilePickerCoordinator.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
class FilePickerCoordinator: ObservableObject {
    @Published var isPresented = false
    @Published var fileImported = false
    @Published var selectedFileURL: URL?
    @Published var customApp = false
    @Published var selectedMPURL: URL?
    @Published var selectedP12URL: URL?
    @Published var selectedTweakURL: URL?
    @Published var mobileProvisionImported = false
    @Published var p12Imported = false
    @Published var tweakImported = false
    @Published var currentPickerType: PickerType = .ipa
    
    // Certificate pair selection state
    @Published var certificatePairImported = false
    @Published var selectedCertificatePairP12URL: URL?
    @Published var selectedCertificatePairMPURL: URL?
    @Published var certificatePairSelectionStep: CertificatePairStep = .p12
    
    // Individual certificate file import state
    @Published var individualP12Imported = false
    @Published var individualMPImported = false
    @Published var selectedIndividualP12URL: URL?
    @Published var selectedIndividualMPURL: URL?
    
    // .esigncert file import state
    @Published var esigncertImported = false
    @Published var selectedEsigncertURL: URL?
    
    // Certificate pair selection steps
    enum CertificatePairStep {
        case p12
        case mobileprovision
    }
    
    enum PickerType {
        case ipa
        case mobileprovision
        case p12
        case tweak
        case certificatePairP12
        case certificatePairMobileProv
        case certificatePairMultiple
        case individualP12
        case individualMobileProv
        case esigncert
        case image
        
        var contentTypes: [UTType] {
            switch self {
            case .ipa:
                return [
                    UTType(filenameExtension: "ipa")!,
                    UTType(tag: "app", tagClass: .filenameExtension, conformingTo: nil)!,
                    UTType.applicationBundle
                ]
            case .mobileprovision, .certificatePairMobileProv, .individualMobileProv:
                return [UTType(filenameExtension: "mobileprovision") ?? .data]
            case .p12, .certificatePairP12, .individualP12:
                return [UTType(filenameExtension: "p12") ?? .x509Certificate]
            case .esigncert:
                return [UTType(filenameExtension: "esigncert") ?? .data]
            case .tweak:
                return [UTType(filenameExtension: "dylib") ?? .data,
                       UTType(filenameExtension: "deb") ?? .data]
            case .certificatePairMultiple:
                return [
                    UTType(filenameExtension: "p12") ?? .x509Certificate,
                    UTType(filenameExtension: "mobileprovision") ?? .data
                ]
            case .image:
                return [.image]
            }
        }
        
        var allowsMultipleSelection: Bool {
            switch self {
            case .certificatePairMultiple, .tweak:
                return true
            default:
                return false
            }
        }
    }
    
    func presentPicker(type: PickerType) {
        currentPickerType = type
        isPresented = true
    }
    
    func startIndividualP12Import() {
        selectedIndividualP12URL = nil
        individualP12Imported = false
        presentPicker(type: .individualP12)
    }
    
    func startIndividualMPImport() {
        selectedIndividualMPURL = nil
        individualMPImported = false
        presentPicker(type: .individualMobileProv)
    }
    
    func startEsigncertImport() {
        selectedEsigncertURL = nil
        esigncertImported = false
        presentPicker(type: .esigncert)
    }
    
    func startCertificatePairImport() {
        selectedCertificatePairP12URL = nil
        selectedCertificatePairMPURL = nil
        certificatePairImported = false
        ToastManager.shared.showToast.warning("Select both P12 and Mobile Provision files")
        presentPicker(type: .certificatePairMultiple)
    }
    
    func handleCertificatePairMultipleSelection(urls: [URL]) {
        var p12URL: URL?
        var mpURL: URL?
        
        for url in urls {
            let pathExtension = url.pathExtension.lowercased()
            switch pathExtension {
            case "p12":
                p12URL = url
            case "mobileprovision":
                mpURL = url
            default:
                ToastManager.shared.showToast.warning("Ignoring unsupported file: \(url.lastPathComponent)")
            }
        }
        
        if let p12 = p12URL, let mp = mpURL {
            selectedCertificatePairP12URL = p12
            selectedCertificatePairMPURL = mp
            certificatePairImported = true
            ToastManager.shared.showToast.success("Certificate pair selected: \(p12.lastPathComponent) + \(mp.lastPathComponent)")
        } else if p12URL != nil && mpURL == nil {
            ToastManager.shared.showToast.error("Missing Mobile Provision file. Please select both P12 and .mobileprovision files.")
        } else if p12URL == nil && mpURL != nil {
            ToastManager.shared.showToast.error("Missing P12 file. Please select both P12 and .mobileprovision files.")
        } else {
            ToastManager.shared.showToast.error("No valid certificate files selected. Please select both P12 and .mobileprovision files.")
        }
    }
    
    func handleCertificatePairSelection(url: URL, type: PickerType) {
        switch type {
        case .certificatePairP12:
            selectedCertificatePairP12URL = url
            certificatePairSelectionStep = .mobileprovision
            ToastManager.shared.showToast.success("P12 selected: \(url.lastPathComponent)")
            ToastManager.shared.showToast.warning("Step 2: Select Mobile Provision file")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.presentPicker(type: .certificatePairMobileProv)
            }
            
        case .certificatePairMobileProv:
            selectedCertificatePairMPURL = url
            ToastManager.shared.showToast.success("Mobile Provision selected: \(url.lastPathComponent)")
            if selectedCertificatePairP12URL != nil && selectedCertificatePairMPURL != nil {
                certificatePairImported = true
                ToastManager.shared.showToast.success("Certificate pair ready for import")
            }
            
        default:
            break
        }
    }
    
    func handleMultipleTweakSelection(urls: [URL]) {
        // This will be handled by the TweakManagerView through TweakOperations
        selectedTweakURL = urls.first // Keep compatibility with existing single-tweak selection
        tweakImported = !urls.isEmpty
        
        if urls.count == 1 {
            ToastManager.shared.showToast.success("Selected tweak: \(urls.first!.lastPathComponent)")
        } else {
            ToastManager.shared.showToast.success("Selected \(urls.count) tweaks")
        }
    }
    
    func getDestinationFolder(for type: PickerType) -> URL? {
        switch type {
        case .ipa:
            return DirectoryManager.shared.getURL(for: .importedIPAs)
        case .mobileprovision, .p12, .certificatePairP12, .certificatePairMobileProv, .certificatePairMultiple, .individualP12, .individualMobileProv, .esigncert:
            return DirectoryManager.shared.getURL(for: .importedCertificates)
        case .tweak:
            return DirectoryManager.shared.getURL(for: .importedTweaks)
        case .image:
            return DirectoryManager.shared.getURL(for: .wallpapers)
        }
    }
}