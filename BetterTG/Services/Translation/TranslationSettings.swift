// TranslationSettings.swift
// UserDefaults-backed settings for automatic message translation.

import Foundation

enum TranslationSettings {
    private static let prefix = "BetterTG.fork.translation."

    /// Master switch for automatic message-level translation.
    static var autoTranslateNonTarget: Bool {
        get { UserDefaults.standard.bool(forKey: prefix + "autoTranslateNonTarget") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "autoTranslateNonTarget") }
    }

    /// BCP-47 / Telegram-style target language code (e.g. zh, en, ja).
    static var targetLanguage: String {
        get {
            let v = UserDefaults.standard.string(forKey: prefix + "targetLanguage") ?? ""
            if !v.isEmpty { return v }
            return MessageTranslation.appLanguageCode
        }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "targetLanguage") }
    }

    /// Ordered engine chain used for failover. Empty → all engines in default order.
    static var engineChain: [TranslationEngine] {
        get {
            guard let raw = UserDefaults.standard.array(forKey: prefix + "engineChain") as? [String] else {
                return TranslationEngine.allCases
            }
            let parsed = raw.compactMap(TranslationEngine.init(rawValue:))
            return parsed.isEmpty ? TranslationEngine.allCases : parsed
        }
        set {
            // Dedupe while preserving order.
            var seen = Set<TranslationEngine>()
            var ordered: [TranslationEngine] = []
            for e in newValue where seen.insert(e).inserted {
                ordered.append(e)
            }
            UserDefaults.standard.set(ordered.map(\.rawValue), forKey: prefix + "engineChain")
        }
    }

    /// Multiple DeepL auth keys, tried in order on rate-limit / failure.
    static var deeplAPIKeys: [String] {
        get {
            if let arr = UserDefaults.standard.stringArray(forKey: prefix + "deeplAPIKeys") {
                return normalizedKeys(arr)
            }
            // Migrate legacy single key.
            let legacy = UserDefaults.standard.string(forKey: prefix + "deeplAPIKey") ?? ""
            let trimmed = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return [] }
            let keys = [trimmed]
            UserDefaults.standard.set(keys, forKey: prefix + "deeplAPIKeys")
            return keys
        }
        set {
            let keys = normalizedKeys(newValue)
            UserDefaults.standard.set(keys, forKey: prefix + "deeplAPIKeys")
            // Keep legacy key in sync for any leftover readers.
            UserDefaults.standard.set(keys.first ?? "", forKey: prefix + "deeplAPIKey")
        }
    }

    /// Convenience: first key (legacy API).
    static var deeplAPIKey: String {
        get { deeplAPIKeys.first ?? "" }
        set {
            var keys = deeplAPIKeys
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !keys.isEmpty { keys.removeFirst() }
            } else if keys.isEmpty {
                keys = [trimmed]
            } else {
                keys[0] = trimmed
            }
            deeplAPIKeys = keys
        }
    }

    static var azureAPIKey: String {
        get { UserDefaults.standard.string(forKey: prefix + "azureAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "azureAPIKey") }
    }

    static var azureRegion: String {
        get { UserDefaults.standard.string(forKey: prefix + "azureRegion") ?? "eastasia" }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "azureRegion") }
    }

    private static func normalizedKeys(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in values {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, seen.insert(t).inserted else { continue }
            result.append(t)
        }
        return result
    }
}
