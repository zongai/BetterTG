// DownloadCacheSettings.swift

import Foundation

// MARK: - Download Boost

/// Four-tier boost approximating Swiftgram / Premium-client parallelism.
enum DownloadBoostLevel: String, CaseIterable, Codable, Sendable {
    case off
    case standard
    case high
    case extreme

    var title: String {
        switch self {
        case .off: "关闭"
        case .standard: "标准"
        case .high: "高"
        case .extreme: "极高"
        }
    }

    var detail: String {
        switch self {
        case .off: "单连接顺序下载"
        case .standard: "小并行，较稳"
        case .high: "接近 Premium 客户端"
        case .extreme: "最大并行，可能不稳定"
        }
    }

    /// Target parallel byte-range workers for large files.
    var parallelParts: Int {
        switch self {
        case .off: 1
        case .standard: 4
        case .high: 12
        case .extreme: 24
        }
    }

    /// TDLib downloadFile priority (1...32).
    var priority: Int {
        switch self {
        case .off: 8
        case .standard: 16
        case .high: 24
        case .extreme: 32
        }
    }

    /// Max simultaneous large-file downloads app-wide.
    var maxConcurrentLargeFiles: Int {
        switch self {
        case .off: 1
        case .standard: 2
        case .high: 2
        case .extreme: 3
        }
    }

    static func nearest(toParts parts: Int, enabled: Bool) -> DownloadBoostLevel {
        guard enabled, parts > 1 else { return .off }
        let candidates = DownloadBoostLevel.allCases.filter { $0 != .off }
        return candidates.min(by: { abs($0.parallelParts - parts) < abs($1.parallelParts - parts) }) ?? .high
    }
}

// MARK: - Settings

enum DownloadCacheSettings {
    private static let prefix = "BetterTG.fork.download."

    /// Primary boost control. Migrates from legacy multiThread + parallelParts when unset.
    static var boostLevel: DownloadBoostLevel {
        get {
            if let raw = UserDefaults.standard.string(forKey: prefix + "boostLevel"),
               let level = DownloadBoostLevel(rawValue: raw)
            {
                return level
            }
            // Legacy migration
            let multi: Bool = {
                if UserDefaults.standard.object(forKey: prefix + "multiThread") == nil { return true }
                return UserDefaults.standard.bool(forKey: prefix + "multiThread")
            }()
            let parts: Int = {
                let v = UserDefaults.standard.integer(forKey: prefix + "parallelParts")
                return v == 0 ? 16 : min(32, max(4, v))
            }()
            return DownloadBoostLevel.nearest(toParts: parts, enabled: multi)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: prefix + "boostLevel")
            // Keep legacy keys in sync for older snapshot fields / UI.
            UserDefaults.standard.set(newValue != .off, forKey: prefix + "multiThread")
            UserDefaults.standard.set(newValue.parallelParts, forKey: prefix + "parallelParts")
        }
    }

    /// Legacy toggles kept for cloud snapshot compatibility.
    static var multiThreadDownload: Bool {
        get { boostLevel != .off }
        set {
            if newValue {
                if boostLevel == .off { boostLevel = .high }
            } else {
                boostLevel = .off
            }
        }
    }

    static var parallelParts: Int {
        get { boostLevel.parallelParts }
        set { boostLevel = DownloadBoostLevel.nearest(toParts: newValue, enabled: newValue > 1) }
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

// MARK: - Runtime config

final class MultipartDownloadConfig {
    static let shared = MultipartDownloadConfig()
    private init() { applyFromSettings() }

    private(set) var level: DownloadBoostLevel = .high
    private(set) var parallelParts: Int = 12
    private(set) var enabled: Bool = true
    private(set) var priority: Int = 24
    private(set) var maxConcurrentLargeFiles: Int = 2

    func applyFromSettings() {
        level = DownloadCacheSettings.boostLevel
        enabled = level != .off
        parallelParts = level.parallelParts
        priority = level.priority
        maxConcurrentLargeFiles = level.maxConcurrentLargeFiles
    }

    /// Effective parallel part count for a given file size.
    func parts(forFileSize size: Int64) -> Int {
        guard enabled else { return 1 }
        if size <= 0 { return 1 }
        if size < 1 * 1024 * 1024 { return 1 }
        if size < 8 * 1024 * 1024 { return min(2, parallelParts) }
        if size < 32 * 1024 * 1024 { return min(4, parallelParts) }
        return parallelParts
    }
}

@MainActor
final class DownloadCacheCleaner {
    static let shared = DownloadCacheCleaner()
    private init() {}

    func cleanupIfNeeded() {
        let cutoff = Date().addingTimeInterval(-Double(DownloadCacheSettings.keepDays) * 86400)
        let maxBytes = Int64(DownloadCacheSettings.maxCacheMB) * 1024 * 1024
        // Best-effort: temp directory sweep only (TDLib media box is managed by TDLib).
        let tmp = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var total: Int64 = 0
        var dated: [(URL, Date, Int64)] = []
        for url in files {
            guard url.lastPathComponent.hasPrefix("BetterTG") || url.pathExtension == "part" else { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? .distantPast
            let size = Int64(values?.fileSize ?? 0)
            if date < cutoff {
                try? FileManager.default.removeItem(at: url)
            } else {
                total += size
                dated.append((url, date, size))
            }
        }
        if total > maxBytes {
            for (url, _, size) in dated.sorted(by: { $0.1 < $1.1 }) {
                try? FileManager.default.removeItem(at: url)
                total -= size
                if total <= maxBytes { break }
            }
        }
    }
}
