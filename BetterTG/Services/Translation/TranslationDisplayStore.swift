// TranslationDisplayStore.swift
// Per-message preference: show original vs translation when bilingual is off.

import Foundation

/// Tracks which messages the user toggled to "original" (or back to translation).
/// In-memory only — resets when the process restarts.
@MainActor
enum TranslationDisplayStore {
    /// Keys are `"chatID:messageID"`. `true` = prefer original text.
    private static var preferOriginal: [String: Bool] = [:]

    private static func key(chatID: Int64, messageID: Int64) -> String {
        "\(chatID):\(messageID)"
    }

    static func showsOriginal(chatID: Int64, messageID: Int64) -> Bool {
        preferOriginal[key(chatID: chatID, messageID: messageID)] ?? false
    }

    static func setShowsOriginal(_ value: Bool, chatID: Int64, messageID: Int64) {
        preferOriginal[key(chatID: chatID, messageID: messageID)] = value
    }

    static func toggle(chatID: Int64, messageID: Int64) -> Bool {
        let k = key(chatID: chatID, messageID: messageID)
        let next = !(preferOriginal[k] ?? false)
        preferOriginal[k] = next
        return next
    }
}
