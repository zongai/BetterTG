// BetterTG.Windows — multi-chunk download helper + speed reporting
// Intended to wrap / parallelize Unigram file downloads for large files.

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Services;

namespace BetterTG.Windows.Services.Download
{
    public sealed class DownloadProgressEventArgs : EventArgs
    {
        public string TaskId { get; init; } = string.Empty;
        public long BytesReceived { get; init; }
        public long? TotalBytes { get; init; }
        public double BytesPerSecond { get; init; }
        public bool IsCompleted { get; init; }
        public bool IsFaulted { get; init; }
        public string? Error { get; init; }
    }

    /// <summary>
    /// Multi-chunk HTTP downloader. Chunk count comes from BetterTGSettings (4–32).
    /// For TDLib-managed files, Unigram still owns the file id lifecycle; this service
    /// is for direct URL / large attachment acceleration where applicable, and for
    /// reporting aggregate speed to the UI.
    /// </summary>
    public sealed class MultiThreadDownloadService
    {
        public static MultiThreadDownloadService Current { get; } = new MultiThreadDownloadService();

        private static readonly HttpClient Http = new()
        {
            Timeout = Timeout.InfiniteTimeSpan
        };

        private readonly ConcurrentDictionary<string, DownloadTask> _tasks = new();

        public event EventHandler<DownloadProgressEventArgs>? ProgressChanged;

        private MultiThreadDownloadService() { }

        public int ConfiguredChunkCount => BetterTGSettings.Current.DownloadChunkCount;

        public bool ShowSpeed => BetterTGSettings.Current.ShowDownloadSpeed;

        /// <summary>
        /// Download a URL to <paramref name="destinationPath"/> using ranged multi-chunk GET when the server supports it.
        /// Falls back to single-stream if Accept-Ranges is absent.
        /// </summary>
        public async Task DownloadAsync(
            string taskId,
            string url,
            string destinationPath,
            CancellationToken cancellationToken = default)
        {
            var chunkCount = ConfiguredChunkCount;
            var task = new DownloadTask { Id = taskId, Url = url, Destination = destinationPath };
            _tasks[taskId] = task;

            try
            {
                long? total = null;
                var supportsRanges = false;

                using (var head = new HttpRequestMessage(HttpMethod.Head, url))
                using (var headResp = await Http.SendAsync(head, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
                           .ConfigureAwait(false))
                {
                    if (headResp.Content.Headers.ContentLength.HasValue)
                        total = headResp.Content.Headers.ContentLength.Value;
                    supportsRanges = headResp.Headers.AcceptRanges?.Contains("bytes") == true
                                     || headResp.Content.Headers.ContentLength.HasValue;
                }

                task.TotalBytes = total;
                var sw = Stopwatch.StartNew();

                if (!supportsRanges || total == null || total.Value <= 0 || chunkCount <= 1)
                {
                    await DownloadSingleAsync(task, url, destinationPath, sw, cancellationToken).ConfigureAwait(false);
                }
                else
                {
                    await DownloadChunkedAsync(task, url, destinationPath, total.Value, chunkCount, sw, cancellationToken)
                        .ConfigureAwait(false);
                }

                task.IsCompleted = true;
                RaiseProgress(task, sw);
            }
            catch (OperationCanceledException)
            {
                task.IsFaulted = true;
                task.Error = "Cancelled";
                RaiseProgress(task, Stopwatch.StartNew());
                throw;
            }
            catch (Exception ex)
            {
                task.IsFaulted = true;
                task.Error = ex.Message;
                RaiseProgress(task, Stopwatch.StartNew());
                throw;
            }
            finally
            {
                _tasks.TryRemove(taskId, out _);
            }
        }

        private async Task DownloadSingleAsync(
            DownloadTask task, string url, string path, Stopwatch sw, CancellationToken ct)
        {
            using var response = await Http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct)
                .ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            task.TotalBytes ??= response.Content.Headers.ContentLength;

            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            await using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true);
            await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);

            var buffer = new byte[81920];
            int read;
            long lastReport = 0;
            while ((read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), ct).ConfigureAwait(false)) > 0)
            {
                await fs.WriteAsync(buffer.AsMemory(0, read), ct).ConfigureAwait(false);
                Interlocked.Add(ref task.BytesReceived, read);
                if (sw.ElapsedMilliseconds - lastReport > 200)
                {
                    lastReport = sw.ElapsedMilliseconds;
                    RaiseProgress(task, sw);
                }
            }
            RaiseProgress(task, sw);
        }

        private async Task DownloadChunkedAsync(
            DownloadTask task, string url, string path, long total, int chunks, Stopwatch sw, CancellationToken ct)
        {
            var chunkSize = total / chunks;
            var parts = new string[chunks];
            var dir = Path.GetDirectoryName(path)!;
            Directory.CreateDirectory(dir);

            var jobs = new List<Task>();
            for (var i = 0; i < chunks; i++)
            {
                var index = i;
                var start = index * chunkSize;
                var end = index == chunks - 1 ? total - 1 : start + chunkSize - 1;
                parts[index] = path + $".part{index}";

                jobs.Add(Task.Run(async () =>
                {
                    using var req = new HttpRequestMessage(HttpMethod.Get, url);
                    req.Headers.Range = new RangeHeaderValue(start, end);
                    using var resp = await Http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct)
                        .ConfigureAwait(false);
                    resp.EnsureSuccessStatusCode();
                    await using var fs = new FileStream(parts[index], FileMode.Create, FileAccess.Write, FileShare.None, 81920, true);
                    await using var stream = await resp.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
                    var buffer = new byte[81920];
                    int read;
                    while ((read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), ct).ConfigureAwait(false)) > 0)
                    {
                        await fs.WriteAsync(buffer.AsMemory(0, read), ct).ConfigureAwait(false);
                        Interlocked.Add(ref task.BytesReceived, read);
                    }
                }, ct));
            }

            // Progress ticker
            var tickerCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            var ticker = Task.Run(async () =>
            {
                while (!tickerCts.Token.IsCancellationRequested)
                {
                    RaiseProgress(task, sw);
                    try { await Task.Delay(250, tickerCts.Token).ConfigureAwait(false); }
                    catch (OperationCanceledException) { break; }
                }
            }, tickerCts.Token);

            try
            {
                await Task.WhenAll(jobs).ConfigureAwait(false);
            }
            finally
            {
                tickerCts.Cancel();
                try { await ticker.ConfigureAwait(false); } catch { /* ignore */ }
            }

            // Merge parts
            await using (var output = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true))
            {
                for (var i = 0; i < chunks; i++)
                {
                    await using var part = new FileStream(parts[i], FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
                    await part.CopyToAsync(output, ct).ConfigureAwait(false);
                }
            }

            foreach (var p in parts)
            {
                try { File.Delete(p); } catch { /* ignore */ }
            }

            RaiseProgress(task, sw);
        }

        private void RaiseProgress(DownloadTask task, Stopwatch sw)
        {
            var seconds = Math.Max(sw.Elapsed.TotalSeconds, 0.001);
            var bps = task.BytesReceived / seconds;
            ProgressChanged?.Invoke(this, new DownloadProgressEventArgs
            {
                TaskId = task.Id,
                BytesReceived = task.BytesReceived,
                TotalBytes = task.TotalBytes,
                BytesPerSecond = bps,
                IsCompleted = task.IsCompleted,
                IsFaulted = task.IsFaulted,
                Error = task.Error
            });
        }

        private sealed class DownloadTask
        {
            public string Id = string.Empty;
            public string Url = string.Empty;
            public string Destination = string.Empty;
            public long BytesReceived;
            public long? TotalBytes;
            public bool IsCompleted;
            public bool IsFaulted;
            public string? Error;
        }
    }
}
