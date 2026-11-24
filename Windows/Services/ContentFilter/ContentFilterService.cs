// BetterTG.Windows — keyword blacklist / whitelist + hide sponsored messages

using System;
using System.Collections.Generic;
using System.Linq;
using BetterTG.Windows.Services;

namespace BetterTG.Windows.Services.ContentFilter
{
    /// <summary>
    /// Content filter. White list takes priority over black list.
    /// Only affects UI visibility; never mutates TDLib storage.
    /// </summary>
    public sealed class ContentFilterService
    {
        public static ContentFilterService Current { get; } = new ContentFilterService();

        private ContentFilterService() { }

        /// <summary>
        /// Returns true if the message text should be hidden by keyword filter.
        /// Whitelist match => never hide. Blacklist match => hide.
        /// </summary>
        public bool ShouldHideByKeywords(string? text)
        {
            var settings = BetterTGSettings.Current;
            if (!settings.ContentFilterEnabled)
                return false;
            if (string.IsNullOrEmpty(text))
                return false;

            var white = settings.GetWhitelist();
            var black = settings.GetBlacklist();

            if (white.Count > 0 && ContainsAny(text, white))
                return false;

            if (black.Count > 0 && ContainsAny(text, black))
                return true;

            return false;
        }

        /// <summary>
        /// Whether sponsored / ad messages should be suppressed.
        /// Call when Unigram is about to show a sponsored message.
        /// </summary>
        public bool ShouldHideSponsoredMessage()
        {
            return BetterTGSettings.Current.HideAds;
        }

        /// <summary>
        /// Combined check for a chat message about to be rendered.
        /// <paramref name="isSponsored"/> should be true for TDLib sponsored message types.
        /// </summary>
        public bool ShouldHideMessage(string? text, bool isSponsored)
        {
            if (isSponsored && ShouldHideSponsoredMessage())
                return true;
            return ShouldHideByKeywords(text);
        }

        private static bool ContainsAny(string text, IReadOnlyList<string> keywords)
        {
            // Case-insensitive substring match; one keyword per list entry.
            foreach (var kw in keywords)
            {
                if (string.IsNullOrWhiteSpace(kw)) continue;
                if (text.IndexOf(kw, StringComparison.OrdinalIgnoreCase) >= 0)
                    return true;
            }
            return false;
        }
    }
}
