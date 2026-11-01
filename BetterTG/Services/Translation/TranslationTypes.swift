// TranslationTypes.swift
// Multi-engine message translation types (fork feature).

import Foundation

enum TranslationEngine: String, CaseIterable, Codable, Sendable {
    case google
    case deepl
    case azure
    case mymemory

    var displayName: String {
        switch self {
        case .google: "Google"
        case .deepl: "DeepL"
        case .azure: "Azure"
        case .mymemory: "MyMemory"
        }
    }
}

struct TranslationResult: Sendable {
    let text: String
    let engine: TranslationEngine
    let detectedSource: String?
}

enum TranslationError: Error, LocalizedError {
    case emptyText
    case noEngineAvailable
    case rateLimited(TranslationEngine)
    case engineFailed(TranslationEngine, String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .emptyText: "Empty text"
        case .noEngineAvailable: "No translation engine available"
        case .rateLimited(let e): "\(e.displayName) rate limited"
        case .engineFailed(let e, let m): "\(e.displayName): \(m)"
        case .network(let m): m
        }
    }
}
