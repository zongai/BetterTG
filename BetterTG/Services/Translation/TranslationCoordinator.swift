// TranslationCoordinator.swift
// Engine chain, rate-limit cooldown, failover (Harbor-style).

import Foundation

final class TranslationCoordinator: @unchecked Sendable {
    static let shared = TranslationCoordinator()

    private var limitedUntil: [TranslationEngine: Date] = [:]
    private let lock = NSLock()

    func effectiveChain(configured: [TranslationEngine]) -> [TranslationEngine] {
        let source = configured.isEmpty ? TranslationEngine.allCases : configured
        var seen = Set<TranslationEngine>()
        var list: [TranslationEngine] = []
        for e in source {
            guard seen.insert(e).inserted else { continue }
            if isCooling(e) { continue }
            list.append(e)
        }
        if list.isEmpty {
            seen.removeAll()
            for e in source where seen.insert(e).inserted {
                list.append(e)
            }
        }
        return list
    }

    func isCooling(_ engine: TranslationEngine) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let until = limitedUntil[engine] else { return false }
        if until > Date() { return true }
        limitedUntil[engine] = nil
        return false
    }

    func markLimited(_ engine: TranslationEngine, minutes: Double = 5) {
        lock.lock()
        limitedUntil[engine] = Date().addingTimeInterval(minutes * 60)
        lock.unlock()
    }

    func clearLimit(_ engine: TranslationEngine) {
        lock.lock()
        limitedUntil[engine] = nil
        lock.unlock()
    }
}
