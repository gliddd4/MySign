//
//  SideloadingViewModel.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

var totalTweaks = 0
var currentSignedTweaks = 0
var globalSideloadingPercentage = 0
var progress = 0
var deviceModel = ""
var globalSideloadingStatus: SideloadingViewModel?

@MainActor
class SideloadingViewModel: ObservableObject {
    @Published var sideloadingPercentage = 0

    var totalTweaks: Int = 0
    var currentSignedTweaks: Int = 0 {
        didSet {
            if currentSignedTweaks != 0 && totalTweaks != 0 {
                progress = Int((Double(currentSignedTweaks) / Double(totalTweaks)) * 70 + 15)
            }
            ToastManager.shared.showToast.warning("Progress: \(progress)%")
            sideloadingPercentage = Int(progress)
            globalSideloadingPercentage = sideloadingPercentage
        }
    }

    func incrementSignedTweaks() {
        currentSignedTweaks += 1
    }

    func resetSignedTweaks() {
        currentSignedTweaks = 0
    }
}
