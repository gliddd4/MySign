//
//  CirclefyManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation
import UIKit

// Forward declaration to help Swift find the function
@_silgen_name("ModifyExecutable")
func ModifyExecutable(_ executablePath: NSString, _ platform: UInt32)

@MainActor
class CirclefyManager {
    static let shared = CirclefyManager()
    
    private init() {}
    
    func modifyExecutable(at path: String, with platform: UInt32) {
        // Call the actual ModifyExecutable function from the C library
        ModifyExecutable(path as NSString, platform)
        ToastManager.shared.showToast.success("ModifyExecutable called successfully")
    }
    
    func isModifyExecutableAvailable() -> Bool {
        // The function is available since it's declared in the bridging header
        return true
    }
}
