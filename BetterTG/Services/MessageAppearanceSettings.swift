// MessageAppearanceSettings.swift
// Fork: message text size scale.

import Foundation
import UIKit

enum MessageAppearanceSettings {
    private static let prefix = "BetterTG.fork.appearance."

    static let didChangeNotification = Notification.Name("BetterTG.fork.messageAppearanceDidChange")

    /// Multiplier applied to message body font (0.85 ... 1.50). Default 1.0.
    static var textScale: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: prefix + "textScale")
            if v == 0 { return 1.0 }
            return CGFloat(min(1.50, max(0.85, v)))
        }
        set {
            let clamped = min(1.50, max(0.85, newValue))
            UserDefaults.standard.set(Double(clamped), forKey: prefix + "textScale")
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static var bodyPointSize: CGFloat { 17 * textScale }

    static var bodyFont: UIFont { .systemFont(ofSize: bodyPointSize) }

    static var translationPointSize: CGFloat { 15 * textScale }

    static var translationFont: UIFont { .systemFont(ofSize: translationPointSize) }

    static var scalePercentLabel: String {
        "\(Int((textScale * 100).rounded()))%"
    }
}
