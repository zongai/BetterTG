// AutoTranslator.swift
// Message-level auto translation: language skip, engine failover, attribute store.

import Foundation
import NaturalLanguage

@MainActor
final class AutoTranslator {
    static let shared = AutoTranslator()

    private var inFlight: Set<String> = []
    private let coordinator = TranslationCoordinator.shared

    private init() {}

    /// Translate a message body when auto-translate is on and the text is not already the target language.
    /// Writes `TranslationMessageAttribute` on success.
    @discardableResult
    func translateIfNeeded(
        chatID: Int64,
        messageID: Int64,
        text: String,
        knownSourceLanguage: String? = nil
    ) async -> String? {
        guard TranslationSettings.autoTranslateNonTarget else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let target = TranslationSettings.targetLanguage.lowercased()
        if let cached = TranslationMessageStore.shared.translatedText(
            chatID: chatID,
            messageID: messageID,
            sourceText: trimmed
        ) {
            return cached
        }

        let source = (knownSourceLanguage ?? detectLanguage(of: trimmed))?.lowercased()
        if let source, isSameLanguage(source, target) {
            return nil
        }

        let flightKey = "\(chatID):\(messageID):\(target):\(trimmed.hashValue)"
        guard !inFlight.contains(flightKey) else { return nil }
        inFlight.insert(flightKey)
        defer { inFlight.remove(flightKey) }

        let chain = coordinator.effectiveChain(configured: TranslationSettings.engineChain)
        for engine in chain {
            if engine == .deepl, TranslationSettings.deeplAPIKey.isEmpty { continue }
            if engine == .azure, TranslationSettings.azureAPIKey.isEmpty { continue }
            do {
                let result = try await TranslationServices.translate(
                    text: trimmed,
                    targetLang: target,
                    engine: engine
                )
                coordinator.clearLimit(engine)
                let out = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !out.isEmpty, out != trimmed else { continue }
                TranslationMessageStore.shared.set(
                    chatID: chatID,
                    messageID: messageID,
                    sourceText: trimmed,
                    translatedText: out,
                    engine: engine
                )
                return out
            } catch TranslationError.rateLimited(let e) {
                coordinator.markLimited(e)
                continue
            } catch {
                continue
            }
        }
        return nil
    }

    /// Batch helper for a slice of chat messages (used by ChatVM).
    func translateVisibleMessages(_ messages: [CustomMessage]) {
        guard TranslationSettings.autoTranslateNonTarget else { return }
        let slice = Array(messages.prefix(50))
        Task { @MainActor in
            for message in slice {
                let text = message.formattedText?.text ?? ""
                guard !text.isEmpty else { continue }
                _ = await translateIfNeeded(
                    chatID: message.message.chatId,
                    messageID: message.id,
                    text: text
                )
            }
        }
    }

    private func detectLanguage(of text: String) -> String? {
        MessageTranslation.detectedLanguage(of: text)
    }

    private func isSameLanguage(_ a: String, _ b: String) -> Bool {
        let na = normalize(a)
        let nb = normalize(b)
        if na == nb { return true }
        if na.hasPrefix("zh") && nb.hasPrefix("zh") { return true }
        return false
    }

    private func normalize(_ code: String) -> String {
        var c = code.lowercased()
        if c.hasSuffix("-raw") { c = String(c.dropLast(4)) }
        if c.count > 3, c.contains("-") {
            // keep zh-cn style for zh comparison via hasPrefix
            return c
        }
        return String(c.prefix(2))
    }
}
