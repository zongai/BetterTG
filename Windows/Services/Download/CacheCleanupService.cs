// BetterTG.Windows — cache cleanup by age and total size

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Services;

namespace BetterTG.Windows.Services.Download
{
    public sealed class CacheCleanupResult
    {
        public int FilesRemoved { get; init; }
        public long BytesFreed { get; init; }
    }

    /// <summary>
    /// Applies BetterTG cache policy (max age days / max size MB) to a directory tree.
    /// Call with Unigram's media/cache folders; does not touch TDLib database files.
    /// </summary>
    public sealed class CacheCleanupService
    {
        public static CacheCleanupService Current { get; } = new CacheCleanupService();

        private CacheCleanupService() { }

        public async Task<CacheCleanupResult> CleanupAsync(
            IEnumerable<string> rootDirectories,
            CancellationToken cancellationToken = default)
        {
            var settings = BetterTGSettings.Current;
            var maxAge = TimeSpan.FromDays(Math.Max(0, settings.CacheMaxAgeDays));
            var maxBytes = (long)settings.CacheMaxSizeMb * 1024L * 1024L;

            var files = new List<FileInfo>();
            foreach (var root in rootDirectories)
            {
                if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
                    continue;
                try
                {
                    foreach (var path in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
                    {
                        cancellationToken.ThrowIfCancellationRequested();
                        try
                        {
                            files.Add(new FileInfo(path));
                        }
                        catch
                        {
                            // skip locked / inaccessible
                        }
                    }
                }
                catch
                {
                    // skip unreadable roots
                }
            }

            long freed = 0;
            var removed = 0;
            var now = DateTimeOffset.UtcNow;

            // 1) Age-based
            if (maxAge > TimeSpan.Zero)
            {
                foreach (var fi in files.ToList())
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    try
                    {
                        if (now - fi.LastWriteTimeUtc > maxAge)
                        {
                            var len = fi.Length;
                            fi.Delete();
                            freed += len;
                            removed++;
                            files.Remove(fi);
                        }
                    }
                    catch
                    {
                        // ignore
                    }
                }
            }

            // 2) Size-based (oldest first)
            if (maxBytes > 0)
            {
                var total = files.Sum(f =>
                {
                    try { return f.Exists ? f.Length : 0L; }
                    catch { return 0L; }
                });

                if (total > maxBytes)
                {
                    foreach (var fi in files.OrderBy(f => f.LastWriteTimeUtc))
                    {
                        if (total <= maxBytes) break;
                        cancellationToken.ThrowIfCancellationRequested();
                        try
                        {
                            if (!fi.Exists) continue;
                            var len = fi.Length;
                            fi.Delete();
                            total -= len;
                            freed += len;
                            removed++;
                        }
                        catch
                        {
                            // ignore
                        }
                    }
                }
            }

            await Task.Yield();
            return new CacheCleanupResult { FilesRemoved = removed, BytesFreed = freed };
        }

        public long EstimateDirectorySize(string root)
        {
            if (!Directory.Exists(root)) return 0;
            long total = 0;
            try
            {
                foreach (var path in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
                {
                    try { total += new FileInfo(path).Length; }
                    catch { /* ignore */ }
                }
            }
            catch
            {
                // ignore
            }
            return total;
        }
    }
}
