//
//  ToastManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import UIKit
import BlurView
import Combine

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published private(set) var logs: [String] = []
    let maxLogs = 1000

    private var toasts: [ToastItem] = []

    private init() {
    }

    var showToast: ToastDisplayer {
        ToastDisplayer(manager: self)
    }

    private func updateToastPositions() {
        guard !toasts.isEmpty else { return }

        let defaultToasts = toasts.filter { $0.position == .default }
        let loweredToasts = toasts.filter { $0.position == .lowered }

        updateToastGroup(defaultToasts)
        updateToastGroup(loweredToasts)
    }

    private func updateToastGroup(_ toasts: [ToastItem]) {
        guard !toasts.isEmpty else { return }

        var currentOffset: CGFloat = 0

        for toast in toasts.reversed() {
            let containerView = toast.containerView

            let bottomOffset = toast.position.bottomOffset

            let containerHeight = containerView.systemLayoutSizeFitting(
                CGSize(width: containerView.frame.width,
                      height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height

            if let window = containerView.window,
               let constraint = containerView.toastBottomConstraint {
                UIView.animate(withDuration: 0.3) {
                    containerView.transform = .identity
                    constraint.constant = bottomOffset - currentOffset
                    window.layoutIfNeeded()
                }
            }

            currentOffset += containerHeight + AnimationConfig.toastSpacing
        }
    }

    func showToast(_ message: String, type: ToastType = .success, position: ToastPosition = .default) {
        let customDuration: TimeInterval = 3.5
        let tabName = TabSelectionManager.shared.selectedTabName

        let statusIcon: String
        switch type {
        case .success:
            statusIcon = "✅"
        case .error:
            statusIcon = "❌"
        case .warning:
            statusIcon = "⚠️"
        }

        let logMessage = "[\(tabName)] \(statusIcon) \(message)"

        #if DEBUG
        print(logMessage)
        #endif

        logs.append(logMessage)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            let label = UILabel()
            label.font = .systemFont(ofSize: UIConfig.fontSize, weight: .medium)
            label.text = message

            //-------------------------------------------------------------
            // Determine if the toast is single-line or multi-line so we
            // can apply the toast-specific dynamic corner radius.
            //-------------------------------------------------------------
            let maxWidth = window.bounds.width * UIConfig.maxWidthMultiplier
                         - (UIConfig.horizontalPadding * 2
                         +  UIConfig.iconSize
                         +  UIConfig.iconSpacing)
            let size         = label.sizeThatFits(
                                CGSize(width: maxWidth,
                                       height: .infinity))
            let isSingleLine = size.height <= (UIConfig.fontSize * 1.5)
            let cornerRadius = isSingleLine
                             ? UIConfig.compactCornerRadius
                             : UIConfig.standardCornerRadius

            let containerView = UIView()
            containerView.backgroundColor = .clear

            // Create dock-style background using SwiftUI approach
            let backgroundStack = UIView()
            
            // Layer 1: Black tint (matches dock exactly)
            let blackTintView = UIView()
            blackTintView.backgroundColor = UIColor.black.withAlphaComponent(0.05)
            blackTintView.layer.cornerRadius = cornerRadius
            blackTintView.clipsToBounds = true
            
            // Layer 2: Ultra thin material (matches dock exactly)
            let mainBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            mainBlurView.alpha = 0.3
            mainBlurView.layer.cornerRadius = cornerRadius
            mainBlurView.clipsToBounds = true
            
            // Add layers to background stack
            backgroundStack.addSubview(blackTintView)
            backgroundStack.addSubview(mainBlurView)
            
            blackTintView.translatesAutoresizingMaskIntoConstraints = false
            mainBlurView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                blackTintView.topAnchor.constraint(equalTo: backgroundStack.topAnchor),
                blackTintView.leadingAnchor.constraint(equalTo: backgroundStack.leadingAnchor),
                blackTintView.trailingAnchor.constraint(equalTo: backgroundStack.trailingAnchor),
                blackTintView.bottomAnchor.constraint(equalTo: backgroundStack.bottomAnchor),
                mainBlurView.topAnchor.constraint(equalTo: backgroundStack.topAnchor),
                mainBlurView.leadingAnchor.constraint(equalTo: backgroundStack.leadingAnchor),
                mainBlurView.trailingAnchor.constraint(equalTo: backgroundStack.trailingAnchor),
                mainBlurView.bottomAnchor.constraint(equalTo: backgroundStack.bottomAnchor)
            ])
            
            // Add border using SwiftUI-style approach (matches dock exactly)
            let borderLayer = CAShapeLayer()
            borderLayer.path = UIBezierPath(roundedRect: CGRect.zero, cornerRadius: cornerRadius).cgPath
            borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.1).cgColor
            borderLayer.fillColor = UIColor.clear.cgColor
            borderLayer.lineWidth = 0.5
            backgroundStack.layer.addSublayer(borderLayer)
            
            // Add shadow (matches dock exactly)
            backgroundStack.layer.shadowColor = UIColor.black.cgColor
            backgroundStack.layer.shadowOpacity = 0.25
            backgroundStack.layer.shadowRadius = 20
            backgroundStack.layer.shadowOffset = CGSize(width: 0, height: 10)

            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = UIConfig.iconSpacing

            let iconView: UIView
            let textColor: UIColor
            switch type {
            case .success:
                let iconImageView = UIImageView()
                iconImageView.image = UIImage(systemName: "checkmark.circle")
                iconImageView.tintColor = .white
                iconImageView.contentMode = .scaleAspectFit
                iconView = iconImageView
                textColor = .white
            case .error:
                let iconImageView = UIImageView()
                iconImageView.image = UIImage(systemName: "exclamationmark.circle")
                iconImageView.tintColor = .white
                iconImageView.contentMode = .scaleAspectFit
                iconView = iconImageView
                textColor = .white
            case .warning:
                let iconImageView = UIImageView()
                iconImageView.image = UIImage(systemName: "exclamationmark.circle")
                iconImageView.tintColor = .white
                iconImageView.contentMode = .scaleAspectFit
                iconView = iconImageView
                textColor = .white
            }
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: UIConfig.iconSize),
                iconView.heightAnchor.constraint(equalToConstant: UIConfig.iconSize)
            ])
            stackView.addArrangedSubview(iconView)

            label.textColor = textColor
            label.textAlignment = .left
            label.numberOfLines = 0
            stackView.addArrangedSubview(label)

            containerView.addSubview(backgroundStack)
            //  Place content *above* the blur so colour stays 100 % opaque white,
            //  mirroring the dock's SwiftUI implementation.
            backgroundStack.addSubview(stackView)
            backgroundStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                backgroundStack.topAnchor.constraint(equalTo: containerView.topAnchor),
                backgroundStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                backgroundStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                backgroundStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            stackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: backgroundStack.topAnchor, constant: UIConfig.verticalPadding),
                stackView.bottomAnchor.constraint(equalTo: backgroundStack.bottomAnchor, constant: -UIConfig.verticalPadding),
                stackView.leadingAnchor.constraint(equalTo: backgroundStack.leadingAnchor, constant: UIConfig.horizontalPadding),
                stackView.trailingAnchor.constraint(equalTo: backgroundStack.trailingAnchor, constant: -UIConfig.horizontalPadding)
            ])

            window.addSubview(containerView)
            containerView.translatesAutoresizingMaskIntoConstraints = false
            let bottomConstraint = containerView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: position.bottomOffset)
            containerView.toastBottomConstraint = bottomConstraint
            containerView.toastPosition = position
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                bottomConstraint,
                containerView.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, multiplier: UIConfig.maxWidthMultiplier),
                containerView.heightAnchor.constraint(lessThanOrEqualToConstant: UIConfig.maxHeight),
                containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: UIConfig.minHeight),
                containerView.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 16),
                containerView.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -16)
            ])

            // Update border frame when container is laid out
            containerView.layoutIfNeeded()
            borderLayer.path = UIBezierPath(roundedRect: backgroundStack.bounds, cornerRadius: cornerRadius).cgPath

            containerView.alpha = 0
            containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            window.layoutIfNeeded()

            UIView.animate(withDuration: AnimationConfig.animationDuration,
                         delay: 0,
                         usingSpringWithDamping: 0.7,
                         initialSpringVelocity: 0.3,
                         options: [.allowUserInteraction],
                         animations: {
                containerView.transform = .identity
                containerView.alpha = 1
                mainBlurView.alpha = 0.3
            })

            containerView.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleToastTap(_:)))
            containerView.addGestureRecognizer(tapGesture)

            let timer = Timer.scheduledTimer(withTimeInterval: customDuration,
                                          repeats: false) { [weak self] timer in
                Task { @MainActor in
                    self?.dismissToast(containerView: containerView, timer: timer, isAutomatic: true)
                }
            }

            let toastItem = ToastItem(containerView: containerView, position: position, timer: timer)
            self.toasts.append(toastItem)

            self.updateToastPositions()
        }
    }
    
    // Extended duration toast for important success messages
    func showExtendedToast(_ message: String, type: ToastType = .success, position: ToastPosition = .default, duration: TimeInterval = 8.0) {

        let tabName = TabSelectionManager.shared.selectedTabName

        let statusIcon: String
        switch type {
        case .success:
            statusIcon = "✅"
        case .error:
            statusIcon = "❌"
        case .warning:
            statusIcon = "⚠️"
        }

        let logMessage = "[\(tabName)] \(statusIcon) \(message) (Extended Duration: \(duration)s)"

        #if DEBUG
        print(logMessage)
        #endif

        logs.append(logMessage)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            let label = UILabel()
            label.font = .systemFont(ofSize: UIConfig.fontSize, weight: .medium)
            label.text = message

            let maxWidth = window.bounds.width * UIConfig.maxWidthMultiplier
                         - (UIConfig.horizontalPadding * 2
                         +  UIConfig.iconSize
                         +  UIConfig.iconSpacing)
            let size         = label.sizeThatFits(
                                CGSize(width: maxWidth,
                                       height: .infinity))
            let isSingleLine = size.height <= (UIConfig.fontSize * 1.5)
            let cornerRadius = isSingleLine
                             ? UIConfig.compactCornerRadius
                             : UIConfig.standardCornerRadius

            let containerView = UIView()
            containerView.backgroundColor = .clear

            // Create dock-style background using SwiftUI approach
            let backgroundStack = UIView()
            
            // Layer 1: Black tint (matches dock exactly)
            let blackTintView = UIView()
            blackTintView.backgroundColor = UIColor.black.withAlphaComponent(0.05)
            blackTintView.layer.cornerRadius = cornerRadius
            blackTintView.clipsToBounds = true
            
            // Layer 2: Ultra thin material (matches dock exactly)
            let mainBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            mainBlurView.alpha = 0.3
            mainBlurView.layer.cornerRadius = cornerRadius
            mainBlurView.clipsToBounds = true
            
            // Add layers to background stack
            backgroundStack.addSubview(blackTintView)
            backgroundStack.addSubview(mainBlurView)
            
            blackTintView.translatesAutoresizingMaskIntoConstraints = false
            mainBlurView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                blackTintView.topAnchor.constraint(equalTo: backgroundStack.topAnchor),
                blackTintView.leadingAnchor.constraint(equalTo: backgroundStack.leadingAnchor),
                blackTintView.trailingAnchor.constraint(equalTo: backgroundStack.trailingAnchor),
                blackTintView.bottomAnchor.constraint(equalTo: backgroundStack.bottomAnchor),
                mainBlurView.topAnchor.constraint(equalTo: backgroundStack.topAnchor),
                mainBlurView.leadingAnchor.constraint(equalTo: backgroundStack.leadingAnchor),
                mainBlurView.trailingAnchor.constraint(equalTo: backgroundStack.trailingAnchor),
                mainBlurView.bottomAnchor.constraint(equalTo: backgroundStack.bottomAnchor)
            ])
            
            // Add border using SwiftUI-style approach (matches dock exactly)
            let borderLayer = CAShapeLayer()
            borderLayer.path = UIBezierPath(roundedRect: CGRect.zero, cornerRadius: cornerRadius).cgPath
            borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.1).cgColor
            borderLayer.fillColor = UIColor.clear.cgColor
            borderLayer.lineWidth = 0.5
            backgroundStack.layer.addSublayer(borderLayer)
            
            // Add shadow (matches dock exactly)
            backgroundStack.layer.shadowColor = UIColor.black.cgColor
            backgroundStack.layer.shadowOpacity = 0.25
            backgroundStack.layer.shadowRadius = 20
            backgroundStack.layer.shadowOffset = CGSize(width: 0, height: 10)

            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = UIConfig.iconSpacing

            let iconView: UIView
            let textColor: UIColor
            switch type {
            case .success:
                let iconImageView = UIImageView()
                iconImageView.image = UIImage(systemName: "checkmark.circle")
                iconImageView.tintColor = .white
                iconImageView.contentMode = .scaleAspectFit
                iconView = iconImageView
                textColor = .white
            case .error:
                let iconImageView = UIImageView()
                iconImageView.image = UIImage(systemName: "exclamationmark.circle")
                iconImageView.tintColor = .white
                iconImageView.contentMode = .scaleAspectFit
                iconView = iconImageView
                textColor = .white
            case .warning:
                let iconImageView = UIImageView()
                iconImageView.image = UIImage(systemName: "exclamationmark.circle")
                iconImageView.tintColor = .white
                iconImageView.contentMode = .scaleAspectFit
                iconView = iconImageView
                textColor = .white
            }
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: UIConfig.iconSize),
                iconView.heightAnchor.constraint(equalToConstant: UIConfig.iconSize)
            ])
            stackView.addArrangedSubview(iconView)

            label.textColor = textColor
            label.textAlignment = .left
            label.numberOfLines = 0
            stackView.addArrangedSubview(label)

            containerView.addSubview(backgroundStack)
            //  Place content *above* the blur so colour stays 100 % opaque white,
            //  mirroring the dock's SwiftUI implementation.
            backgroundStack.addSubview(stackView)
            backgroundStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                backgroundStack.topAnchor.constraint(equalTo: containerView.topAnchor),
                backgroundStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                backgroundStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                backgroundStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            stackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: backgroundStack.topAnchor, constant: UIConfig.verticalPadding),
                stackView.bottomAnchor.constraint(equalTo: backgroundStack.bottomAnchor, constant: -UIConfig.verticalPadding),
                stackView.leadingAnchor.constraint(equalTo: backgroundStack.leadingAnchor, constant: UIConfig.horizontalPadding),
                stackView.trailingAnchor.constraint(equalTo: backgroundStack.trailingAnchor, constant: -UIConfig.horizontalPadding)
            ])

            window.addSubview(containerView)
            containerView.translatesAutoresizingMaskIntoConstraints = false
            let bottomConstraint = containerView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: position.bottomOffset)
            containerView.toastBottomConstraint = bottomConstraint
            containerView.toastPosition = position
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                bottomConstraint,
                containerView.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, multiplier: UIConfig.maxWidthMultiplier),
                containerView.heightAnchor.constraint(lessThanOrEqualToConstant: UIConfig.maxHeight),
                containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: UIConfig.minHeight),
                containerView.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 16),
                containerView.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -16)
            ])

            // Update border frame when container is laid out
            containerView.layoutIfNeeded()
            borderLayer.path = UIBezierPath(roundedRect: backgroundStack.bounds, cornerRadius: cornerRadius).cgPath

            containerView.alpha = 0
            containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            window.layoutIfNeeded()

            UIView.animate(withDuration: AnimationConfig.animationDuration,
                         delay: 0,
                         usingSpringWithDamping: 0.7,
                         initialSpringVelocity: 0.3,
                         options: [.allowUserInteraction],
                         animations: {
                containerView.transform = .identity
                containerView.alpha = 1
                mainBlurView.alpha = 0.3
            })

            containerView.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleToastTap(_:)))
            containerView.addGestureRecognizer(tapGesture)

            // Use custom duration instead of default
            let timer = Timer.scheduledTimer(withTimeInterval: duration,
                                          repeats: false) { [weak self] timer in
                Task { @MainActor in
                    self?.dismissToast(containerView: containerView, timer: timer, isAutomatic: true)
                }
            }

            let toastItem = ToastItem(containerView: containerView, position: position, timer: timer)
            self.toasts.append(toastItem)

            self.updateToastPositions()
        }
    }

    private func dismissToast(containerView: UIView, timer: Timer, isAutomatic: Bool = false) {
        timer.invalidate()

        guard let index = toasts.firstIndex(where: { $0.containerView == containerView }),
              index < toasts.count else {
            containerView.removeFromSuperview()
            if let idx = toasts.firstIndex(where: { $0.containerView == containerView }) {
                toasts.remove(at: idx)
            }
            return
        }

        let backgroundStack = containerView.subviews.first

        UIView.animate(withDuration: AnimationConfig.dismissDuration,
                      delay: 0,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0.2,
                      options: .curveEaseOut,
                      animations: {
            containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            containerView.alpha = 0
            backgroundStack?.alpha = 0
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            containerView.removeFromSuperview()

            if let validIndex = self.toasts.firstIndex(where: { $0.containerView == containerView }), validIndex < self.toasts.count {
                self.toasts.remove(at: validIndex)
                self.updateToastPositions()
            } else if index < self.toasts.count && self.toasts[index].containerView == containerView {
                self.toasts.remove(at: index)
                self.updateToastPositions()
            }
        })
    }

    @objc private func handleToastTap(_ gesture: UITapGestureRecognizer) {
        if let containerView = gesture.view,
           let index = toasts.firstIndex(where: { $0.containerView == containerView }) {
            let timer = toasts[index].timer
            dismissToast(containerView: containerView, timer: timer)
        }
    }

    private func updateAllToastPositions() {
        updateToastPositions()
    }

    func logOnly(_ message: String, type: ToastType) {
        let tabName = TabSelectionManager.shared.selectedTabName

        let statusIcon: String
        switch type {
        case .success:
            statusIcon = "✅"
        case .error:
            statusIcon = "❌"
        case .warning:
            statusIcon = "⚠️"
        }

        let logMessage = "[\(tabName)] \(statusIcon) \(message)"

        #if DEBUG
        print(logMessage)
        #endif

        logs.append(logMessage)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    func addLog(_ message: String) {
        let tabName = TabSelectionManager.shared.selectedTabName
        let logMessage = "[\(tabName)] \(message)"
        
        #if DEBUG
        print(logMessage)
        #endif
        
        logs.append(logMessage)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    func clearLogs() {
        logs.removeAll()
        self.showToast("Logs cleared", type: .success, position: .default)
    }
}