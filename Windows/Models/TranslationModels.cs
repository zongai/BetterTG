// BetterTG.Windows — translation result & request models

using System;

namespace BetterTG.Windows.Models
{
    public sealed class TranslationRequest
    {
        public string Text { get; init; } = string.Empty;
        public string? SourceLanguage { get; init; }
        public string TargetLanguage { get; init; } = BetterTGConstants.DefaultTargetLanguage;
        public long? ChatId { get; init; }
        public long? MessageId { get; init; }
    }

    public sealed class TranslationResult
    {
        public bool Success { get; init; }
        public string? TranslatedText { get; init; }
        public string? DetectedSourceLanguage { get; init; }
        public TranslationEngineId? EngineUsed { get; init; }
        public string? ErrorMessage { get; init; }
        public bool FromCache { get; init; }

        public static TranslationResult Fail(string message) => new()
        {
            Success = false,
            ErrorMessage = message
        };

        public static TranslationResult Ok(string text, TranslationEngineId engine, string? detected = null, bool fromCache = false) => new()
        {
            Success = true,
            TranslatedText = text,
            EngineUsed = engine,
            DetectedSourceLanguage = detected,
            FromCache = fromCache
        };
    }

    /// <summary>
    /// Per-message UI state for auto-translate display.
    /// Kept separate from TDLib message objects so core protocol is untouched.
    /// </summary>
    public sealed class MessageTranslationState
    {
        public long ChatId { get; init; }
        public long MessageId { get; init; }
        public string OriginalText { get; init; } = string.Empty;
        public string? TranslatedText { get; set; }
        public bool IsTranslating { get; set; }
        public bool ShowOriginal { get; set; }
        public TranslationEngineId? EngineUsed { get; set; }
        public string? Error { get; set; }
        public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

        public string DisplayText
        {
            get
            {
                if (IsTranslating)
                    return "翻译中…";
                if (!string.IsNullOrEmpty(Error))
                    return OriginalText;
                if (string.IsNullOrEmpty(TranslatedText))
                    return OriginalText;
                return ShowOriginal ? OriginalText : TranslatedText;
            }
        }
    }
}
