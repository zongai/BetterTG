// ContentFilterSettings.swift

import Foundation

enum ContentFilterSettings {
    private static let prefix = "BetterTG.fork.contentFilter."

    static var hideAds: Bool {
        get { UserDefaults.standard.bool(forKey: prefix + "hideAds") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "hideAds") }
    }

    static var filterEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: prefix + "filterEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "filterEnabled") }
    }

    /// Keywords that force a message to show (checked before blacklist).
    static var whitelist: [String] {
        get { UserDefaults.standard.stringArray(forKey: prefix + "whitelist") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "whitelist") }
    }

    /// Keywords that hide a text message when filterEnabled.
    static var blacklist: [String] {
        get { UserDefaults.standard.stringArray(forKey: prefix + "blacklist") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "blacklist") }
    }
}

enum ContentFilter {
    /// Whether a text body should be shown. Whitelist wins over blacklist.
    static func shouldShowText(_ text: String) -> Bool {
        guard ContentFilterSettings.filterEnabled else { return true }
        let body = text.lowercased()
        let white = ContentFilterSettings.whitelist.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if white.contains(where: { body.contains($0) }) { return true }
        let black = ContentFilterSettings.blacklist.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if black.contains(where: { body.contains($0) }) { return false }
        return true
    }
}
