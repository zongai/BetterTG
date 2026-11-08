// BoostedFileDownload.swift
// Applies Download Boost to TDLib downloadFile (priority + optional parallel ranges).

import Foundation
import TDLibKit

/// Downloads a file using current `MultipartDownloadConfig` boost settings.
///
/// TDLib accepts `offset`/`limit` on `downloadFile`. For large files we issue
/// several concurrent range requests so the library fills the local file faster,
/// then issue a full download to ensure completion. If parallel requests fail,
/// falls back to a single full-file download.
enum BoostedFileDownload {
    /// 1 MiB — aligns with Telegram file part boundaries.
    private static let alignment: Int64 = 1024 * 1024

    static func download(
        client: TDClient,
        fileId: Int,
        expectedSize: Int64 = 0,
        synchronous: Bool = false
    ) async throws -> File {
        MultipartDownloadConfig.shared.applyFromSettings()
        let config = MultipartDownloadConfig.shared
        let parts = config.parts(forFileSize: expectedSize)
        let priority = config.priority

        if parts <= 1 || expectedSize < 2 * alignment {
            return try await client.downloadFile(
                fileId: fileId,
                limit: 0,
                offset: 0,
                priority: priority,
                synchronous: synchronous
            )
        }

        do {
            try await downloadParallel(
                client: client,
                fileId: fileId,
                size: expectedSize,
                parts: parts,
                priority: priority
            )
            // Ensure the file is fully present / marked complete.
            let file = try await client.downloadFile(
                fileId: fileId,
                limit: 0,
                offset: 0,
                priority: priority,
                synchronous: synchronous
            )
            return file
        } catch {
            return try await client.downloadFile(
                fileId: fileId,
                limit: 0,
                offset: 0,
                priority: priority,
                synchronous: synchronous
            )
        }
    }

    private static func downloadParallel(
        client: TDClient,
        fileId: Int,
        size: Int64,
        parts: Int,
        priority: Int
    ) async throws {
        var chunk = max(alignment, (size + Int64(parts) - 1) / Int64(parts))
        chunk = ((chunk + alignment - 1) / alignment) * alignment

        try await withThrowingTaskGroup(of: Void.self) { group in
            var offset: Int64 = 0
            while offset < size {
                let limit = min(chunk, size - offset)
                let capturedOffset = offset
                group.addTask {
                    _ = try await client.downloadFile(
                        fileId: fileId,
                        limit: limit,
                        offset: capturedOffset,
                        priority: priority,
                        synchronous: false
                    )
                }
                offset += limit
            }
            try await group.waitForAll()
        }
    }
}
