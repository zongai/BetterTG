// BetterTG.Windows — Google Translate (unofficial free endpoint, no key)

using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation.Engines
{
    public sealed class GoogleTranslationEngine : ITranslationEngine
    {
        private static readonly HttpClient Http = CreateClient();

        public TranslationEngineId Id => TranslationEngineId.Google;
        public string DisplayName => "Google";
        public bool RequiresApiKey => false;
        public bool IsConfigured => true;

        public async Task<TranslationResult> TranslateAsync(TranslationRequest request, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(request.Text))
                return TranslationResult.Fail("Empty text");

            try
            {
                var sl = string.IsNullOrEmpty(request.SourceLanguage) ? "auto" : request.SourceLanguage;
                var tl = request.TargetLanguage;
                var q = Uri.EscapeDataString(request.Text);
                // Public translate_a endpoint used by many open clients; subject to rate limits.
                var url =
                    $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={sl}&tl={tl}&dt=t&q={q}";

                using var response = await Http.GetAsync(url, cancellationToken).ConfigureAwait(false);
                response.EnsureSuccessStatusCode();
                var json = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Array || root.GetArrayLength() == 0)
                    return TranslationResult.Fail("Unexpected Google response");

                var segments = root[0];
                if (segments.ValueKind != JsonValueKind.Array)
                    return TranslationResult.Fail("Unexpected Google segments");

                var sb = new System.Text.StringBuilder();
                foreach (var seg in segments.EnumerateArray())
                {
                    if (seg.ValueKind == JsonValueKind.Array && seg.GetArrayLength() > 0)
                    {
                        var piece = seg[0].GetString();
                        if (piece != null)
                            sb.Append(piece);
                    }
                }

                string? detected = null;
                if (root.GetArrayLength() > 2 && root[2].ValueKind == JsonValueKind.String)
                    detected = root[2].GetString();

                var text = sb.ToString();
                if (string.IsNullOrEmpty(text))
                    return TranslationResult.Fail("Empty translation from Google");

                return TranslationResult.Ok(text, Id, detected);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                return TranslationResult.Fail("Google: " + ex.Message);
            }
        }

        private static HttpClient CreateClient()
        {
            var c = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
            c.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) BetterTG.Windows/1.0");
            return c;
        }
    }
}
