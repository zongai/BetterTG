// BetterTG.Windows — message text presentation helper for auto-translate
// Host binds a TextBlock (or RichTextBlock) and calls Bind / Unbind.

using System;
using BetterTG.Windows.Helpers;
using BetterTG.Windows.Models;
using BetterTG.Windows.Services;
using BetterTG.Windows.Services.Translation;

namespace BetterTG.Windows.Controls
{
    /// <summary>
    /// Non-UI helper that decides what text to show for a message and when to
    /// request translation. Keeps layout rules (no measure while scrolling).
    /// </summary>
    public sealed class TranslatedMessagePresenter
    {
        private long _chatId;
        private long _messageId;
        private string _original = string.Empty;
        private Action<string>? _setText;
        private Action<string, string?>? _setBilingual; // original, translation
        private bool _subscribed;

        public void Bind(
            long chatId,
            long messageId,
            string originalText,
            Action<string> setText,
            Action<string, string?>? setBilingual = null)
        {
            Unbind();
            _chatId = chatId;
            _messageId = messageId;
            _original = originalText ?? string.Empty;
            _setText = setText;
            _setBilingual = setBilingual;

            TranslationService.Current.StateChanged += OnStateChanged;
            _subscribed = true;

            ApplyCurrentState();

            if (BetterTGSettings.Current.IsAutoTranslateEnabled(chatId) &&
                !string.IsNullOrWhiteSpace(_original))
            {
                _ = TranslationService.Current.TranslateMessageAsync(chatId, messageId, _original);
            }
        }

        public void Unbind()
        {
            if (_subscribed)
            {
                TranslationService.Current.StateChanged -= OnStateChanged;
                _subscribed = false;
            }
            _setText = null;
            _setBilingual = null;
        }

        public void ToggleOriginal()
        {
            TranslationService.Current.ToggleShowOriginal(_chatId, _messageId);
        }

        private void OnStateChanged(object? sender, MessageTranslationState state)
        {
            if (state.ChatId != _chatId || state.MessageId != _messageId)
                return;
            ApplyState(state);
        }

        private void ApplyCurrentState()
        {
            var state = TranslationService.Current.GetState(_chatId, _messageId);
            if (state != null)
                ApplyState(state);
            else
                _setText?.Invoke(_original);
        }

        private void ApplyState(MessageTranslationState state)
        {
            var bilingual = BetterTGSettings.Current.ShowBilingual;
            var deferLayout = ScrollingLayoutGuard.Current.ShouldDeferLayoutChanges;

            if (state.IsTranslating)
            {
                _setText?.Invoke("翻译中…");
                return;
            }

            if (bilingual && !string.IsNullOrEmpty(state.TranslatedText) && _setBilingual != null)
            {
                if (deferLayout)
                {
                    // While scrolling: only update primary text, do not toggle bilingual rows.
                    _setText?.Invoke(state.ShowOriginal ? state.OriginalText : state.TranslatedText!);
                }
                else
                {
                    _setBilingual(state.OriginalText, state.TranslatedText);
                }
                return;
            }

            _setText?.Invoke(state.DisplayText);
        }
    }
}
