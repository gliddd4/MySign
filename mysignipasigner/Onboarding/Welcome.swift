//
//  Welcome.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import WelcomeSheet

struct WelcomePopover: View {
    @EnvironmentObject private var installChecker: NewInstall
    @EnvironmentObject private var theme: Theme
    @State private var showSheet = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                DispatchQueue.main.async {
                    checkInstallState(state: installChecker.currentState)
                }
            }
            .onChange(of: installChecker.currentState) { newState in
                checkInstallState(state: newState)
            }
            .welcomeSheet(isPresented: $showSheet,
                          onDismiss: { sheetDismissed() },
                          isSlideToDismissDisabled: true,
                          pages: getPages())
            .preferredColorScheme(.dark)
    }

    private func checkInstallState(state: AppInstallState) {
        if state == .newInstall || state == .reinstall || state == .update {
            showSheet = true
        }
    }

    func sheetDismissed() {
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Clicked Continue in Onboarding")
    }
    
    private func handleSupportButtonTap() {
        HapticManager.shared.medium()
        ToastManager.shared.showToast.log("Clicked Support in Onboarding")
        
        // Open the support URL
        if let url = URL(string: "https://discord.gg/hUK5m9MGFc") {
            UIApplication.shared.open(url)
        }
    }
    
    func getPages() -> [WelcomeSheetPage] {
        [
            WelcomeSheetPage(
                title: "Welcome to WhySign",
                rows: [
                    WelcomeSheetPageRow(
                        imageSystemName: "paintbrush.fill",
                        accentColor: theme.accentColor,
                        title: "Customization",
                        content: "Toggle WhySign's core features easily and customize appearance to your liking."
                    ),
                    WelcomeSheetPageRow(
                        imageSystemName: "hare.fill",
                        accentColor: theme.accentColor,
                        title: "Unique Design",
                        content: "WhySign was designed to be the iOS 26 before iOS 26. Enjoy satisfying progressive blurs, glassy backgrounds, and haptic feedback."
                    ),
                    WelcomeSheetPageRow(
                        imageSystemName: "exclamationmark.triangle.fill",
                        accentColor: theme.accentColor,
                        title: "Warning",
                        content: "You are using the 2.0 beta 1 ipa. Report any bugs in the support server."
                    )
                ],
                accentColor: theme.accentColor,
                optionalButtonTitle: "Support",
                optionalButtonAction: { handleSupportButtonTap() }
            )
        ]
    }
}
