// ForkSettingsCloudSync.swift
// Sync fork settings via a marker document in Saved Messages (follows Telegram account).
//
// Safety rules (prevent new blank device from wiping cloud):
// 1. Never auto-push until a successful pull finished this session.
// 2. Never auto-push unless the user actually changed fork settings on this device
//    (`hasUserEdited`), except explicit "立即上传".
// 3. If cloud exists and local has no user edits (or local.updatedAt == 0), always apply cloud.
// 4. Before upload, re-fetch cloud; if remote is newer, apply remote and skip upload.
// 5. Only delete old marker messages after deciding to upload.

import Foundation
import TDLibKit

@MainActor
final class ForkSettingsCloudSync {
    static let shared = ForkSettingsCloudSync()

    enum Status: Equatable {
        case idle
        case syncing
        case success(Date)
        case failure(String)
    }

    private(set) var status: Status = .idle {
        didSet { NotificationCenter.default.post(name: .forkSettingsCloudStatusDidChange, object: status) }
    }

    private var pushTask: Task<Void, Never>?
    private var didPullThisSession = false
    private var isPulling = false
    private var observers: [Any] = []

    private static let editedKey = "BetterTG.fork.cloud.hasUserEdited"

    /// True after the user changes a fork preference on this install (or after applying cloud).
    private var hasUserEdited: Bool {
        get { UserDefaults.standard.bool(forKey: Self.editedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.editedKey) }
    }

    private init() {}

    func start() {
        guard observers.isEmpty else { return }
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .authorizationStateReady, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.didPullThisSession = false
                await self?.pullIfNeeded(force: true)
            }
        })
    }

    /// Call after any local fork preference changes (settings UI).
    func noteLocalChange() {
        hasUserEdited = true
        ForkSettingsClock.touch()
        // Do not push until we have finished at least one pull this session,
        // otherwise a blank new device can overwrite Saved Messages.
        guard didPullThisSession, !isPulling else { return }
        schedulePush()
    }

    /// Call when the active account becomes ready (also safe after start()).
    func pullIfNeeded(force: Bool = false) async {
        guard ForkSettingsCloudOptions.enabled else { return }
        guard TDLib.shared.activeAccount?.userID != nil else { return }
        if didPullThisSession, !force { return }
        if isPulling { return }

        isPulling = true
        status = .syncing
        defer { isPulling = false }

        do {
            let remote = try await fetchRemoteSnapshot()
            if let remote {
                let local = ForkSettingsClock.now()
                // New / untouched device: always prefer cloud when present.
                let preferRemote = !hasUserEdited || local <= 0 || remote.updatedAt >= local
                if preferRemote {
                    remote.apply(touchLocalClock: true)
                    // Cloud is source of truth; do not treat apply as a local edit that needs re-upload.
                    hasUserEdited = false
                } else {
                    // Real local edits newer than cloud — upload after pull gate opens.
                    didPullThisSession = true
                    status = .success(Date())
                    schedulePush(delay: 0.5)
                    return
                }
            }
            // No remote document: do NOT seed cloud with blank defaults.
            // First upload happens only after the user edits settings (noteLocalChange).
            didPullThisSession = true
            status = .success(Date())
            if hasUserEdited {
                schedulePush(delay: 0.5)
            }
        } catch {
            // Pull failed — never push; avoid wiping cloud with local blanks.
            status = .failure(error.localizedDescription)
        }
    }

    func pushNow() async {
        guard ForkSettingsCloudOptions.enabled else { return }
        status = .syncing
        do {
            try await uploadSnapshot(force: true)
            status = .success(Date())
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func schedulePush(delay: TimeInterval = 2.0) {
        guard ForkSettingsCloudOptions.enabled else { return }
        guard didPullThisSession, !isPulling else { return }
        guard hasUserEdited else { return }
        pushTask?.cancel()
        pushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard didPullThisSession, !isPulling, hasUserEdited else { return }
            await pushNow()
        }
    }

    // MARK: - TDLib

    private func client() throws -> TDLibClient {
        guard TDLib.shared.activeAccount?.userID != nil else {
            throw SyncError.notReady
        }
        return TDLib.shared.activeClient
    }

    private func savedMessagesChatID(client: TDLibClient) async throws -> Int64 {
        let me = try await client.getMe()
        let chat = try await client.createPrivateChat(force: false, userId: me.id)
        return chat.id
    }

    private func fetchRemoteSnapshot() async throws -> ForkSettingsSnapshot? {
        let client = try client()
        let chatID = try await savedMessagesChatID(client: client)
        let found = try await client.searchChatMessages(
            chatId: chatID,
            filter: nil,
            fromMessageId: 0,
            limit: 20,
            offset: 0,
            query: ForkSettingsSnapshot.cloudMarker,
            senderId: nil,
            topicId: nil
        )
        var best: (date: Int, snapshot: ForkSettingsSnapshot)?
        for message in found.messages {
            if let snap = try await snapshot(from: message, client: client) {
                let date = message.date
                if best == nil || date >= best!.date {
                    best = (date, snap)
                }
            }
        }
        return best?.snapshot
    }

    private func snapshot(from message: Message, client: TDLibClient) async throws -> ForkSettingsSnapshot? {
        if case .messageDocument(let doc) = message.content {
            let caption = doc.caption.text
            guard caption.contains(ForkSettingsSnapshot.cloudMarker)
                    || doc.document.fileName.contains("bettertg-fork-settings")
            else { return nil }
            let path = try await ensureDownloaded(file: doc.document.document, client: client)
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try ForkSettingsSnapshot.decode(from: data)
        }
        if case .messageText(let text) = message.content {
            let body = text.text.text
            guard body.contains(ForkSettingsSnapshot.cloudMarker) else { return nil }
            if let range = body.range(of: "{"),
               let jsonData = String(body[range.lowerBound...]).data(using: .utf8),
               let snap = try? ForkSettingsSnapshot.decode(from: jsonData)
            {
                return snap
            }
        }
        return nil
    }

    private func ensureDownloaded(file: File, client: TDLibClient) async throws -> String {
        if file.local.isDownloadingCompleted, !file.local.path.isEmpty {
            return file.local.path
        }
        let downloaded = try await client.downloadFile(
            fileId: file.id,
            limit: 0,
            offset: 0,
            priority: 32,
            synchronous: true
        )
        guard downloaded.local.isDownloadingCompleted, !downloaded.local.path.isEmpty else {
            throw SyncError.downloadFailed
        }
        return downloaded.local.path
    }

    /// - Parameter force: user tapped「立即上传」— still re-check remote so we don't clobber a newer cloud copy.
    private func uploadSnapshot(force: Bool) async throws {
        // Guard automatic paths again (force still requires enabled + account).
        if !force {
            guard didPullThisSession, hasUserEdited else { return }
        }

        // Re-fetch so a newer cloud revision always wins.
        if let remote = try await fetchRemoteSnapshot() {
            let local = ForkSettingsClock.now()
            if remote.updatedAt > local {
                remote.apply(touchLocalClock: true)
                hasUserEdited = false
                return
            }
            // Equal timestamps + no force: skip redundant rewrite.
            if !force, remote.updatedAt == local, !hasUserEdited {
                return
            }
        }

        let client = try client()
        let chatID = try await savedMessagesChatID(client: client)

        // Bump clock only for intentional uploads after pull.
        ForkSettingsClock.touch()
        let snapshot = ForkSettingsSnapshot.capture(includeAPIKeys: ForkSettingsCloudOptions.syncAPIKeys)
        let data = try snapshot.jsonData()

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(ForkSettingsSnapshot.fileName)
        try data.write(to: temp, options: .atomic)

        try await deleteOldMarkerMessages(chatID: chatID, client: client)

        let caption = FormattedText(entities: [], text: ForkSettingsSnapshot.cloudMarker)
        _ = try await client.sendMessage(
            chatId: chatID,
            inputMessageContent: .inputMessageDocument(
                InputMessageDocument(
                    caption: caption,
                    document: InputDocument(
                        disableContentTypeDetection: true,
                        document: .inputFileLocal(
                            InputFileLocal(path: temp.path(percentEncoded: false))
                        ),
                        thumbnail: nil
                    )
                )
            ),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
        try? FileManager.default.removeItem(at: temp)
        hasUserEdited = false
    }

    private func deleteOldMarkerMessages(chatID: Int64, client: TDLibClient) async throws {
        let found = try await client.searchChatMessages(
            chatId: chatID,
            filter: nil,
            fromMessageId: 0,
            limit: 50,
            offset: 0,
            query: ForkSettingsSnapshot.cloudMarker,
            senderId: nil,
            topicId: nil
        )
        let ids = found.messages.map(\.id)
        guard !ids.isEmpty else { return }
        _ = try? await client.deleteMessages(chatId: chatID, messageIds: ids, revoke: true)
    }

    enum SyncError: LocalizedError {
        case notReady
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .notReady: "账号未就绪"
            case .downloadFailed: "无法下载云端配置文件"
            }
        }
    }
}

extension Foundation.Notification.Name {
    static let forkSettingsCloudStatusDidChange = Self("BetterTG.fork.cloudStatusDidChange")
}
