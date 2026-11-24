// BetterTG.Windows — hide channel inline share button (context menu forward remains)

using BetterTG.Windows.Services;

namespace BetterTG.Windows.Helpers
{
    /// <summary>
    /// Mirrors iOS MessageShareButton.kind → nil for non-saved messages in channels.
    /// Long-press / right-click forward must remain available in the host UI.
    /// </summary>
    public static class ShareButtonVisibilityHelper
    {
        /// <summary>
        /// Whether the inline (bubble-side) share / forward round button should be shown.
        /// </summary>
        /// <param name="kind">Chat classification.</param>
        /// <param name="isSavedMessages">True when the open chat is Saved Messages.</param>
        public static bool ShouldShowInlineShareButton(BetterTGChatKind kind, bool isSavedMessages)
        {
            if (isSavedMessages)
                return true;

            if (!BetterTGSettings.Current.HideChannelShareButton)
                return true;

            // Hide for channels (and optionally supergroups acting as channels).
            return kind != BetterTGChatKind.Channel;
        }
    }
}
