// BetterTG.Windows — Azure Translator (requires key + region)

using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation.Engines
{
    public sealed class AzureTranslationEngine : ITranslationEngine
    {
        private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

        public TranslationEngineId Id => TranslationEngineId.Azure;
        public string DisplayName => "Azure";
        public bool RequiresApiKey => true;

        public bool IsConfigured
        {
            get
            {
                var s = BetterTGSettings.Current;
                return !string.IsNullOrWhiteSpace(s.AzureKey) && !string.IsNullOrWhiteSpace(s.AzureRegion);
            }
        }

        public async Task<TranslationResult> TranslateAsync(TranslationRequest request, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(request.Text))
                return TranslationResult.Fail("Empty text");

            var settings = BetterTGSettings.Current;
            if (string.IsNullOrWhiteSpace(settings.AzureKey))
                return TranslationResult.Fail("Azure: no API key");

            try
            {
                var region = string.IsNullOrWhiteSpace(settings.AzureRegion) ? "eastasia" : settings.AzureRegion;
                var to = NormalizeLang(request.TargetLanguage);
                var fromPart = string.IsNullOrEmpty(request.SourceLanguage)
                    ? string.Empty
                    : $"&from={Uri.EscapeDataString(NormalizeLang(request.SourceLanguage))}";

                var url =
                    $"https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to={Uri.EscapeDataString(to)}{fromPart}";

                var payload = JsonSerializer.Serialize(new[] { new { Text = request.Text } });
                using var content = new StringContent(payload, Encoding.UTF8, "application/json");
                using var msg = new HttpRequestMessage(HttpMethod.Post, url) { Content = content };
                msg.Headers.Add("Ocp-Apim-Subscription-Key", settings.AzureKey);
                msg.Headers.Add("Ocp-Apim-Subscription-Region", region);

                using var response = await Http.SendAsync(msg, cancellationToken).ConfigureAwait(false);
                var json = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                if (!response.IsSuccessStatusCode)
                    return TranslationResult.Fail($"Azure HTTP {(int)response.StatusCode}");

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Array || root.GetArrayLength() == 0)
                    return TranslationResult.Fail("Unexpected Azure response");

                var first = root[0];
                string? detected = null;
                if (first.TryGetProperty("detectedLanguage", out var dl) &&
                    dl.TryGetProperty("language", out var langEl))
                    detected = langEl.GetString();

                if (!first.TryGetProperty("translations", out var translations) ||
                    translations.GetArrayLength() == 0)
                    return TranslationResult.Fail("No Azure translations");

                var text = translations[0].GetProperty("text").GetString();
                if (string.IsNullOrEmpty(text))
                    return TranslationResult.Fail("Empty Azure translation");

                return TranslationResult.Ok(text, Id, detected);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                return TranslationResult.Fail("Azure: " + ex.Message);
            }
        }

        private static string NormalizeLang(string lang)
        {
            if (string.IsNullOrEmpty(lang)) return "en";
            if (lang.Equals("zh", StringComparison.OrdinalIgnoreCase)) return "zh-Hans";
            return lang;
        }
    }
}
