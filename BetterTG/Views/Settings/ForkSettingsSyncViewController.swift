// ForkSettingsSyncViewController.swift

import UIKit

/// Settings → 设置同步：Saved Messages 云文档 + iCloud 钥匙串口令解密 API Key。
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

        let keychainDetail = ForkSettingsSecretStore.hasPassphrase ? "已就绪（随 Apple ID）" : "未创建"

        return [
            SettingsSection(
                header: "Telegram 收藏夹",
                footer: "扩展设置以文档形式保存在「收藏夹」（标记 \(ForkSettingsSnapshot.cloudMarker)），随 Telegram 账号跨设备。",
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
            SettingsSection(
                header: "API Key 加密",
                footer: """
                开启后，DeepL / Azure Key 以 AES-GCM 密文写入收藏夹，口令保存在 iCloud 钥匙串（随 Apple ID 同步）。\
                换机后：同一 Apple ID 自动取口令，同一 Telegram 账号拉收藏夹文档即可解密恢复。\
                未开启 iCloud 钥匙串的设备无法解密云端 Key。
                """,
                rows: [
                    SettingsRow(
                        title: "同步加密 API Key",
                        detail: "收藏夹密文 + iCloud 口令",
                        style: .subtitle,
                        accessory: .toggle(isOn: ForkSettingsCloudOptions.syncAPIKeys, onChange: { [weak self] on in
                            if on {
                                do {
                                    _ = try ForkSettingsSecretStore.ensurePassphrase()
                                    ForkSettingsCloudOptions.syncAPIKeys = true
                                    ForkSettingsCloudSync.shared.noteLocalChange()
                                } catch {
                                    self?.presentAlert(
                                        title: "无法启用",
                                        message: error.localizedDescription
                                    )
                                }
                            } else {
                                ForkSettingsCloudOptions.syncAPIKeys = false
                                ForkSettingsCloudSync.shared.noteLocalChange()
                            }
                            self?.reload()
                        })
                    ),
                    SettingsRow(
                        title: "加密口令（iCloud 钥匙串）",
                        detail: keychainDetail,
                        style: .subtitle,
                        accessory: .disclosure,
                        action: { [weak self] in self?.managePassphrase() }
                    ),
                    SettingsRow(
                        title: "重新生成口令",
                        detail: "旧密文将无法解密，需重新上传",
                        style: .subtitle,
                        action: { [weak self] in self?.confirmRegeneratePassphrase() }
                    ),
                ]
            ),
        ]
    }

    private func managePassphrase() {
        let alert = UIAlertController(
            title: "加密口令",
            message: "可自定义口令并写入 iCloud 钥匙串；留空则仅查看状态。换机需同一 Apple ID 且开启 iCloud 钥匙串。",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.isSecureTextEntry = true
            $0.placeholder = "新口令（可选）"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                self?.reload()
                return
            }
            do {
                try ForkSettingsSecretStore.savePassphrase(text)
                if ForkSettingsCloudOptions.syncAPIKeys {
                    ForkSettingsCloudSync.shared.noteLocalChange()
                }
                self?.reload()
            } catch {
                self?.presentAlert(title: "保存失败", message: error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func confirmRegeneratePassphrase() {
        let alert = UIAlertController(
            title: "重新生成口令？",
            message: "将生成新的随机口令并写入 iCloud 钥匙串。收藏夹里旧的加密 Key 无法再解，需再点「立即上传」。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重新生成", style: .destructive) { [weak self] _ in
            do {
                try ForkSettingsSecretStore.deletePassphrase()
                _ = try ForkSettingsSecretStore.ensurePassphrase()
                if ForkSettingsCloudOptions.syncAPIKeys {
                    ForkSettingsCloudSync.shared.noteLocalChange()
                }
                self?.reload()
            } catch {
                self?.presentAlert(title: "失败", message: error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
