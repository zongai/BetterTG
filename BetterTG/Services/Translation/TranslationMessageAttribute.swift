// TranslationMessageAttribute.swift
// In-memory + disk-backed per-message translation attribute (fork).

import Foundation

/// One translated body attached to a chat message, analogous to Telegram's translation attribute.
struct TranslationMessageAttribute: Codable, Equatable, Sendable {
    var messageID: Int64
    var chatID: Int64
    var sourceTextHash: Int
    var targetLanguage: String
    var translatedText: String
    var engine: String
    var updatedAt: Date
}

/// Shared store for message-level translations. Posts `.translationMessageDidUpdate` when a value changes.
@MainActor
final class TranslationMessageStore {
    static let shared = TranslationMessageStore()

    static let didUpdateNotification = Notification.Name("BetterTG.fork.translationMessageDidUpdate")

    private var attributes: [String: TranslationMessageAttribute] = [:]
    private let diskKey = "BetterTG.fork.translation.attributes"

    private init() {
        if let data = UserDefaults.standard.data(forKey: diskKey),
           let decoded = try? JSONDecoder().decode([String: TranslationMessageAttribute].self, from: data)
        {
            attributes = decoded
        }
    }

    private func key(chatID: Int64, messageID: Int64, target: String) -> String {
        "\(chatID):\(messageID):\(target.lowercased())"
    }

    func attribute(chatID: Int64, messageID: Int64, target: String? = nil) -> TranslationMessageAttribute? {
        let t = (target ?? TranslationSettings.targetLanguage).lowercased()
        return attributes[key(chatID: chatID, messageID: messageID, target: t)]
    }

    func translatedText(chatID: Int64, messageID: Int64, sourceText: String) -> String? {
        let t = TranslationSettings.targetLanguage.lowercased()
        guard let attr = attributes[key(chatID: chatID, messageID: messageID, target: t)] else { return nil }
        guard attr.sourceTextHash == sourceText.hashValue else { return nil }
        return attr.translatedText
    }

    func set(
        chatID: Int64,
        messageID: Int64,
        sourceText: String,
        translatedText: String,
        engine: TranslationEngine
    ) {
        let t = TranslationSettings.targetLanguage.lowercased()
        let attr = TranslationMessageAttribute(
            messageID: messageID,
            chatID: chatID,
            sourceTextHash: sourceText.hashValue,
            targetLanguage: t,
            translatedText: translatedText,
            engine: engine.rawValue,
            updatedAt: Date()
        )
        attributes[key(chatID: chatID, messageID: messageID, target: t)] = attr
        persist()
        NotificationCenter.default.post(
            name: Self.didUpdateNotification,
            object: nil,
            userInfo: [
                "chatID": chatID,
                "messageID": messageID,
            ]
        )
    }

    private func persist() {
        if attributes.count > 800 {
            let sorted = attributes.values.sorted { $0.updatedAt < $1.updatedAt }
            for old in sorted.prefix(attributes.count - 600) {
                attributes.removeValue(
                    forKey: key(chatID: old.chatID, messageID: old.messageID, target: old.targetLanguage)
                )
            }
        }
        if let data = try? JSONEncoder().encode(attributes) {
            UserDefaults.standard.set(data, forKey: diskKey)
        }
    }
}
