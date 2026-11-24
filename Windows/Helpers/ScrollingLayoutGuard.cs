// BetterTG.Windows — prevent layout invalidation while the message list is scrolling
// (iOS equivalent: never invalidateLayout while scrolling)

using System;
using BetterTG.Windows.Services.Translation;

namespace BetterTG.Windows.Helpers
{
    /// <summary>
    /// Host wires ListView / ScrollViewer ViewChanged / PointerWheel to Begin/End.
    /// While scrolling, translation StateChanged handlers should only update text content,
    /// not request measure/arrange passes that thrash virtualization.
    /// </summary>
    public sealed class ScrollingLayoutGuard
    {
        public static ScrollingLayoutGuard Current { get; } = new ScrollingLayoutGuard();

        private int _depth;
        private DateTimeOffset _lastScrollUtc = DateTimeOffset.MinValue;

        /// <summary>Optional settle delay after last scroll event before allowing layout.</summary>
        public TimeSpan SettleDelay { get; set; } = TimeSpan.FromMilliseconds(120);

        public bool IsScrolling
        {
            get
            {
                if (_depth > 0) return true;
                return DateTimeOffset.UtcNow - _lastScrollUtc < SettleDelay;
            }
        }

        public void BeginScroll()
        {
            _depth++;
            _lastScrollUtc = DateTimeOffset.UtcNow;
            TranslationService.Current.IsListScrolling = true;
        }

        public void EndScroll()
        {
            if (_depth > 0) _depth--;
            _lastScrollUtc = DateTimeOffset.UtcNow;
            if (_depth == 0)
            {
                // Keep IsListScrolling true until settle delay elapses; host may poll IsScrolling.
                TranslationService.Current.IsListScrolling = IsScrolling;
            }
        }

        public void NotifyScroll()
        {
            _lastScrollUtc = DateTimeOffset.UtcNow;
            TranslationService.Current.IsListScrolling = true;
        }

        /// <summary>
        /// Call from translation UI binder: if true, update TextBlock.Text only;
        /// do not change visibility of extra bilingual rows or force remeasure.
        /// </summary>
        public bool ShouldDeferLayoutChanges => IsScrolling;
    }
}
