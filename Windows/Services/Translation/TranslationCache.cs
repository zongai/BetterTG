// BetterTG.Windows — text-level SHA256 translation cache (cross-message reuse)

using System;
using System.Collections.Concurrent;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation
{
    /// <summary>
    /// In-memory + optional disk-backed cache keyed by SHA256(text + targetLang).
    /// Matches iOS BetterTG text-level cache behaviour.
    /// </summary>
    public sealed class TranslationCache
    {
        public static TranslationCache Current { get; } = new TranslationCache();

        private readonly ConcurrentDictionary<string, CacheEntry> _memory = new();
        private readonly string? _diskPath;
        private readonly SemaphoreSlim _diskLock = new(1, 1);
        private const int MaxMemoryEntries = 5000;

        private TranslationCache()
        {
#if WINDOWS_UWP || WINUI
            try
            {
                var folder = Windows.Storage.ApplicationData.Current.LocalFolder.Path;
                _diskPath = Path.Combine(folder, "BetterTG.Fork", "translation-cache.json");
            }
            catch
            {
                _diskPath = null;
            }
#else
            _diskPath = Path.Combine(Path.GetTempPath(), "BetterTG.Fork", "translation-cache.json");
#endif
        }

        public static string ComputeKey(string text, string targetLanguage)
        {
            var payload = (text ?? string.Empty) + "\n" + (targetLanguage ?? string.Empty).ToLowerInvariant();
            var hash = SHA256.HashData(Encoding.UTF8.GetBytes(payload));
            return Convert.ToHexString(hash);
        }

        public bool TryGet(string text, string targetLanguage, out TranslationResult? result)
        {
            result = null;
            if (!BetterTGSettings.Current.TranslationCacheEnabled)
                return false;

            var key = ComputeKey(text, targetLanguage);
            if (_memory.TryGetValue(key, out var entry) && entry.IsValid)
            {
                result = TranslationResult.Ok(entry.TranslatedText, entry.Engine, entry.DetectedSource, fromCache: true);
                return true;
            }
            return false;
        }

        public void Set(string text, string targetLanguage, TranslationResult result)
        {
            if (!BetterTGSettings.Current.TranslationCacheEnabled || !result.Success || string.IsNullOrEmpty(result.TranslatedText))
                return;

            var key = ComputeKey(text, targetLanguage);
            var entry = new CacheEntry
            {
                TranslatedText = result.TranslatedText!,
                Engine = result.EngineUsed ?? TranslationEngineId.Google,
                DetectedSource = result.DetectedSourceLanguage,
                StoredAt = DateTimeOffset.UtcNow
            };

            _memory[key] = entry;

            // Soft bound
            if (_memory.Count > MaxMemoryEntries)
            {
                // Drop arbitrary older entries (simple approach)
                var n = 0;
                foreach (var k in _memory.Keys)
                {
                    if (n++ > 500) break;
                    _memory.TryRemove(k, out _);
                }
            }
        }

        public void Clear()
        {
            _memory.Clear();
            if (_diskPath != null && File.Exists(_diskPath))
            {
                try { File.Delete(_diskPath); } catch { /* ignore */ }
            }
        }

        public int Count => _memory.Count;

        public async Task PersistAsync(CancellationToken ct = default)
        {
            if (_diskPath == null) return;
            await _diskLock.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                var dir = Path.GetDirectoryName(_diskPath);
                if (!string.IsNullOrEmpty(dir))
                    Directory.CreateDirectory(dir);

                var snapshot = _memory.ToArray();
                var dto = new PersistDto();
                foreach (var kv in snapshot)
                {
                    if (kv.Value.IsValid)
                        dto.Entries[kv.Key] = kv.Value;
                }

                var json = JsonSerializer.Serialize(dto);
                await File.WriteAllTextAsync(_diskPath, json, ct).ConfigureAwait(false);
            }
            catch
            {
                // best-effort
            }
            finally
            {
                _diskLock.Release();
            }
        }

        public async Task LoadAsync(CancellationToken ct = default)
        {
            if (_diskPath == null || !File.Exists(_diskPath)) return;
            await _diskLock.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                var json = await File.ReadAllTextAsync(_diskPath, ct).ConfigureAwait(false);
                var dto = JsonSerializer.Deserialize<PersistDto>(json);
                if (dto?.Entries == null) return;
                foreach (var kv in dto.Entries)
                {
                    if (kv.Value.IsValid)
                        _memory[kv.Key] = kv.Value;
                }
            }
            catch
            {
                // ignore corrupt cache
            }
            finally
            {
                _diskLock.Release();
            }
        }

        private sealed class CacheEntry
        {
            public string TranslatedText { get; set; } = string.Empty;
            public TranslationEngineId Engine { get; set; }
            public string? DetectedSource { get; set; }
            public DateTimeOffset StoredAt { get; set; }

            // 30-day soft expiry
            public bool IsValid =>
                !string.IsNullOrEmpty(TranslatedText) &&
                DateTimeOffset.UtcNow - StoredAt < TimeSpan.FromDays(30);
        }

        private sealed class PersistDto
        {
            public Dictionary<string, CacheEntry> Entries { get; set; } = new();
        }
    }
}
