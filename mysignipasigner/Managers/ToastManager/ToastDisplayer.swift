//
//  ToastDisplayer.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ToastDisplayer {
    let manager: ToastManager

    @MainActor
    func success(_ message: String, position: ToastPosition = .default) {
        manager.showToast(message, type: .success, position: position)
    }

    @MainActor
    func error(_ message: String, position: ToastPosition = .default) {
        manager.showToast(message, type: .error, position: position)
    }

    @MainActor
    func warning(_ message: String, position: ToastPosition = .default) {
        manager.showToast(message, type: .warning, position: position)
    }

    @MainActor
    func lowered(_ message: String, isError: Bool = false) {
        manager.showToast(message, type: isError ? .error : .success, position: .lowered)
    }

    @MainActor
    func silentSuccess(_ message: String) {
        manager.logOnly(message, type: .success)
    }

    @MainActor
    func silentError(_ message: String) {
        manager.logOnly(message, type: .error)
    }

    @MainActor
    func silentWarning(_ message: String) {
        manager.logOnly(message, type: .warning)
    }

    @MainActor
    func log(_ message: String) {
        manager.addLog(message)
    }
}
