// BetterTG.Windows — group/channel full-width bubbles; private chat keeps ~82%

using BetterTG.Windows.Services;

namespace BetterTG.Windows.Helpers
{
    /// <summary>
    /// Chat type classification for bubble width. Map TDLib ChatType* to these values
    /// at the call site so this helper stays free of TDLib references.
    /// </summary>
    public enum BetterTGChatKind
    {
        Private,
        BasicGroup,
        Supergroup,
        Channel,
        Secret
    }

    public static class MessageBubbleLayoutHelper
    {
        /// <summary>Private / secret bubble max width ratio (matches iOS ~82%).</summary>
        public const double PrivateBubbleWidthRatio = 0.82;

        /// <summary>Group / channel near-full width ratio.</summary>
        public const double GroupBubbleWidthRatio = 0.96;

        /// <summary>
        /// Returns the max width fraction of the available message column
        /// for the given chat kind, respecting the FullWidthBubblesInGroups setting.
        /// </summary>
        public static double GetBubbleWidthRatio(BetterTGChatKind kind)
        {
            var settings = BetterTGSettings.Current;
            switch (kind)
            {
                case BetterTGChatKind.BasicGroup:
                case BetterTGChatKind.Supergroup:
                case BetterTGChatKind.Channel:
                    return settings.FullWidthBubblesInGroups
                        ? GroupBubbleWidthRatio
                        : PrivateBubbleWidthRatio;
                default:
                    return PrivateBubbleWidthRatio;
            }
        }

        /// <summary>
        /// Absolute max width in pixels given the available content width.
        /// </summary>
        public static double GetMaxBubbleWidth(double availableWidth, BetterTGChatKind kind)
        {
            if (availableWidth <= 0) return 0;
            return availableWidth * GetBubbleWidthRatio(kind);
        }

        /// <summary>
        /// Font size scale from settings (0.85–1.50). Multiply Unigram base message font by this.
        /// </summary>
        public static double GetMessageFontScale() => BetterTGSettings.Current.MessageFontScale;
    }
}
