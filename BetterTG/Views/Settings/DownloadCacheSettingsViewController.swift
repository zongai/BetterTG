// DownloadCacheSettingsViewController.swift

import UIKit

/// Settings → BetterTG 扩展 → 下载与缓存
final class DownloadCacheSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "下载与缓存"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func makeSections() -> [SettingsSection] {
        let level = DownloadCacheSettings.boostLevel
        MultipartDownloadConfig.shared.applyFromSettings()

        var boostRows: [SettingsRow] = DownloadBoostLevel.allCases.map { candidate in
            SettingsRow(
                title: candidate.title,
                detail: "\(candidate.detail) · \(candidate.parallelParts) 分片",
                style: .subtitle,
                accessory: level == candidate ? .checkmark : .none,
                action: { [weak self] in
                    DownloadCacheSettings.boostLevel = candidate
                    MultipartDownloadConfig.shared.applyFromSettings()
                    ForkSettingsCloudSync.shared.noteLocalChange()
                    self?.reload()
                }
            )
        }

        return [
            SettingsSection(
                header: "下载加速（Download Boost）",
                footer: """
                参考 Swiftgram / 官方 Premium 客户端：提高大文件分片并行与下载优先级。\
                非 Premium 账号仍可能被服务器限速；不稳定时请选「标准」。\
                小文件自动降低并行数。
                """,
                rows: boostRows
            ),
            SettingsSection(
                header: "当前生效",
                footer: nil,
                rows: [
                    SettingsRow(
                        title: "并行分片",
                        detail: "\(MultipartDownloadConfig.shared.parallelParts)",
                        style: .subtitle
                    ),
                    SettingsRow(
                        title: "下载优先级",
                        detail: "\(MultipartDownloadConfig.shared.priority) / 32",
                        style: .subtitle
                    ),
                    SettingsRow(
                        title: "同时大文件数",
                        detail: "\(MultipartDownloadConfig.shared.maxConcurrentLargeFiles)",
                        style: .subtitle
                    ),
                ]
            ),
            SettingsSection(
                header: "缓存清理",
                footer: "回到前台时按间隔清理临时文件（不超过保留天数与容量上限）。",
                rows: [
                    SettingsRow(
                        title: "自动清理缓存",
                        accessory: .toggle(isOn: DownloadCacheSettings.autoCleanupEnabled, onChange: { [weak self] on in
                            DownloadCacheSettings.autoCleanupEnabled = on
                            ForkSettingsCloudSync.shared.noteLocalChange()
                            self?.reload()
                        })
                    ),
                    SettingsRow(
                        title: "保留天数",
                        detail: "\(DownloadCacheSettings.keepDays) 天",
                        style: .subtitle,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.editInt(
                                title: "保留天数",
                                current: DownloadCacheSettings.keepDays
                            ) {
                                DownloadCacheSettings.keepDays = $0
                                ForkSettingsCloudSync.shared.noteLocalChange()
                            }
                        }
                    ),
                    SettingsRow(
                        title: "缓存上限",
                        detail: "\(DownloadCacheSettings.maxCacheMB) MB",
                        style: .subtitle,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.editInt(
                                title: "缓存上限 (MB)",
                                current: DownloadCacheSettings.maxCacheMB
                            ) {
                                DownloadCacheSettings.maxCacheMB = $0
                                ForkSettingsCloudSync.shared.noteLocalChange()
                            }
                        }
                    ),
                ]
            ),
        ]
    }

    private func editInt(title: String, current: Int, onSave: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.keyboardType = .numberPad
            $0.text = "\(current)"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            let value = Int(alert.textFields?.first?.text ?? "") ?? current
            onSave(value)
            self?.reload()
        })
        present(alert, animated: true)
    }
}
