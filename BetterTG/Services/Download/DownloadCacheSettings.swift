// DownloadCacheSettings.swift

import Foundation

enum DownloadCacheSettings {
    private static let prefix = "BetterTG.fork.download."

    static var multiThreadDownload: Bool {
        get {
            if UserDefaults.standard.object(forKey: prefix + "multiThread") == nil { return true }
            return UserDefaults.standard.bool(forKey: prefix + "multiThread")
        }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "multiThread") }
    }

    /// Parallel parts for large file downloads (4...32).
    static var parallelParts: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: prefix + "parallelParts")
            if v == 0 { return 16 }
            return min(32, max(4, v))
        }
        set { UserDefaults.standard.set(min(32, max(4, newValue)), forKey: prefix + "parallelParts") }
    }

    static var autoCleanupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: prefix + "autoCleanup") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "autoCleanup") }
    }

    static var keepDays: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: prefix + "keepDays")
            return v == 0 ? 7 : max(1, v)
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: prefix + "keepDays") }
    }

    static var maxCacheMB: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: prefix + "maxCacheMB")
            return v == 0 ? 2048 : max(64, v)
        }
        set { UserDefaults.standard.set(max(64, newValue), forKey: prefix + "maxCacheMB") }
    }

    private static let lastCleanupKey = "BetterTG.fork.download.lastCleanup"

    static var lastCleanupAt: Date? {
        get { UserDefaults.standard.object(forKey: lastCleanupKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastCleanupKey) }
    }

    /// Apply multipart config and optionally run cleanup (call on foreground).
    @MainActor
    static func applyOnForeground() {
        MultipartDownloadConfig.shared.applyFromSettings()
        guard autoCleanupEnabled else { return }
        let now = Date()
        if let last = lastCleanupAt, now.timeIntervalSince(last) < 6 * 3600 { return }
        lastCleanupAt = now
        DownloadCacheCleaner.shared.cleanupIfNeeded()
    }
}

enum MultipartDownloadConfig {
    static let shared = MultipartDownloadConfig()
    private init() {}

    private(set) var parallelParts: Int = 16
    private(set) var enabled: Bool = true

    func applyFromSettings() {
        enabled = DownloadCacheSettings.multiThreadDownload
        parallelParts = DownloadCacheSettings.parallelParts
    }

    /// Effective parallel part count for a given file size.
    func parts(forFileSize size: Int64) -> Int {
        guard enabled else { return 1 }
        if size < 2 * 1024 * 1024 { return 1 }
        if size < 16 * 1024 * 1024 { return min(4, parallelParts) }
        return parallelParts
    }
}

@MainActor
final class DownloadCacheCleaner {
    static let shared = DownloadCacheCleaner()
    private init() {}

    func cleanupIfNeeded() {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(DownloadCacheSettings.keepDays) * 86400)
        let maxBytes = Int64(DownloadCacheSettings.maxCacheMB) * 1024 * 1024
        let roots: [URL] = [
            fm.temporaryDirectory,
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
        ].compactMap { $0 }

        var files: [(url: URL, size: Int64, modified: Date)] = []
        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            while let item = enumerator.nextObject() as? URL {
                guard let values = try? item.resourceValues(forKeys: [
                    .isRegularFileKey, .contentModificationDateKey, .fileSizeKey,
                ]),
                    values.isRegularFile == true
                else { continue }
                let modified = values.contentModificationDate ?? .distantPast
                let size = Int64(values.fileSize ?? 0)
                files.append((item, size, modified))
            }
        }

        // Delete expired first.
        for f in files where f.modified < cutoff {
            try? fm.removeItem(at: f.url)
        }

        // Enforce size budget (oldest first).
        let remaining = files.filter { (try? $0.url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
        var total = remaining.reduce(Int64(0)) { $0 + $1.size }
        if total <= maxBytes { return }
        for f in remaining.sorted(by: { $0.modified < $1.modified }) {
            if total <= maxBytes { break }
            try? fm.removeItem(at: f.url)
            total -= f.size
        }
    }
}
