// ContentFilterSettingsViewController.swift

import UIKit

final class ContentFilterSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "内容过滤"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func makeSections() -> [SettingsSection] {
        [
            SettingsSection(
                header: nil,
                footer: "开启关键词过滤后，命中黑名单的文本消息将被隐藏；命中白名单则始终显示。",
                rows: [
                    SettingsRow(
                        title: "隐藏广告 / 赞助消息",
                        accessory: .toggle(isOn: ContentFilterSettings.hideAds, onChange: { on in
                            ContentFilterSettings.hideAds = on
                        }),
                    ),
                    SettingsRow(
                        title: "启用关键词过滤",
                        detail: "白名单优先于黑名单",
                        style: .subtitle,
                        accessory: .toggle(isOn: ContentFilterSettings.filterEnabled, onChange: { [weak self] on in
                            ContentFilterSettings.filterEnabled = on
                            self?.reload()
                        }),
                    ),
                    SettingsRow(
                        title: "黑名单",
                        detail: "\(ContentFilterSettings.blacklist.count) 个词",
                        accessory: .disclosure,
                        action: { [weak self] in self?.editList(isWhitelist: false) }
                    ),
                    SettingsRow(
                        title: "白名单",
                        detail: "\(ContentFilterSettings.whitelist.count) 个词",
                        accessory: .disclosure,
                        action: { [weak self] in self?.editList(isWhitelist: true) }
                    ),
                ]
            ),
        ]
    }

    private func editList(isWhitelist: Bool) {
        let current = isWhitelist ? ContentFilterSettings.whitelist : ContentFilterSettings.blacklist
        let alert = UIAlertController(
            title: isWhitelist ? "白名单" : "黑名单",
            message: "用换行或逗号分隔关键词",
            preferredStyle: .alert
        )
        alert.addTextField { $0.text = current.joined(separator: ", ") }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            let raw = alert.textFields?.first?.text ?? ""
            let items = raw
                .split(whereSeparator: { $0 == "\n" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if isWhitelist {
                ContentFilterSettings.whitelist = items
            } else {
                ContentFilterSettings.blacklist = items
            }
            self?.reload()
        })
        present(alert, animated: true)
    }
}
