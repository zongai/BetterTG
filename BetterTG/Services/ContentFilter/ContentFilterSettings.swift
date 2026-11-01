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
        set { UserDefaults.standard.set(Self.normalized(newValue), forKey: prefix + "whitelist") }
    }

    /// Keywords that hide a text message when filterEnabled.
    static var blacklist: [String] {
        get { UserDefaults.standard.stringArray(forKey: prefix + "blacklist") ?? [] }
        set { UserDefaults.standard.set(Self.normalized(newValue), forKey: prefix + "blacklist") }
    }

    /// Trim, drop empty, dedupe case-insensitively (keep first spelling).
    private static func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()
        for raw in values {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }
}

enum ContentFilter {
    /// Whether a text body should be shown. Whitelist wins over blacklist.
    static func shouldShowText(_ text: String) -> Bool {
        guard ContentFilterSettings.filterEnabled else { return true }
        let body = text.lowercased()
        let white = ContentFilterSettings.whitelist.map { $0.lowercased() }.filter { !$0.isEmpty }
        if white.contains(where: { body.contains($0) }) { return true }
        let black = ContentFilterSettings.blacklist.map { $0.lowercased() }.filter { !$0.isEmpty }
        if black.contains(where: { body.contains($0) }) { return false }
        return true
    }
}
