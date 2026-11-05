// ForkSettingsSnapshot.swift
// Serializable snapshot of all BetterTG fork preferences (cloud + export).

import Foundation

/// Versioned payload stored as a document in Saved Messages.
struct ForkSettingsSnapshot: Codable, Equatable, Sendable {
    static let currentFormat = 1
    /// Caption / search marker in Saved Messages (do not translate).
    static let cloudMarker = "#BetterTGForkSettings"
    static let fileName = "bettertg-fork-settings.json"

    var format: Int = currentFormat
    /// Unix seconds; last-write-wins between devices.
    var updatedAt: TimeInterval
    var translation: TranslationSlice
    var contentFilter: ContentFilterSlice
    var download: DownloadSlice
    var appearance: AppearanceSlice?

    struct TranslationSlice: Codable, Equatable, Sendable {
        var autoTranslateNonTarget: Bool
        var showBilingual: Bool
        var targetLanguage: String
        var engineChain: [String]
        /// Keys intentionally omitted from cloud by default.
        var includeAPIKeys: Bool
        var deeplAPIKeys: [String]?
        var azureAPIKey: String?
        var azureRegion: String?
        /// chatID string → override
        var chatOverrides: [String: Bool]?
    }

    struct ContentFilterSlice: Codable, Equatable, Sendable {
        var hideAds: Bool
        var filterEnabled: Bool
        var blacklist: [String]
        var whitelist: [String]
    }

    struct DownloadSlice: Codable, Equatable, Sendable {
        var multiThreadDownload: Bool
        var parallelParts: Int
        var autoCleanupEnabled: Bool
        var keepDays: Int
        var maxCacheMB: Int
    }

    struct AppearanceSlice: Codable, Equatable, Sendable {
        var textScale: Double
    }

    static func capture(includeAPIKeys: Bool = false) -> ForkSettingsSnapshot {
        ForkSettingsSnapshot(
            format: currentFormat,
            updatedAt: ForkSettingsClock.now(),
            translation: .init(
                autoTranslateNonTarget: TranslationSettings.autoTranslateNonTarget,
                showBilingual: TranslationSettings.showBilingual,
                targetLanguage: TranslationSettings.targetLanguage,
                engineChain: TranslationSettings.engineChain.map(\.rawValue),
                includeAPIKeys: includeAPIKeys,
                deeplAPIKeys: includeAPIKeys ? TranslationSettings.deeplAPIKeys : nil,
                azureAPIKey: includeAPIKeys ? TranslationSettings.azureAPIKey : nil,
                azureRegion: includeAPIKeys ? TranslationSettings.azureRegion : nil,
                chatOverrides: Dictionary(
                    uniqueKeysWithValues: TranslationSettings.overriddenChatIDs.map {
                        (String($0.chatID), $0.enabled)
                    }
                )
            ),
            contentFilter: .init(
                hideAds: ContentFilterSettings.hideAds,
                filterEnabled: ContentFilterSettings.filterEnabled,
                blacklist: ContentFilterSettings.blacklist,
                whitelist: ContentFilterSettings.whitelist
            ),
            download: .init(
                multiThreadDownload: DownloadCacheSettings.multiThreadDownload,
                parallelParts: DownloadCacheSettings.parallelParts,
                autoCleanupEnabled: DownloadCacheSettings.autoCleanupEnabled,
                keepDays: DownloadCacheSettings.keepDays,
                maxCacheMB: DownloadCacheSettings.maxCacheMB
            ),
            appearance: .init(textScale: Double(MessageAppearanceSettings.textScale))
        )
    }

    /// Apply onto UserDefaults. Does not bump local clock unless `touchLocalClock` is true.
    @MainActor
    func apply(touchLocalClock: Bool = false) {
        TranslationSettings.autoTranslateNonTarget = translation.autoTranslateNonTarget
        TranslationSettings.showBilingual = translation.showBilingual
        if !translation.targetLanguage.isEmpty {
            TranslationSettings.targetLanguage = translation.targetLanguage
        }
        let engines = translation.engineChain.compactMap(TranslationEngine.init(rawValue:))
        if !engines.isEmpty {
            TranslationSettings.engineChain = engines
        }
        if translation.includeAPIKeys {
            if let keys = translation.deeplAPIKeys { TranslationSettings.deeplAPIKeys = keys }
            if let v = translation.azureAPIKey { TranslationSettings.azureAPIKey = v }
            if let v = translation.azureRegion { TranslationSettings.azureRegion = v }
        }
        if let overrides = translation.chatOverrides {
            for (key, enabled) in overrides {
                if let id = Int64(key) {
                    TranslationSettings.setAutoTranslate(enabled, chatID: id)
                }
            }
        }

        ContentFilterSettings.hideAds = contentFilter.hideAds
        ContentFilterSettings.filterEnabled = contentFilter.filterEnabled
        ContentFilterSettings.blacklist = contentFilter.blacklist
        ContentFilterSettings.whitelist = contentFilter.whitelist

        DownloadCacheSettings.multiThreadDownload = download.multiThreadDownload
        DownloadCacheSettings.parallelParts = download.parallelParts
        DownloadCacheSettings.autoCleanupEnabled = download.autoCleanupEnabled
        DownloadCacheSettings.keepDays = download.keepDays
        DownloadCacheSettings.maxCacheMB = download.maxCacheMB
        MultipartDownloadConfig.shared.applyFromSettings()

        if let appearance {
            MessageAppearanceSettings.textScale = CGFloat(appearance.textScale)
        }

        if touchLocalClock {
            ForkSettingsClock.set(updatedAt)
        } else {
            ForkSettingsClock.set(max(ForkSettingsClock.now(), updatedAt))
        }
        NotificationCenter.default.post(name: .forkSettingsDidApplyFromCloud, object: nil)
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> ForkSettingsSnapshot {
        try JSONDecoder().decode(ForkSettingsSnapshot.self, from: data)
    }
}

enum ForkSettingsClock {
    private static let key = "BetterTG.fork.settings.updatedAt"

    static func now() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: key)
        return stored > 0 ? stored : 0
    }

    static func touch() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    static func set(_ value: TimeInterval) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

extension Foundation.Notification.Name {
    static let forkSettingsDidApplyFromCloud = Self("BetterTG.fork.settingsDidApplyFromCloud")
}

enum ForkSettingsCloudOptions {
    private static let prefix = "BetterTG.fork.cloud."

    static var enabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: prefix + "enabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: prefix + "enabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "enabled") }
    }

    /// When true, DeepL/Azure keys are written into the Saved Messages payload.
    static var syncAPIKeys: Bool {
        get { UserDefaults.standard.bool(forKey: prefix + "syncAPIKeys") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "syncAPIKeys") }
    }
}
