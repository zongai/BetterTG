// BetterTG.Windows — MyMemory free API (no key, rate-limited)

using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation.Engines
{
    public sealed class MyMemoryTranslationEngine : ITranslationEngine
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(20) };

        public TranslationEngineId Id => TranslationEngineId.MyMemory;
        public string DisplayName => "MyMemory";
        public bool RequiresApiKey => false;
        public bool IsConfigured => true;

        public async Task<TranslationResult> TranslateAsync(TranslationRequest request, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(request.Text))
                return TranslationResult.Fail("Empty text");

            try
            {
                var from = string.IsNullOrEmpty(request.SourceLanguage) ? "autodetect" : request.SourceLanguage;
                var to = request.TargetLanguage;
                // MyMemory uses langpair like en|zh-CN
                var langpair = $"{Normalize(from)}|{Normalize(to)}";
                var url =
                    "https://api.mymemory.translated.net/get?q=" +
                    Uri.EscapeDataString(request.Text) +
                    "&langpair=" + Uri.EscapeDataString(langpair);

                using var response = await Http.GetAsync(url, cancellationToken).ConfigureAwait(false);
                var json = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                response.EnsureSuccessStatusCode();

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (!root.TryGetProperty("responseData", out var data))
                    return TranslationResult.Fail("MyMemory: no responseData");

                var text = data.GetProperty("translatedText").GetString();
                if (string.IsNullOrEmpty(text))
                    return TranslationResult.Fail("MyMemory empty");

                // Treat obvious error payloads as failure
                if (text.StartsWith("INVALID", StringComparison.OrdinalIgnoreCase) ||
                    text.Contains("QUERY LENGTH LIMIT", StringComparison.OrdinalIgnoreCase))
                    return TranslationResult.Fail("MyMemory: " + text);

                return TranslationResult.Ok(text, Id);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                return TranslationResult.Fail("MyMemory: " + ex.Message);
            }
        }

        private static string Normalize(string lang)
        {
            if (string.IsNullOrEmpty(lang) || lang.Equals("autodetect", StringComparison.OrdinalIgnoreCase))
                return "autodetect";
            if (lang.Equals("zh", StringComparison.OrdinalIgnoreCase))
                return "zh-CN";
            return lang;
        }
    }
}
