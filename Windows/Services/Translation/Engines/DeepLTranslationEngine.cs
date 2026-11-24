// BetterTG.Windows — DeepL API with multi-key rotation

using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation.Engines
{
    public sealed class DeepLTranslationEngine : ITranslationEngine
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };
        private int _keyIndex;

        public TranslationEngineId Id => TranslationEngineId.DeepL;
        public string DisplayName => "DeepL";
        public bool RequiresApiKey => true;

        public bool IsConfigured => BetterTGSettings.Current.GetDeepLKeyList().Count > 0;

        public async Task<TranslationResult> TranslateAsync(TranslationRequest request, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(request.Text))
                return TranslationResult.Fail("Empty text");

            var keys = BetterTGSettings.Current.GetDeepLKeyList();
            if (keys.Count == 0)
                return TranslationResult.Fail("DeepL: no API key configured");

            Exception? last = null;
            var attempts = Math.Min(keys.Count, 5);
            for (var i = 0; i < attempts; i++)
            {
                var key = keys[(_keyIndex + i) % keys.Count];
                try
                {
                    var result = await TranslateWithKeyAsync(request, key, cancellationToken).ConfigureAwait(false);
                    if (result.Success)
                    {
                        _keyIndex = (_keyIndex + i) % keys.Count;
                        return result;
                    }
                    last = new Exception(result.ErrorMessage);
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    last = ex;
                }
            }

            _keyIndex = (_keyIndex + 1) % keys.Count;
            return TranslationResult.Fail("DeepL: " + (last?.Message ?? "all keys failed"));
        }

        private static async Task<TranslationResult> TranslateWithKeyAsync(
            TranslationRequest request, string apiKey, CancellationToken ct)
        {
            // Free keys end with :fx and use api-free.deepl.com
            var isFree = apiKey.EndsWith(":fx", StringComparison.OrdinalIgnoreCase);
            var host = isFree ? "https://api-free.deepl.com" : "https://api.deepl.com";
            var url = host + "/v2/translate";

            var form = new Dictionary<string, string>
            {
                ["text"] = request.Text,
                ["target_lang"] = NormalizeLang(request.TargetLanguage)
            };
            if (!string.IsNullOrEmpty(request.SourceLanguage))
                form["source_lang"] = NormalizeLang(request.SourceLanguage);

            using var content = new FormUrlEncodedContent(form);
            using var msg = new HttpRequestMessage(HttpMethod.Post, url) { Content = content };
            msg.Headers.Authorization = new AuthenticationHeaderValue("DeepL-Auth-Key", apiKey);

            using var response = await Http.SendAsync(msg, ct).ConfigureAwait(false);
            var json = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);

            if (!response.IsSuccessStatusCode)
                return TranslationResult.Fail($"DeepL HTTP {(int)response.StatusCode}: {Truncate(json, 120)}");

            using var doc = JsonDocument.Parse(json);
            var translations = doc.RootElement.GetProperty("translations");
            if (translations.GetArrayLength() == 0)
                return TranslationResult.Fail("DeepL empty translations");

            var first = translations[0];
            var text = first.GetProperty("text").GetString();
            string? detected = null;
            if (first.TryGetProperty("detected_source_language", out var dsl))
                detected = dsl.GetString();

            if (string.IsNullOrEmpty(text))
                return TranslationResult.Fail("DeepL empty text");

            return TranslationResult.Ok(text, TranslationEngineId.DeepL, detected);
        }

        private static string NormalizeLang(string lang)
        {
            if (string.IsNullOrEmpty(lang)) return "EN";
            var u = lang.ToUpperInvariant();
            if (u is "ZH" or "ZH-CN" or "ZH-HANS") return "ZH";
            if (u is "ZH-TW" or "ZH-HANT") return "ZH";
            if (u.StartsWith("EN")) return "EN";
            if (u.Length > 2) return u.Substring(0, 2);
            return u;
        }

        private static string Truncate(string s, int n) =>
            string.IsNullOrEmpty(s) ? string.Empty : (s.Length <= n ? s : s.Substring(0, n));
    }
}
