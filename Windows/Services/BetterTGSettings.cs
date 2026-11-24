// BetterTG.Windows — persistent settings (ApplicationData LocalSettings)
// Pattern aligned with Unigram SettingsServiceBase; isolated container BetterTG.Fork.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using BetterTG.Windows.Models;

#if WINDOWS_UWP || WINUI
using Windows.Storage;
#endif

namespace BetterTG.Windows.Services
{
    /// <summary>
    /// Fork settings store. Uses its own ApplicationData container so it never
    /// collides with Unigram core keys or the iOS client.
    /// </summary>
    public sealed class BetterTGSettings
    {
        public static BetterTGSettings Current { get; } = new BetterTGSettings();

#if WINDOWS_UWP || WINUI
        private readonly ApplicationDataContainer _container;

        private BetterTGSettings()
        {
            _container = ApplicationData.Current.LocalSettings
                .CreateContainer(BetterTGConstants.SettingsContainerName, ApplicationDataCreateDisposition.Always);
        }

        private T Get<T>(string key, T defaultValue)
        {
            if (_container.Values.TryGetValue(key, out var raw) && raw is T t)
                return t;
            // boxed numeric / string fallbacks
            if (raw != null)
            {
                try
                {
                    return (T)Convert.ChangeType(raw, typeof(T));
                }
                catch
                {
                    // ignore
                }
            }
            return defaultValue;
        }

        private void Set(string key, object value)
        {
            _container.Values[key] = value;
        }
#else
        // Design-time / non-Windows fallback (in-memory) so the library still type-checks on Linux CI.
        private readonly Dictionary<string, object> _mem = new();

        private BetterTGSettings() { }

        private T Get<T>(string key, T defaultValue)
        {
            if (_mem.TryGetValue(key, out var raw) && raw is T t)
                return t;
            if (raw != null)
            {
                try { return (T)Convert.ChangeType(raw, typeof(T)); }
                catch { /* ignore */ }
            }
            return defaultValue;
        }

        private void Set(string key, object value) => _mem[key] = value;
#endif

        // ── Auto-translate ──────────────────────────────────────────────

        public bool AutoTranslateEnabled
        {
            get => Get(BetterTGConstants.AutoTranslateEnabled, false);
            set => Set(BetterTGConstants.AutoTranslateEnabled, value);
        }

        public bool ShowBilingual
        {
            get => Get(BetterTGConstants.ShowBilingual, true);
            set => Set(BetterTGConstants.ShowBilingual, value);
        }

        public string TargetLanguage
        {
            get => Get(BetterTGConstants.TargetLanguage, BetterTGConstants.DefaultTargetLanguage);
            set => Set(BetterTGConstants.TargetLanguage, value ?? BetterTGConstants.DefaultTargetLanguage);
        }

        public string EngineOrder
        {
            get => Get(BetterTGConstants.EngineOrder, BetterTGConstants.DefaultEngineOrder);
            set => Set(BetterTGConstants.EngineOrder, value ?? BetterTGConstants.DefaultEngineOrder);
        }

        public IReadOnlyList<TranslationEngineId> GetEngineOrderList()
        {
            var order = EngineOrder.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var list = new List<TranslationEngineId>();
            foreach (var s in order)
            {
                if (Enum.TryParse<TranslationEngineId>(s, true, out var id))
                    list.Add(id);
            }
            if (list.Count == 0)
            {
                list.AddRange(new[]
                {
                    TranslationEngineId.Google,
                    TranslationEngineId.Bing,
                    TranslationEngineId.DeepL,
                    TranslationEngineId.Azure,
                    TranslationEngineId.MyMemory
                });
            }
            return list;
        }

        public void SetEngineOrderList(IEnumerable<TranslationEngineId> engines)
        {
            EngineOrder = string.Join(",", engines.Select(e => e.ToString().ToLowerInvariant()));
        }

        public bool IsEngineEnabled(TranslationEngineId id)
        {
            return Get(BetterTGConstants.EngineEnabled + id.ToString().ToLowerInvariant(), true);
        }

        public void SetEngineEnabled(TranslationEngineId id, bool enabled)
        {
            Set(BetterTGConstants.EngineEnabled + id.ToString().ToLowerInvariant(), enabled);
        }

        /// <summary>DeepL API keys, one per line or comma-separated; rotation on failure.</summary>
        public string DeepLKeys
        {
            get => Get(BetterTGConstants.DeepLKeys, string.Empty);
            set => Set(BetterTGConstants.DeepLKeys, value ?? string.Empty);
        }

        public IReadOnlyList<string> GetDeepLKeyList()
        {
            return DeepLKeys
                .Split(new[] { '\n', '\r', ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(s => s.Length > 0)
                .ToList();
        }

        public string AzureKey
        {
            get => Get(BetterTGConstants.AzureKey, string.Empty);
            set => Set(BetterTGConstants.AzureKey, value ?? string.Empty);
        }

        public string AzureRegion
        {
            get => Get(BetterTGConstants.AzureRegion, "eastasia");
            set => Set(BetterTGConstants.AzureRegion, value ?? "eastasia");
        }

        public bool TranslationCacheEnabled
        {
            get => Get(BetterTGConstants.TranslationCacheEnabled, true);
            set => Set(BetterTGConstants.TranslationCacheEnabled, value);
        }

        /// <summary>
        /// Per-chat override: chatId -> enabled (null = use global).
        /// Serialized as JSON object.
        /// </summary>
        public Dictionary<long, bool?> GetChatExceptions()
        {
            var json = Get(BetterTGConstants.ChatExceptions, "{}");
            try
            {
                var dict = JsonSerializer.Deserialize<Dictionary<string, bool?>>(json)
                           ?? new Dictionary<string, bool?>();
                return dict.ToDictionary(kv => long.Parse(kv.Key), kv => kv.Value);
            }
            catch
            {
                return new Dictionary<long, bool?>();
            }
        }

        public void SetChatExceptions(Dictionary<long, bool?> map)
        {
            var strKeys = map.ToDictionary(kv => kv.Key.ToString(), kv => kv.Value);
            Set(BetterTGConstants.ChatExceptions, JsonSerializer.Serialize(strKeys));
        }

        public void SetChatException(long chatId, bool? enabled)
        {
            var map = GetChatExceptions();
            if (enabled == null)
                map.Remove(chatId);
            else
                map[chatId] = enabled;
            SetChatExceptions(map);
        }

        /// <summary>Effective auto-translate for a chat: exception ?? global.</summary>
        public bool IsAutoTranslateEnabled(long chatId)
        {
            var map = GetChatExceptions();
            if (map.TryGetValue(chatId, out var overrideValue) && overrideValue.HasValue)
                return overrideValue.Value;
            return AutoTranslateEnabled;
        }

        public double MessageFontScale
        {
            get
            {
                var v = Get(BetterTGConstants.MessageFontScale, BetterTGConstants.DefaultFontScale);
                return Math.Clamp(v, BetterTGConstants.MinFontScale, BetterTGConstants.MaxFontScale);
            }
            set => Set(BetterTGConstants.MessageFontScale,
                Math.Clamp(value, BetterTGConstants.MinFontScale, BetterTGConstants.MaxFontScale));
        }

        // ── Content filter ──────────────────────────────────────────────

        public bool ContentFilterEnabled
        {
            get => Get(BetterTGConstants.ContentFilterEnabled, false);
            set => Set(BetterTGConstants.ContentFilterEnabled, value);
        }

        public bool HideAds
        {
            get => Get(BetterTGConstants.HideAds, false);
            set => Set(BetterTGConstants.HideAds, value);
        }

        public string BlacklistRaw
        {
            get => Get(BetterTGConstants.Blacklist, string.Empty);
            set => Set(BetterTGConstants.Blacklist, value ?? string.Empty);
        }

        public string WhitelistRaw
        {
            get => Get(BetterTGConstants.Whitelist, string.Empty);
            set => Set(BetterTGConstants.Whitelist, value ?? string.Empty);
        }

        public IReadOnlyList<string> GetBlacklist() => SplitList(BlacklistRaw);
        public IReadOnlyList<string> GetWhitelist() => SplitList(WhitelistRaw);

        public void SetBlacklist(IEnumerable<string> items) =>
            BlacklistRaw = string.Join("\n", items.Select(s => s.Trim()).Where(s => s.Length > 0));

        public void SetWhitelist(IEnumerable<string> items) =>
            WhitelistRaw = string.Join("\n", items.Select(s => s.Trim()).Where(s => s.Length > 0));

        private static List<string> SplitList(string raw) =>
            (raw ?? string.Empty)
                .Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(s => s.Length > 0)
                .ToList();

        // ── Download / cache ────────────────────────────────────────────

        public int DownloadChunkCount
        {
            get
            {
                var v = Get(BetterTGConstants.DownloadChunkCount, BetterTGConstants.DefaultChunkCount);
                return Math.Clamp(v, BetterTGConstants.MinChunkCount, BetterTGConstants.MaxChunkCount);
            }
            set => Set(BetterTGConstants.DownloadChunkCount,
                Math.Clamp(value, BetterTGConstants.MinChunkCount, BetterTGConstants.MaxChunkCount));
        }

        public int CacheMaxAgeDays
        {
            get => Get(BetterTGConstants.CacheMaxAgeDays, 30);
            set => Set(BetterTGConstants.CacheMaxAgeDays, Math.Max(0, value));
        }

        public int CacheMaxSizeMb
        {
            get => Get(BetterTGConstants.CacheMaxSizeMb, 2048);
            set => Set(BetterTGConstants.CacheMaxSizeMb, Math.Max(0, value));
        }

        public bool ShowDownloadSpeed
        {
            get => Get(BetterTGConstants.ShowDownloadSpeed, true);
            set => Set(BetterTGConstants.ShowDownloadSpeed, value);
        }

        // ── UI ──────────────────────────────────────────────────────────

        public bool FullWidthBubblesInGroups
        {
            get => Get(BetterTGConstants.FullWidthBubblesInGroups, true);
            set => Set(BetterTGConstants.FullWidthBubblesInGroups, value);
        }

        public bool HideChannelShareButton
        {
            get => Get(BetterTGConstants.HideChannelShareButton, true);
            set => Set(BetterTGConstants.HideChannelShareButton, value);
        }

        public void ClearAll()
        {
#if WINDOWS_UWP || WINUI
            _container.Values.Clear();
#else
            _mem.Clear();
#endif
        }
    }
}
