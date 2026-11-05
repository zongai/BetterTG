// ForkSettingsSyncViewController.swift

import UIKit

/// Settings → 设置同步：Saved Messages 云端配置（随 Telegram 账号）。
final class ForkSettingsSyncViewController: SettingsListViewController {
    private var statusObserver: NSObjectProtocol?

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置同步"
        navigationItem.largeTitleDisplayMode = .never
        statusObserver = NotificationCenter.default.addObserver(
            forName: .forkSettingsCloudStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    override func makeSections() -> [SettingsSection] {
        let statusText: String = {
            switch ForkSettingsCloudSync.shared.status {
            case .idle: return "空闲"
            case .syncing: return "同步中…"
            case .success(let date):
                let f = DateFormatter()
                f.dateStyle = .short
                f.timeStyle = .short
                return "已同步 \(f.string(from: date))"
            case .failure(let msg): return "失败：\(msg)"
            }
        }()

        return [
            SettingsSection(
                header: "Telegram 收藏夹",
                footer: "开启后，扩展设置会以隐藏文档的形式保存在「收藏夹」中（标题含 \(ForkSettingsSnapshot.cloudMarker)），换设备登录同一账号可自动拉取。API Key 默认不同步。",
                rows: [
                    SettingsRow(
                        title: "随账号同步",
                        detail: "Saved Messages 云文档",
                        style: .subtitle,
                        accessory: .toggle(isOn: ForkSettingsCloudOptions.enabled, onChange: { [weak self] on in
                            ForkSettingsCloudOptions.enabled = on
                            if on {
                                Task { await ForkSettingsCloudSync.shared.pullIfNeeded(force: true) }
                            }
                            self?.reload()
                        })
                    ),
                    SettingsRow(
                        title: "同步 API Key",
                        detail: "DeepL / Azure 密钥写入云端（明文）",
                        style: .subtitle,
                        accessory: .toggle(isOn: ForkSettingsCloudOptions.syncAPIKeys, onChange: { [weak self] on in
                            ForkSettingsCloudOptions.syncAPIKeys = on
                            ForkSettingsCloudSync.shared.noteLocalChange()
                            self?.reload()
                        })
                    ),
                    SettingsRow(
                        title: "状态",
                        detail: statusText,
                        style: .subtitle
                    ),
                    SettingsRow(
                        title: "立即从云端拉取",
                        style: .action(destructive: false),
                        action: {
                            Task { await ForkSettingsCloudSync.shared.pullIfNeeded(force: true) }
                        }
                    ),
                    SettingsRow(
                        title: "立即上传到收藏夹",
                        style: .action(destructive: false),
                        action: {
                            Task { await ForkSettingsCloudSync.shared.pushNow() }
                        }
                    ),
                ]
            ),
        ]
    }
}
