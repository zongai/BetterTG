// DownloadCacheSettingsViewController.swift

import UIKit

final class DownloadCacheSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "下载与缓存"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func makeSections() -> [SettingsSection] {
        let parts = DownloadCacheSettings.parallelParts
        return [
            SettingsSection(header: "多线程下载", footer: nil, rows: [
                SettingsRow(
                    title: "启用多线程下载",
                    accessory: .toggle(isOn: DownloadCacheSettings.multiThreadDownload, onChange: { [weak self] on in
                        DownloadCacheSettings.multiThreadDownload = on
                        MultipartDownloadConfig.shared.applyFromSettings()
                        self?.reload()
                    }),
                ),
                SettingsRow(
                    title: "并行分片数",
                    detail: "\(parts)（4–32）",
                    accessory: .disclosure,
                    action: { [weak self] in self?.pickParts() }
                ),
            ]),
            SettingsSection(
                header: "自动清理",
                footer: "回到前台时按间隔清理过期临时文件，并限制缓存上限。",
                rows: [
                    SettingsRow(
                        title: "自动清理缓存",
                        accessory: .toggle(isOn: DownloadCacheSettings.autoCleanupEnabled, onChange: { on in
                            DownloadCacheSettings.autoCleanupEnabled = on
                        }),
                    ),
                    SettingsRow(
                        title: "保留天数",
                        detail: "\(DownloadCacheSettings.keepDays) 天",
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.pickNumber(title: "保留天数", current: DownloadCacheSettings.keepDays) {
                                DownloadCacheSettings.keepDays = $0
                            }
                        }
                    ),
                    SettingsRow(
                        title: "缓存上限",
                        detail: "\(DownloadCacheSettings.maxCacheMB) MB",
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.pickNumber(title: "缓存上限 (MB)", current: DownloadCacheSettings.maxCacheMB) {
                                DownloadCacheSettings.maxCacheMB = $0
                            }
                        }
                    ),
                    SettingsRow(
                        title: "立即清理",
                        style: .action(destructive: false),
                        action: { DownloadCacheCleaner.shared.cleanupIfNeeded() }
                    ),
                ]
            ),
        ]
    }

    private func pickParts() {
        let sheet = UIAlertController(title: "并行分片数", message: nil, preferredStyle: .actionSheet)
        for n in [4, 8, 12, 16, 24, 32] {
            sheet.addAction(UIAlertAction(title: "\(n)", style: .default) { [weak self] _ in
                DownloadCacheSettings.parallelParts = n
                MultipartDownloadConfig.shared.applyFromSettings()
                self?.reload()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    private func pickNumber(title: String, current: Int, save: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.text = "\(current)"
            $0.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            if let v = Int(alert.textFields?.first?.text ?? ""), v > 0 {
                save(v)
                self?.reload()
            }
        })
        present(alert, animated: true)
    }
}
