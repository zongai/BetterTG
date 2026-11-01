// ContentFilterSettingsViewController.swift

import UIKit

final class ContentFilterSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "内容过滤"
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
                footer: "开启关键词过滤后，命中黑名单的文本消息将被隐藏；命中白名单则始终显示。白名单优先。",
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
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                KeywordListManagerViewController(mode: .blacklist),
                                animated: true
                            )
                        }
                    ),
                    SettingsRow(
                        title: "白名单",
                        detail: "\(ContentFilterSettings.whitelist.count) 个词",
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                KeywordListManagerViewController(mode: .whitelist),
                                animated: true
                            )
                        }
                    ),
                ]
            ),
        ]
    }
}

// MARK: - KeywordListManagerViewController

/// Manage blacklist / whitelist: one keyword per row, add / delete / clear.
final class KeywordListManagerViewController: UITableViewController {
    enum Mode {
        case blacklist
        case whitelist

        var title: String {
            switch self {
            case .blacklist: "黑名单"
            case .whitelist: "白名单"
            }
        }

        var emptyHint: String {
            switch self {
            case .blacklist: "暂无黑名单词\n点击右上角 + 添加，每行一个关键词"
            case .whitelist: "暂无白名单词\n点击右上角 + 添加，每行一个关键词"
            }
        }

        var items: [String] {
            get {
                switch self {
                case .blacklist: ContentFilterSettings.blacklist
                case .whitelist: ContentFilterSettings.whitelist
                }
            }
            set {
                switch self {
                case .blacklist: ContentFilterSettings.blacklist = newValue
                case .whitelist: ContentFilterSettings.whitelist = newValue
                }
            }
        }
    }

    private let mode: Mode
    private var items: [String]
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(mode: Mode) {
        self.mode = mode
        self.items = mode.items
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.title
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "keyword")
        tableView.keyboardDismissMode = .onDrag

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addTapped)),
            editButtonItem,
        ]

        emptyLabel.text = mode.emptyHint
        tableView.backgroundView = UIView()
        tableView.backgroundView?.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.leadingAnchor.constraint(equalTo: tableView.backgroundView!.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: tableView.backgroundView!.trailingAnchor, constant: -32),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.backgroundView!.centerYAnchor),
        ])
        updateEmptyState()
        updateClearButton()
    }

    private func persist() {
        switch mode {
        case .blacklist: ContentFilterSettings.blacklist = items
        case .whitelist: ContentFilterSettings.whitelist = items
        }
        updateEmptyState()
        updateClearButton()
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !items.isEmpty
    }

    private func updateClearButton() {
        if items.isEmpty {
            navigationItem.leftBarButtonItem = nil
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "清空",
                style: .plain,
                target: self,
                action: #selector(clearAllTapped)
            )
        }
    }

    // MARK: Actions

    @objc private func addTapped() {
        let alert = UIAlertController(
            title: "添加关键词",
            message: "每次添加一个；也可粘贴多行，将按行拆分",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "关键词"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.returnKeyType = .done
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            guard let self else { return }
            let raw = alert.textFields?.first?.text ?? ""
            self.addKeywords(from: raw)
        })
        present(alert, animated: true)
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "清空\(mode.title)？",
            message: "将删除全部 \(items.count) 个关键词",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.items.removeAll()
            self.persist()
            self.tableView.reloadData()
            self.setEditing(false, animated: true)
        })
        present(alert, animated: true)
    }

    /// Split by newline / comma / Chinese comma; dedupe case-insensitively; append new ones.
    private func addKeywords(from raw: String) {
        let parts = raw
            .components(separatedBy: CharacterSet(charactersIn: "\n,，、;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return }

        var existing = Set(items.map { $0.lowercased() })
        var added = [String]()
        for part in parts {
            let key = part.lowercased()
            if existing.contains(key) { continue }
            existing.insert(key)
            added.append(part)
        }
        guard !added.isEmpty else { return }

        let start = items.count
        items.append(contentsOf: added)
        persist()
        tableView.insertRows(
            at: (start ..< items.count).map { IndexPath(row: $0, section: 0) },
            with: .automatic
        )
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        items.isEmpty
            ? nil
            : "左滑可删除；点「编辑」可批量删除。消息文本包含关键词即匹配（不区分大小写）。"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "keyword", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = items[indexPath.row]
        config.textProperties.numberOfLines = 1
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            guard let self else {
                done(false)
                return
            }
            self.items.remove(at: indexPath.row)
            self.persist()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        items.remove(at: indexPath.row)
        persist()
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let value = items.remove(at: sourceIndexPath.row)
        items.insert(value, at: destinationIndexPath.row)
        persist()
    }
}
