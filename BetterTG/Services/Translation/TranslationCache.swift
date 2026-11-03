// TranslationCache.swift
// Stable text-level translation cache (shared across messages with identical text).

import CryptoKit
import Foundation

struct TranslationCacheEntry: Codable, Equatable, Sendable {
    var sourceHash: String
    var targetLanguage: String
    var translatedText: String
    var engine: String
    var updatedAt: Date
}

/// Disk + memory cache keyed by stable content hash + target language.
/// Independent of message id so repeated text reuses one translation.
@MainActor
final class TranslationCache {
    static let shared = TranslationCache()

    static let didChangeNotification = Notification.Name("BetterTG.fork.translationCacheDidChange")

    private var entries: [String: TranslationCacheEntry] = [:]
    private let diskKey = "BetterTG.fork.translation.textCache"
    private let maxEntries = 2000
    private let trimTo = 1500

    private init() {
        if let data = UserDefaults.standard.data(forKey: diskKey),
           let decoded = try? JSONDecoder().decode([String: TranslationCacheEntry].self, from: data)
        {
            entries = decoded
        }
    }

    static func stableHash(of text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func key(sourceHash: String, target: String) -> String {
        "\(sourceHash)|\(target.lowercased())"
    }

    func text(for sourceText: String, target: String? = nil) -> String? {
        let t = (target ?? TranslationSettings.targetLanguage).lowercased()
        let h = Self.stableHash(of: sourceText)
        guard let entry = entries[key(sourceHash: h, target: t)] else { return nil }
        return entry.translatedText
    }

    func set(
        sourceText: String,
        translatedText: String,
        target: String? = nil,
        engine: TranslationEngine
    ) {
        let t = (target ?? TranslationSettings.targetLanguage).lowercased()
        let h = Self.stableHash(of: sourceText)
        let entry = TranslationCacheEntry(
            sourceHash: h,
            targetLanguage: t,
            translatedText: translatedText,
            engine: engine.rawValue,
            updatedAt: Date()
        )
        entries[key(sourceHash: h, target: t)] = entry
        persist()
    }

    var count: Int { entries.count }

    func clear() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: diskKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func persist() {
        if entries.count > maxEntries {
            let sorted = entries.sorted { $0.value.updatedAt < $1.value.updatedAt }
            for item in sorted.prefix(entries.count - trimTo) {
                entries.removeValue(forKey: item.key)
            }
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: diskKey)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
