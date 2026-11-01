// BetterTGExtensionsSettingsViewController.swift

import UIKit

/// Hub for all fork-added features: auto-translate, content filter, download & cache.
final class BetterTGExtensionsSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BetterTG 扩展"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func makeSections() -> [SettingsSection] {
        [
            SettingsSection(
                header: nil,
                footer: "本仓库在官方 BetterTG 之上增加的功能，集中在此配置。",
                rows: [
                    SettingsRow(
                        title: "自动翻译",
                        detail: TranslationSettings.autoTranslateNonTarget ? "开" : "关",
                        symbol: "character.book.closed.fill",
                        symbolTint: .systemBlue,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                AutoTranslateSettingsViewController(),
                                animated: true
                            )
                        }
                    ),
                    SettingsRow(
                        title: "内容过滤",
                        detail: ContentFilterSettings.hideAds || ContentFilterSettings.filterEnabled
                            ? "已启用"
                            : "关闭",
                        symbol: "line.3.horizontal.decrease.circle.fill",
                        symbolTint: .systemOrange,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                ContentFilterSettingsViewController(),
                                animated: true
                            )
                        }
                    ),
                    SettingsRow(
                        title: "下载与缓存",
                        detail: DownloadCacheSettings.multiThreadDownload
                            ? "多线程 \(DownloadCacheSettings.parallelParts) 分片"
                            : "单线程",
                        symbol: "arrow.down.circle.fill",
                        symbolTint: .systemGreen,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                DownloadCacheSettingsViewController(),
                                animated: true
                            )
                        }
                    ),
                ]
            ),
        ]
    }
}
