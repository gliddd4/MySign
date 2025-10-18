//
//  Actions.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Foundation

func swiftLogCallback(message: UnsafePointer<CChar>?) {
    guard let messageCStr = message else {
        Task { @MainActor in
            ToastManager.shared.showToast.silentWarning("Received a callback with a nil message.")
        }
        return
    }
    let messageStr = String(cString: messageCStr)
    Task { @MainActor in
        let baseMessage = "⏳ Received tweak signing callback: \(messageStr)"
        ToastManager.shared.showToast.silentWarning(baseMessage)

        globalSideloadingStatus?.incrementSignedTweaks()
    }
}

extension SignView {
    func handleLocalIPASideload() async {
        ToastManager.shared.showToast.silentWarning("handleLocalIPASideload called.")
        guard let fileURL = ipaManager.selectedFileURL else {
            ToastManager.shared.showToast.error("Error: No file selected.")
            return
        }

        ToastManager.shared.showToast.silentWarning("Using local file URL: \(fileURL.path)")
        ToastManager.shared.showToast.silentWarning("File exists at URL: \(FileManager.default.fileExists(atPath: fileURL.path))")

        let fileManager = FileManager.default

        do {
            guard fileManager.fileExists(atPath: fileURL.path),
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                throw NSError(domain: "SignIt", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot access the IPA file or file is empty"
                ])
            }

            ToastManager.shared.showToast.silentWarning("File size: \(fileSize) bytes")
            ToastManager.shared.showToast.silentWarning("Starting sideload process with file")
            await resetSideloadingState()
            await startSideloading(fileURL: fileURL)

        } catch {
            ToastManager.shared.showToast.error("Error during file handling: \(error.localizedDescription)")
            await MainActor.run {
                ToastManager.shared.showToast.error("Sideloading Error: \(error.localizedDescription)")
            }
        }
    }

    private func startSideloading(fileURL: URL) async {
        ToastManager.shared.showToast.silentWarning("startSideloading called with URL: \(fileURL.path)")

        let success = await ipaManager.sideload(ipaPath: fileURL)

        if success {
            await MainActor.run {
                ipaManager.selectedFileURL = nil
                ToastManager.shared.showToast.success("Sideloading Complete: Your app has been signed successfully.")
            }
        } else {
            ToastManager.shared.showToast.error("Sideloading failed")
            await MainActor.run {
                ToastManager.shared.showToast.error("Sideloading Failed: There was an error signing your app. Please try again.")
            }
        }
    }

    private func resetSideloadingState() async {
        await MainActor.run {
            Task { @MainActor in
                ipaManager.timerManager.resetTimers()
            }
            ipaManager.visSigningPercent = 0
            viewModel.resetSignedTweaks()
            viewModel.totalTweaks = 1
            viewModel.sideloadingPercentage = 0
            progress = 0
            ToastManager.shared.showToast.silentSuccess("Sideloading state reset complete.")
        }
    }

    func presentIPAPicker() {
        pickerCoordinator.presentPicker(type: .ipa)
    }

    func presentMobileProvisionPicker() {
        pickerCoordinator.presentPicker(type: .mobileprovision)
    }

    func presentP12Picker() {
        pickerCoordinator.presentPicker(type: .p12)
    }

    func presentTweakPicker() {
        pickerCoordinator.presentPicker(type: .tweak)
    }

    func fetchAndCompareText(from urlString: String, with localString: String) {
        guard let url = URL(string: urlString) else {
            Task { @MainActor in
                ToastManager.shared.showToast.error("Invalid URL: \(urlString)")
            }
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            Task { @MainActor in
                if let error = error {
                    ToastManager.shared.showToast.error("Error fetching data: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    ToastManager.shared.showToast.error("Invalid HTTP response. Status Code: \(statusCode)")
                    return
                }

                guard let data = data, let onlineString = String(data: data, encoding: .utf8) else {
                    ToastManager.shared.showToast.error("Could not decode data.")
                    return
                }

                if onlineString != localString {
                    ToastManager.shared.showToast.warning("Update Available: Please download the latest version.")
                } else {
                    ToastManager.shared.showToast.success("App version is up-to-date.")
                }
            }
        }
        task.resume()
    }
}