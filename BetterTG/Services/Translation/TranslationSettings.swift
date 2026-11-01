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

    /// Ordered engine chain; empty means default order.
    static var engineChain: [TranslationEngine] {
        get {
            guard let raw = UserDefaults.standard.array(forKey: prefix + "engineChain") as? [String] else {
                return TranslationEngine.allCases
            }
            let parsed = raw.compactMap(TranslationEngine.init(rawValue:))
            return parsed.isEmpty ? TranslationEngine.allCases : parsed
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue), forKey: prefix + "engineChain")
        }
    }

    static var deeplAPIKey: String {
        get { UserDefaults.standard.string(forKey: prefix + "deeplAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "deeplAPIKey") }
    }

    static var azureAPIKey: String {
        get { UserDefaults.standard.string(forKey: prefix + "azureAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "azureAPIKey") }
    }

    static var azureRegion: String {
        get { UserDefaults.standard.string(forKey: prefix + "azureRegion") ?? "eastasia" }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "azureRegion") }
    }
}
