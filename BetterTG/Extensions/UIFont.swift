// UIFont.swift

import UIKit

extension UIFont {
    static let monospaced = UIFont(name: "Menlo", size: 17) ?? UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    static let bold = UIFont.boldSystemFont(ofSize: 17)
    static let italic = UIFont.italicSystemFont(ofSize: 17)

    /// Message body font; respects fork message text scale.
    static var body: UIFont { MessageAppearanceSettings.bodyFont }

    static let caption = UIFont.systemFont(ofSize: 12)
}
