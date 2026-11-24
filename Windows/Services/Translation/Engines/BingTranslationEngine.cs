// BetterTG.Windows — Bing / Microsoft Translator free web path (no key)

using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation.Engines
{
    public sealed class BingTranslationEngine : ITranslationEngine
    {
        private static readonly HttpClient Http = CreateClient();
        private static string? _ig;
        private static string? _iid;
        private static string? _token;
        private static string? _key;
        private static DateTimeOffset _tokenExpiry = DateTimeOffset.MinValue;
        private static readonly SemaphoreSlim TokenLock = new(1, 1);

        public TranslationEngineId Id => TranslationEngineId.Bing;
        public string DisplayName => "Bing";
        public bool RequiresApiKey => false;
        public bool IsConfigured => true;

        public async Task<TranslationResult> TranslateAsync(TranslationRequest request, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(request.Text))
                return TranslationResult.Fail("Empty text");

            try
            {
                await EnsureTokenAsync(cancellationToken).ConfigureAwait(false);

                var from = string.IsNullOrEmpty(request.SourceLanguage) ? "auto-detect" : request.SourceLanguage;
                var to = NormalizeLang(request.TargetLanguage);

                var url =
                    $"https://www.bing.com/ttranslatev3?isVertical=1&&IG={_ig}&IID={_iid}";
                var body =
                    $"&fromLang={Uri.EscapeDataString(from)}&text={Uri.EscapeDataString(request.Text)}&to={Uri.EscapeDataString(to)}&token={Uri.EscapeDataString(_token ?? "")}&key={Uri.EscapeDataString(_key ?? "")}";

                using var content = new StringContent(body, Encoding.UTF8, "application/x-www-form-urlencoded");
                using var response = await Http.PostAsync(url, content, cancellationToken).ConfigureAwait(false);
                var json = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                if (!response.IsSuccessStatusCode)
                    return TranslationResult.Fail($"Bing HTTP {(int)response.StatusCode}");

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                // Response shape: [ { "translations": [ { "text": "..." } ], "detectedLanguage": { "language": "xx" } } ]
                if (root.ValueKind != JsonValueKind.Array || root.GetArrayLength() == 0)
                    return TranslationResult.Fail("Unexpected Bing response");

                var first = root[0];
                string? detected = null;
                if (first.TryGetProperty("detectedLanguage", out var dl) &&
                    dl.TryGetProperty("language", out var langEl))
                    detected = langEl.GetString();

                if (!first.TryGetProperty("translations", out var translations) ||
                    translations.ValueKind != JsonValueKind.Array ||
                    translations.GetArrayLength() == 0)
                    return TranslationResult.Fail("No Bing translations");

                var text = translations[0].GetProperty("text").GetString();
                if (string.IsNullOrEmpty(text))
                    return TranslationResult.Fail("Empty Bing translation");

                return TranslationResult.Ok(text, Id, detected);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                // Force token refresh next time
                _tokenExpiry = DateTimeOffset.MinValue;
                return TranslationResult.Fail("Bing: " + ex.Message);
            }
        }

        private static async Task EnsureTokenAsync(CancellationToken ct)
        {
            if (_token != null && DateTimeOffset.UtcNow < _tokenExpiry)
                return;

            await TokenLock.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                if (_token != null && DateTimeOffset.UtcNow < _tokenExpiry)
                    return;

                using var response = await Http.GetAsync("https://www.bing.com/translator", ct).ConfigureAwait(false);
                var html = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);

                _ig = Extract(html, "IG:\"", "\"") ?? Extract(html, "IG:'", "'");
                _iid = "translator.5023.1";
                _token = Extract(html, "params_AbusePreventionHelper = [", "]");
                if (_token != null)
                {
                    // params_AbusePreventionHelper = [key, token, ttl]
                    var parts = _token.Split(',');
                    if (parts.Length >= 2)
                    {
                        _key = parts[0].Trim().Trim('"', '\'', ' ');
                        _token = parts[1].Trim().Trim('"', '\'', ' ');
                        var ttlMs = 600000;
                        if (parts.Length >= 3 && int.TryParse(parts[2].Trim(), out var ttl))
                            ttlMs = ttl;
                        _tokenExpiry = DateTimeOffset.UtcNow.AddMilliseconds(ttlMs * 0.8);
                    }
                }

                if (string.IsNullOrEmpty(_token) || string.IsNullOrEmpty(_key))
                    throw new InvalidOperationException("Failed to obtain Bing abuse-prevention token");
            }
            finally
            {
                TokenLock.Release();
            }
        }

        private static string? Extract(string source, string start, string end)
        {
            var i = source.IndexOf(start, StringComparison.Ordinal);
            if (i < 0) return null;
            i += start.Length;
            var j = source.IndexOf(end, i, StringComparison.Ordinal);
            if (j < 0) return null;
            return source.Substring(i, j - i);
        }

        private static string NormalizeLang(string lang)
        {
            if (string.IsNullOrEmpty(lang)) return "en";
            if (lang.Equals("zh", StringComparison.OrdinalIgnoreCase) ||
                lang.Equals("zh-CN", StringComparison.OrdinalIgnoreCase))
                return "zh-Hans";
            if (lang.Equals("zh-TW", StringComparison.OrdinalIgnoreCase))
                return "zh-Hant";
            return lang;
        }

        private static HttpClient CreateClient()
        {
            var c = new HttpClient { Timeout = TimeSpan.FromSeconds(25) };
            c.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
            c.DefaultRequestHeaders.TryAddWithoutValidation("Referer", "https://www.bing.com/translator");
            return c;
        }
    }
}
