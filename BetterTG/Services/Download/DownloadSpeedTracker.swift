// DownloadSpeedTracker.swift
// Tracks per-file download speed and formats progress strings.

import Foundation

final class DownloadSpeedTracker: @unchecked Sendable {
    static let shared = DownloadSpeedTracker()

    private struct Sample {
        var lastBytes: Int64
        var lastTime: CFAbsoluteTime
        var speedBps: Double
    }

    private var samples: [Int: Sample] = [:]
    private let lock = NSLock()

    func update(fileID: Int, received: Int64) {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        if var s = samples[fileID] {
            let dt = now - s.lastTime
            if dt >= 0.25 {
                let db = Double(received - s.lastBytes)
                let inst = max(0, db / dt)
                s.speedBps = s.speedBps * 0.4 + inst * 0.6
                s.lastBytes = received
                s.lastTime = now
                samples[fileID] = s
            }
        } else {
            samples[fileID] = Sample(lastBytes: received, lastTime: now, speedBps: 0)
        }
    }

    func speedBps(fileID: Int) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return samples[fileID]?.speedBps ?? 0
    }

    func clear(fileID: Int) {
        lock.lock()
        samples[fileID] = nil
        lock.unlock()
    }

    /// e.g. "1.2 MB / 5.0 MB · 2.5 MB/s"
    static func progressText(received: Int64, total: Int64, speedBps: Double) -> String {
        let left = byteString(received)
        let right = total > 0 ? byteString(total) : "—"
        if speedBps > 500 {
            return "\(left) / \(right) · \(byteString(Int64(speedBps)))/s"
        }
        return "\(left) / \(right)"
    }

    private static func byteString(_ bytes: Int64) -> String {
        let b = Double(max(0, bytes))
        if b < 1024 { return String(format: "%.0f B", b) }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024) }
        if b < 1024 * 1024 * 1024 { return String(format: "%.1f MB", b / (1024 * 1024)) }
        return String(format: "%.2f GB", b / (1024 * 1024 * 1024))
    }
}
