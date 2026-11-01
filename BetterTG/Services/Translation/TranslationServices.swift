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
        case .bing:
            let out = try await bing(text: trimmed, target: targetLang)
            return TranslationResult(text: out, engine: .bing, detectedSource: nil)
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

    // MARK: - Bing / Microsoft Edge (free, no key; Harbor AzureBingTranslate)

    /// Prefer Edge endpoint; fall back to Bing Translator page token API.
    private static func bing(text: String, target: String) async throws -> String {
        let tl = bingTarget(target)
        do {
            return try await bingEdge(text: text, target: tl)
        } catch {
            return try await bingWeb(text: text, target: tl)
        }
    }

    private static func bingEdge(text: String, target: String) async throws -> String {
        var components = URLComponents(string: "https://edge.microsoft.com/translate/translatetext")!
        components.queryItems = [
            URLQueryItem(name: "from", value: ""),
            URLQueryItem(name: "to", value: target),
            URLQueryItem(name: "isEnterpriseClient", value: "false"),
        ]
        guard let url = components.url else { throw TranslationError.network("bad bing edge url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: [text])
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                throw TranslationError.rateLimited(.bing)
            }
            if http.statusCode >= 400 {
                throw TranslationError.engineFailed(.bing, "Edge HTTP \(http.statusCode)")
            }
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first,
              let translations = first["translations"] as? [[String: Any]],
              let out = translations.first?["text"] as? String,
              !out.isEmpty
        else {
            throw TranslationError.engineFailed(.bing, "edge unexpected payload")
        }
        return out
    }

    private static func bingWeb(text: String, target: String) async throws -> String {
        // Fetch translator page for IG / IID / token / key (cached briefly).
        let auth = try await bingWebAuth()
        var components = URLComponents()
        components.scheme = "https"
        components.host = auth.host
        components.path = "/ttranslatev3"
        components.queryItems = [
            URLQueryItem(name: "isVertical", value: "1"),
            URLQueryItem(name: "IG", value: auth.ig),
            URLQueryItem(name: "IID", value: auth.iid),
        ]
        guard let url = components.url else { throw TranslationError.network("bad bing web url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.bing.com/translator", forHTTPHeaderField: "Referer")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "fromLang", value: "auto-detect"),
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "to", value: target),
            URLQueryItem(name: "token", value: auth.token),
            URLQueryItem(name: "key", value: auth.key),
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                throw TranslationError.rateLimited(.bing)
            }
            if http.statusCode >= 400 {
                bingWebAuthCache = nil
                throw TranslationError.engineFailed(.bing, "Web HTTP \(http.statusCode)")
            }
        }
        // Response is often [[{translations:[{text:}]}]] or similar nested arrays.
        if let out = bingExtractText(data), !out.isEmpty {
            return out
        }
        throw TranslationError.engineFailed(.bing, "web unexpected payload")
    }

    private struct BingWebAuth {
        var ig: String
        var iid: String
        var key: String
        var token: String
        var host: String
        var expiresAt: Date
    }

    private static var bingWebAuthCache: BingWebAuth?
    private static let bingAuthLock = NSLock()

    private static func bingWebAuth() async throws -> BingWebAuth {
        bingAuthLock.lock()
        if let cached = bingWebAuthCache, cached.expiresAt > Date() {
            bingAuthLock.unlock()
            return cached
        }
        bingAuthLock.unlock()

        var request = URLRequest(url: URL(string: "https://www.bing.com/translator")!)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw TranslationError.engineFailed(.bing, "auth page empty")
        }
        // IG:"..."  IID:"..."  params_AbusePreventionHelper = [key, "token", ttl]
        guard let ig = bingMatch(html, pattern: #"IG:"([^"]+)""#),
              let iid = bingMatch(html, pattern: #"IID:"([^"]+)""#)
                ?? bingMatch(html, pattern: #"data-iid="([^"]+)""#),
              let abuse = bingMatch(html, pattern: #"params_AbusePreventionHelper\s*=\s*\[([^\]]+)\]"#)
        else {
            throw TranslationError.engineFailed(.bing, "auth parse failed")
        }
        let parts = abuse.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        guard parts.count >= 2 else {
            throw TranslationError.engineFailed(.bing, "auth token missing")
        }
        let key = parts[0]
        let token = parts[1]
        var host = "www.bing.com"
        if let http = response as? HTTPURLResponse, let final = http.url?.host, final.hasSuffix("bing.com") {
            host = final
        }
        let auth = BingWebAuth(
            ig: ig,
            iid: iid,
            key: key,
            token: token,
            host: host,
            expiresAt: Date().addingTimeInterval(8 * 60)
        )
        bingAuthLock.lock()
        bingWebAuthCache = auth
        bingAuthLock.unlock()
        return auth
    }

    private static func bingMatch(_ text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text)
        else { return nil }
        return String(text[r])
    }

    private static func bingExtractText(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let arr = json as? [[String: Any]],
           let translations = arr.first?["translations"] as? [[String: Any]],
           let text = translations.first?["text"] as? String
        {
            return text
        }
        if let arr = json as? [Any],
           let first = arr.first as? [[String: Any]],
           let translations = first.first?["translations"] as? [[String: Any]],
           let text = translations.first?["text"] as? String
        {
            return text
        }
        if let arr = json as? [Any],
           let first = arr.first as? [String: Any],
           let translations = first["translations"] as? [[String: Any]],
           let text = translations.first?["text"] as? String
        {
            return text
        }
        return nil
    }

    private static func bingTarget(_ code: String) -> String {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch c {
        case "zh", "zh-cn", "zh-hans": return "zh-Hans"
        case "zh-tw", "zh-hk", "zh-hant": return "zh-Hant"
        default:
            if c.hasPrefix("zh") { return "zh-Hans" }
            if let dash = c.firstIndex(of: "-") { return String(c[..<dash]) }
            return String(c.prefix(8))
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
