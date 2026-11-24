// BetterTG.Windows — orchestrates engine chain, cache, per-chat enablement

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;
using BetterTG.Windows.Services.Translation.Engines;

namespace BetterTG.Windows.Services.Translation
{
    /// <summary>
    /// Main auto-translate service. Does not touch TDLib; callers feed plain text
    /// and attach results to their own message UI state.
    /// </summary>
    public sealed class TranslationService
    {
        public static TranslationService Current { get; } = new TranslationService();

        private readonly IReadOnlyList<ITranslationEngine> _engines;
        private readonly ConcurrentDictionary<string, MessageTranslationState> _states = new();
        private readonly ConcurrentDictionary<string, SemaphoreSlim> _inflight = new();

        /// <summary>
        /// Raised when a message translation state changes (for UI binding).
        /// Handlers must not force layout invalidation while the list is scrolling.
        /// </summary>
        public event EventHandler<MessageTranslationState>? StateChanged;

        /// <summary>
        /// Host should set this while the message list is actively scrolling.
        /// When true, StateChanged still fires but UI should only update text, not measure.
        /// </summary>
        public bool IsListScrolling { get; set; }

        private TranslationService()
        {
            _engines = new ITranslationEngine[]
            {
                new GoogleTranslationEngine(),
                new BingTranslationEngine(),
                new DeepLTranslationEngine(),
                new AzureTranslationEngine(),
                new MyMemoryTranslationEngine()
            };
        }

        public IReadOnlyList<ITranslationEngine> Engines => _engines;

        public MessageTranslationState? GetState(long chatId, long messageId)
        {
            var key = StateKey(chatId, messageId);
            return _states.TryGetValue(key, out var s) ? s : null;
        }

        public void ClearState(long chatId, long messageId)
        {
            _states.TryRemove(StateKey(chatId, messageId), out _);
        }

        public void ToggleShowOriginal(long chatId, long messageId)
        {
            var key = StateKey(chatId, messageId);
            if (!_states.TryGetValue(key, out var state)) return;
            if (string.IsNullOrEmpty(state.TranslatedText)) return;
            state.ShowOriginal = !state.ShowOriginal;
            state.UpdatedAt = DateTimeOffset.UtcNow;
            StateChanged?.Invoke(this, state);
        }

        /// <summary>
        /// Translate a message if auto-translate is enabled for the chat.
        /// Safe to call repeatedly; concurrent calls for the same message coalesce.
        /// </summary>
        public async Task<MessageTranslationState> TranslateMessageAsync(
            long chatId,
            long messageId,
            string originalText,
            CancellationToken cancellationToken = default)
        {
            var key = StateKey(chatId, messageId);
            var settings = BetterTGSettings.Current;

            if (!settings.IsAutoTranslateEnabled(chatId))
            {
                var disabled = new MessageTranslationState
                {
                    ChatId = chatId,
                    MessageId = messageId,
                    OriginalText = originalText,
                    ShowOriginal = true
                };
                return disabled;
            }

            if (string.IsNullOrWhiteSpace(originalText))
            {
                return new MessageTranslationState
                {
                    ChatId = chatId,
                    MessageId = messageId,
                    OriginalText = originalText ?? string.Empty,
                    ShowOriginal = true
                };
            }

            if (_states.TryGetValue(key, out var existing) &&
                !existing.IsTranslating &&
                !string.IsNullOrEmpty(existing.TranslatedText) &&
                string.Equals(existing.OriginalText, originalText, StringComparison.Ordinal))
            {
                return existing;
            }

            var gate = _inflight.GetOrAdd(key, _ => new SemaphoreSlim(1, 1));
            await gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                if (_states.TryGetValue(key, out existing) &&
                    !existing.IsTranslating &&
                    !string.IsNullOrEmpty(existing.TranslatedText) &&
                    string.Equals(existing.OriginalText, originalText, StringComparison.Ordinal))
                {
                    return existing;
                }

                var state = new MessageTranslationState
                {
                    ChatId = chatId,
                    MessageId = messageId,
                    OriginalText = originalText,
                    IsTranslating = true,
                    ShowOriginal = false
                };
                _states[key] = state;
                StateChanged?.Invoke(this, state);

                var target = settings.TargetLanguage;
                if (TranslationCache.Current.TryGet(originalText, target, out var cached) && cached != null)
                {
                    state.IsTranslating = false;
                    state.TranslatedText = cached.TranslatedText;
                    state.EngineUsed = cached.EngineUsed;
                    state.ShowOriginal = false;
                    state.UpdatedAt = DateTimeOffset.UtcNow;
                    StateChanged?.Invoke(this, state);
                    return state;
                }

                var request = new TranslationRequest
                {
                    Text = originalText,
                    TargetLanguage = target,
                    ChatId = chatId,
                    MessageId = messageId
                };

                var result = await TranslateWithChainAsync(request, cancellationToken).ConfigureAwait(false);

                state.IsTranslating = false;
                if (result.Success)
                {
                    state.TranslatedText = result.TranslatedText;
                    state.EngineUsed = result.EngineUsed;
                    state.Error = null;
                    state.ShowOriginal = false;
                    TranslationCache.Current.Set(originalText, target, result);
                }
                else
                {
                    state.Error = result.ErrorMessage;
                    state.ShowOriginal = true;
                }
                state.UpdatedAt = DateTimeOffset.UtcNow;
                StateChanged?.Invoke(this, state);
                return state;
            }
            finally
            {
                gate.Release();
            }
        }

        /// <summary>Force translate regardless of auto-translate switch (e.g. context menu).</summary>
        public async Task<MessageTranslationState> ForceTranslateAsync(
            long chatId, long messageId, string originalText, CancellationToken ct = default)
        {
            ClearState(chatId, messageId);
            var settings = BetterTGSettings.Current;
            var prev = settings.GetChatExceptions();
            var had = prev.TryGetValue(chatId, out var old);
            settings.SetChatException(chatId, true);
            try
            {
                return await TranslateMessageAsync(chatId, messageId, originalText, ct).ConfigureAwait(false);
            }
            finally
            {
                if (had)
                    settings.SetChatException(chatId, old);
                else
                    settings.SetChatException(chatId, null);
            }
        }

        public async Task<TranslationResult> TranslateWithChainAsync(
            TranslationRequest request, CancellationToken cancellationToken = default)
        {
            var settings = BetterTGSettings.Current;
            var order = settings.GetEngineOrderList();

            foreach (var id in order)
            {
                if (!settings.IsEngineEnabled(id))
                    continue;

                var engine = _engines.FirstOrDefault(e => e.Id == id);
                if (engine == null || !engine.IsConfigured)
                    continue;

                try
                {
                    var result = await engine.TranslateAsync(request, cancellationToken).ConfigureAwait(false);
                    if (result.Success && !string.IsNullOrWhiteSpace(result.TranslatedText))
                        return result;
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch
                {
                    // try next engine
                }
            }

            return TranslationResult.Fail("All translation engines failed");
        }

        public void ClearCache()
        {
            TranslationCache.Current.Clear();
        }

        private static string StateKey(long chatId, long messageId) => chatId + ":" + messageId;
    }
}
