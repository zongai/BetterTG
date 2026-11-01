// AutoTranslator.swift
// Message-level auto translation with cache and language skip.

import Foundation
import NaturalLanguage

@MainActor
final class AutoTranslator {
    static let shared = AutoTranslator()

    /// messageKey -> translated text
    private var memoryCache: [String: String] = [:]
    private let diskKey = "BetterTG.fork.translation.cache"
    private var inFlight: Set<String> = []

    private init() {
        if let data = UserDefaults.standard.dictionary(forKey: diskKey) as? [String: String] {
            memoryCache = data
        }
    }

    /// Returns cached or newly translated text. Nil when skipped or failed.
    func translateIfNeeded(
        messageKey: String,
        text: String,
        knownSourceLanguage: String? = nil
    ) async -> String? {
        guard TranslationSettings.autoTranslateNonTarget else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let target = TranslationSettings.targetLanguage.lowercased()
        let source = (knownSourceLanguage ?? detectLanguage(of: trimmed))?.lowercased()
        if let source, isSameLanguage(source, target) {
            return nil
        }

        let cacheKey = "\(messageKey)|\(target)|\(trimmed.hashValue)"
        if let hit = memoryCache[cacheKey] { return hit }
        guard !inFlight.contains(cacheKey) else { return nil }
        inFlight.insert(cacheKey)
        defer { inFlight.remove(cacheKey) }

        let chain = TranslationCoordinator.shared.effectiveChain(configured: TranslationSettings.engineChain)
        guard !chain.isEmpty else { return nil }

        for engine in chain {
            // Skip engines that need keys when missing.
            if engine == .deepl, TranslationSettings.deeplAPIKey.isEmpty { continue }
            if engine == .azure, TranslationSettings.azureAPIKey.isEmpty { continue }
            do {
                let result = try await TranslationServices.translate(
                    text: trimmed,
                    targetLang: target,
                    engine: engine
                )
                TranslationCoordinator.shared.clearLimit(engine)
                memoryCache[cacheKey] = result.text
                persistCache()
                return result.text
            } catch TranslationError.rateLimited(let e) {
                TranslationCoordinator.shared.markLimited(e)
                continue
            } catch {
                continue
            }
        }
        return nil
    }

    func cachedTranslation(messageKey: String, text: String) -> String? {
        let target = TranslationSettings.targetLanguage.lowercased()
        let cacheKey = "\(messageKey)|\(target)|\(text.trimmingCharacters(in: .whitespacesAndNewlines).hashValue)"
        return memoryCache[cacheKey]
    }

    private func persistCache() {
        // Keep cache bounded.
        if memoryCache.count > 500 {
            let keys = Array(memoryCache.keys.prefix(memoryCache.count - 400))
            for k in keys { memoryCache.removeValue(forKey: k) }
        }
        UserDefaults.standard.set(memoryCache, forKey: diskKey)
    }

    private func detectLanguage(of text: String) -> String? {
        MessageTranslation.detectedLanguage(of: text)
    }

    private func isSameLanguage(_ a: String, _ b: String) -> Bool {
        let na = String(a.prefix(2)).lowercased()
        let nb = String(b.prefix(2)).lowercased()
        if na == nb { return true }
        // zh / zh-CN / zh-TW
        if na == "zh" && nb == "zh" { return true }
        return false
    }
}
