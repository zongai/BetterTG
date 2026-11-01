// TranslationServices.swift
// Google / DeepL / Azure / MyMemory translators with simple HTTP.

import Foundation

enum TranslationServices {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        c.timeoutIntervalForResource = 40
        return URLSession(configuration: c)
    }()

    static func translate(
        text: String,
        targetLang: String,
        engine: TranslationEngine
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyText }
        switch engine {
        case .google:
            let out = try await google(text: trimmed, target: targetLang)
            return TranslationResult(text: out, engine: .google, detectedSource: nil)
        case .deepl:
            let out = try await deepl(text: trimmed, target: targetLang)
            return TranslationResult(text: out, engine: .deepl, detectedSource: nil)
        case .azure:
            let out = try await azure(text: trimmed, target: targetLang)
            return TranslationResult(text: out, engine: .azure, detectedSource: nil)
        case .mymemory:
            let out = try await mymemory(text: trimmed, target: targetLang)
            return TranslationResult(text: out, engine: .mymemory, detectedSource: nil)
        }
    }

    // MARK: - Google (unofficial gtx)

    private static func google(text: String, target: String) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: normalizeGoogle(target)),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text),
        ]
        guard let url = components.url else { throw TranslationError.network("bad google url") }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw TranslationError.rateLimited(.google)
        }
        // Response shape: [[["translated","source",...],...],...]
        guard let root = try JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = root.first as? [Any]
        else {
            throw TranslationError.engineFailed(.google, "unexpected payload")
        }
        var parts: [String] = []
        for item in sentences {
            guard let row = item as? [Any], let piece = row.first as? String else { continue }
            parts.append(piece)
        }
        let joined = parts.joined()
        guard !joined.isEmpty else { throw TranslationError.engineFailed(.google, "empty result") }
        return joined
    }

    private static func normalizeGoogle(_ code: String) -> String {
        let c = code.lowercased()
        if c == "zh" || c.hasPrefix("zh-han") { return "zh-CN" }
        if c.hasPrefix("pt") { return c.contains("br") ? "pt" : "pt" }
        return String(c.prefix(2))
    }

    // MARK: - DeepL (multi-key rotation)

    private static var deeplKeyCooldown: [String: Date] = [:]
    private static let deeplKeyLock = NSLock()

    private static func isDeepLKeyCooling(_ key: String) -> Bool {
        deeplKeyLock.lock()
        defer { deeplKeyLock.unlock() }
        guard let until = deeplKeyCooldown[key] else { return false }
        if until > Date() { return true }
        deeplKeyCooldown[key] = nil
        return false
    }

    private static func markDeepLKeyLimited(_ key: String, minutes: Double = 5) {
        deeplKeyLock.lock()
        deeplKeyCooldown[key] = Date().addingTimeInterval(minutes * 60)
        deeplKeyLock.unlock()
    }

    private static func deepl(text: String, target: String) async throws -> String {
        let keys = TranslationSettings.deeplAPIKeys
        guard !keys.isEmpty else { throw TranslationError.engineFailed(.deepl, "missing API key") }

        var lastError: Error = TranslationError.engineFailed(.deepl, "no key available")
        var attempted = 0
        for key in keys {
            if isDeepLKeyCooling(key) { continue }
            attempted += 1
            do {
                return try await deeplOnce(text: text, target: target, key: key)
            } catch let error as TranslationError {
                lastError = error
                switch error {
                case .rateLimited:
                    markDeepLKeyLimited(key)
                    continue
                case .engineFailed(_, let message):
                    if message.contains("HTTP 403") || message.contains("HTTP 456")
                        || message.contains("HTTP 401")
                    {
                        markDeepLKeyLimited(key, minutes: 30)
                        continue
                    }
                    throw error
                default:
                    throw error
                }
            }
        }
        if attempted == 0 {
            return try await deeplOnce(text: text, target: target, key: keys[0])
        }
        throw lastError
    }

    private static func deeplOnce(text: String, target: String, key: String) async throws -> String {
        let free = key.hasSuffix(":fx")
        let host = free ? "api-free.deepl.com" : "api.deepl.com"
        var request = URLRequest(url: URL(string: "https://\(host)/v2/translate")!)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let targetCode = deeplTarget(target)
        let body = "text=\(urlEncode(text))&target_lang=\(targetCode)"
        request.httpBody = body.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 || http.statusCode == 456 {
                throw TranslationError.rateLimited(.deepl)
            }
            if http.statusCode >= 400 {
                throw TranslationError.engineFailed(.deepl, "HTTP \(http.statusCode)")
            }
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let first = translations.first,
              let out = first["text"] as? String
        else {
            throw TranslationError.engineFailed(.deepl, "unexpected payload")
        }
        return out
    }

    private static func deeplTarget(_ code: String) -> String {
        let c = code.lowercased()
        if c.hasPrefix("zh") { return "ZH" }
        if c.hasPrefix("pt") { return c.contains("br") ? "PT-BR" : "PT-PT" }
        if c.hasPrefix("en") { return "EN" }
        return String(c.prefix(2)).uppercased()
    }

    // MARK: - Azure Translator

    private static func azure(text: String, target: String) async throws -> String {
        let key = TranslationSettings.azureAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranslationError.engineFailed(.azure, "missing API key") }
        let region = TranslationSettings.azureRegion
        let tl = String(target.prefix(2)).lowercased()
        var request = URLRequest(
            url: URL(string: "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=\(tl)")!
        )
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [["Text": text]])
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw TranslationError.rateLimited(.azure)
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first,
              let translations = first["translations"] as? [[String: Any]],
              let out = translations.first?["text"] as? String
        else {
            throw TranslationError.engineFailed(.azure, "unexpected payload")
        }
        return out
    }

    // MARK: - MyMemory (free, limited)

    private static func mymemory(text: String, target: String) async throws -> String {
        let tl = String(target.prefix(2)).lowercased()
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "autodetect|\(tl)"),
        ]
        guard let url = components.url else { throw TranslationError.network("bad mymemory url") }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw TranslationError.rateLimited(.mymemory)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rd = json["responseData"] as? [String: Any],
              let out = rd["translatedText"] as? String
        else {
            throw TranslationError.engineFailed(.mymemory, "unexpected payload")
        }
        return out
    }

    private static func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
