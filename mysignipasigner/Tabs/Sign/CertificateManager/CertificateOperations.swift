//
//  CertificateOperations.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import UIKit

class CertificateOperations {
    static let shared = CertificateOperations()
    
    private init() {}
    
    // MARK: - Certificate Loading
    func loadCertificates() async -> [CertificateFolder] {
        return await MainActor.run {
            do {
                guard let certificatesPath = DirectoryManager.shared.getURL(for: .importedCertificates) else {
                    return []
                }
                
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: certificatesPath, includingPropertiesForKeys: [.isDirectoryKey])
                
                let folders = contents.filter { url in
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                        return resourceValues.isDirectory == true
                    } catch {
                        return false
                    }
                }
                
                let certificates = folders.map { folderURL in
                    CertificateFolder(teamName: folderURL.lastPathComponent, folderURL: folderURL)
                }.sorted { $0.teamName < $1.teamName }
                
                return certificates
                
            } catch {
                ToastManager.shared.showToast.error("Error scanning certificates: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    // MARK: - Certificate Deletion
    func deleteCertificate(_ certificate: CertificateFolder) async -> Bool {
        do {
            try FileManager.default.removeItem(at: certificate.folderURL)
            
            await MainActor.run {
                HapticManager.shared.medium()
                ToastManager.shared.showToast.success("Certificate '\(certificate.teamName)' deleted")
            }
            return true
        } catch {
            await MainActor.run {
                ToastManager.shared.showToast.error("Error deleting certificate: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Certificate Sharing
    @MainActor
    func shareCertificate(_ certificate: CertificateFolder) {
        // Show immediate feedback
        HapticManager.shared.medium()
        
        // Check if .esigncert file exists
        guard let esigncertURL = certificate.esigncertURL,
              FileManager.default.fileExists(atPath: esigncertURL.path) else {
            ToastManager.shared.showToast.error("Certificate package not found. Try reimporting the certificate.")
            return
        }
        
        ToastManager.shared.showToast.success("Sharing certificate package")
        
        // Add delay to ensure proper presentation timing and avoid conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                ToastManager.shared.showToast.error("Cannot access root view controller")
                return
            }
            
            // Dismiss any existing presentations first
            if rootVC.presentedViewController != nil {
                rootVC.dismiss(animated: false) {
                    self.presentShareSheet(with: esigncertURL, from: rootVC)
                }
            } else {
                self.presentShareSheet(with: esigncertURL, from: rootVC)
            }
        }
    }
    
    // MARK: - Certificate Import
    @MainActor
    func handlePasswordInput(
        password: String,
        p12URL: URL,
        mpURL: URL,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping () -> Void
    ) {
        if password.isEmpty {
            ToastManager.shared.showToast.error("Please enter a password")
            onFailure()
            return
        }
        
        Task {
             let result = CertificateManager.shared.validateP12Password(p12URL: p12URL, password: password)
            
            await MainActor.run {
                switch result {
                case .success(let teamName):
                    ToastManager.shared.showToast.success("Certificate password validated")
                    Task {
                        let folderCreated = await CertificateManager.shared.createCertificateFolder(mpURL: mpURL, p12URL: p12URL)
                        await MainActor.run {
                            if folderCreated {
                                ToastManager.shared.showToast.success("Certificate imported successfully")
                                onSuccess(teamName)
                            } else {
                                onFailure()
                            }
                        }
                    }
                case .failure:
                    ToastManager.shared.showToast.error("Invalid password entered")
                    onFailure()
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    private func presentShareSheet(with fileURL: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
}
