//
//  ToastPosition.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit
import ObjectiveC

@MainActor
enum ToastPosition {
    case `default`
    case lowered
    
    var bottomOffset: CGFloat {
        return UIConfig.loweredBottomOffset
    }
}

extension UIView {
    private struct AssociatedKeys {
        static let bottomConstraintKey = UnsafeRawPointer(bitPattern: "toastBottomConstraintKey".hashValue)!
        static let positionKey = UnsafeRawPointer(bitPattern: "toastPositionKey".hashValue)!
    }

    var toastBottomConstraint: NSLayoutConstraint? {
        get {
            return objc_getAssociatedObject(self, AssociatedKeys.bottomConstraintKey) as? NSLayoutConstraint
        }
        set {
            objc_setAssociatedObject(self, AssociatedKeys.bottomConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var toastPosition: ToastPosition? {
        get {
            return objc_getAssociatedObject(self, AssociatedKeys.positionKey) as? ToastPosition
        }
        set {
            objc_setAssociatedObject(self, AssociatedKeys.positionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}