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
                    SettingsRow(
                        title: "消息文字大小",
                        detail: MessageAppearanceSettings.scalePercentLabel,
                        symbol: "textformat.size",
                        symbolTint: .systemPurple,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                MessageTextSizeSettingsViewController(),
                                animated: true
                            )
                        }
                    ),
                ]
            ),
        ]
    }
}

// MARK: - MessageTextSizeSettingsViewController

final class MessageTextSizeSettingsViewController: UITableViewController {
    private let scales: [CGFloat] = [0.85, 0.90, 1.0, 1.10, 1.20, 1.35, 1.50]

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息文字大小"
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "size")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        scales.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "调整聊天气泡内正文与译文的字号。重新进入聊天或滚动刷新后完全生效。"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "size", for: indexPath)
        let scale = scales[indexPath.row]
        var config = cell.defaultContentConfiguration()
        let pct = Int((scale * 100).rounded())
        config.text = "\(pct)%"
        config.secondaryText = scale == 1.0 ? "默认" : nil
        config.textProperties.font = .systemFont(ofSize: 17 * scale)
        cell.contentConfiguration = config
        let current = MessageAppearanceSettings.textScale
        cell.accessoryType = abs(current - scale) < 0.001 ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        MessageAppearanceSettings.textScale = scales[indexPath.row]
        tableView.reloadData()
    }
}
