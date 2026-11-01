// AutoTranslateSettingsViewController.swift

import UIKit

/// BetterTG 扩展 → 自动翻译
final class AutoTranslateSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "自动翻译"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func makeSections() -> [SettingsSection] {
        let chain = TranslationSettings.engineChain
        let chainDetail = chain.map(\.displayName).joined(separator: " → ")
        let keyCount = TranslationSettings.deeplAPIKeys.count

        return [
            SettingsSection(
                header: nil,
                footer: "开启后，可见消息若不是目标语言，将按下方引擎顺序自动翻译。可点消息上的「翻译」区域切换原文/译文。",
                rows: [
                    SettingsRow(
                        title: "自动翻译非目标语言",
                        accessory: .toggle(isOn: TranslationSettings.autoTranslateNonTarget, onChange: { [weak self] on in
                            TranslationSettings.autoTranslateNonTarget = on
                            self?.reload()
                        }),
                    ),
                    SettingsRow(
                        title: "显示双语",
                        accessory: .toggle(isOn: TranslationSettings.showBilingual, onChange: { [weak self] on in
                            TranslationSettings.showBilingual = on
                            self?.reload()
                        }),
                    ),
                    SettingsRow(
                        title: "目标语言",
                        detail: TranslationSettings.targetLanguage,
                        accessory: .disclosure,
                        action: { [weak self] in self?.pickTargetLanguage() }
                    ),
                ]
            ),
            SettingsSection(
                header: "翻译源顺序",
                footer: "按顺序尝试；失败或限流时自动切换到下一个。可拖动调整优先级。",
                rows: [
                    SettingsRow(
                        title: "引擎顺序",
                        detail: chainDetail,
                        style: .subtitle,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                TranslationEngineOrderViewController(),
                                animated: true
                            )
                        }
                    ),
                ]
            ),
            SettingsSection(
                header: "API Keys",
                footer: "DeepL 支持多个 Key：限流或失效时自动轮换。Google / Bing / MyMemory 无需 Key。",
                rows: [
                    SettingsRow(
                        title: "DeepL Keys",
                        detail: keyCount == 0 ? "未设置" : "\(keyCount) 个",
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.navigationController?.pushViewController(
                                DeepLAPIKeyManagerViewController(),
                                animated: true
                            )
                        }
                    ),
                    SettingsRow(
                        title: "Azure API Key",
                        detail: TranslationSettings.azureAPIKey.isEmpty ? "未设置" : "已设置",
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.editKey(title: "Azure API Key", current: TranslationSettings.azureAPIKey) {
                                TranslationSettings.azureAPIKey = $0
                            }
                        }
                    ),
                    SettingsRow(
                        title: "Azure Region",
                        detail: TranslationSettings.azureRegion,
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.editKey(title: "Azure Region", current: TranslationSettings.azureRegion) {
                                TranslationSettings.azureRegion = $0.isEmpty ? "eastasia" : $0
                            }
                        }
                    ),
                ]
            ),
        ]
    }

    private func pickTargetLanguage() {
        let alert = UIAlertController(title: "目标语言代码", message: "例如 zh、en、ja、ru", preferredStyle: .alert)
        alert.addTextField { $0.text = TranslationSettings.targetLanguage }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            let v = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !v.isEmpty { TranslationSettings.targetLanguage = v }
            self?.reload()
        })
        present(alert, animated: true)
    }

    private func editKey(title: String, current: String, save: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.text = current
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.isSecureTextEntry = title.lowercased().contains("key")
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            save(alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            self?.reload()
        })
        present(alert, animated: true)
    }
}

// MARK: - DeepLAPIKeyManagerViewController

/// Manage multiple DeepL API keys (order = rotation priority).
final class DeepLAPIKeyManagerViewController: UITableViewController {
    private var keys: [String]

    init() {
        self.keys = TranslationSettings.deeplAPIKeys
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DeepL Keys"
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "key")
        // 始终可排序，避免再占一个「编辑」按钮把标题挤成 “D…”
        setEditing(true, animated: false)
        updateEmptyHint()
        refreshBarButtons()
    }

    private func persist() {
        TranslationSettings.deeplAPIKeys = keys
        updateEmptyHint()
        refreshBarButtons()
    }

    private func updateEmptyHint() {
        if keys.isEmpty {
            let label = UILabel()
            label.text = "尚未添加 DeepL Key\n点右上角 + 添加，可添加多个并拖动排序"
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            label.font = .preferredFont(forTextStyle: .body)
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    /// 右侧最多两个图标（添加 / 清空），去掉「编辑」以免标题被挤成 “D…”。
    private func refreshBarButtons() {
        var items: [UIBarButtonItem] = [
            UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain,
                target: self,
                action: #selector(addTapped)
            ),
        ]
        if !keys.isEmpty {
            items.append(
                UIBarButtonItem(
                    image: UIImage(systemName: "trash"),
                    style: .plain,
                    target: self,
                    action: #selector(clearTapped)
                )
            )
        }
        for item in items {
            item.tintColor = .label
        }
        navigationItem.rightBarButtonItems = items
        navigationItem.leftBarButtonItem = nil
    }

    private static func masked(_ key: String) -> String {
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 12 {
            return t
        }
        // 显示更多字符，避免满屏都是 “0023…e:fx” 难辨认
        return String(t.prefix(8)) + "…" + String(t.suffix(6))
    }

    @objc private func addTapped() {
        let alert = UIAlertController(
            title: "添加 DeepL Key",
            message: "Free 账号 Key 通常以 :fx 结尾。可一次粘贴多行。",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "DeepL-Auth-Key"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self] _ in
            guard let self else { return }
            let raw = alert.textFields?.first?.text ?? ""
            let parts = raw
                .components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var existing = Set(self.keys)
            var added = [String]()
            for p in parts where existing.insert(p).inserted {
                added.append(p)
            }
            guard !added.isEmpty else { return }
            let start = self.keys.count
            self.keys.append(contentsOf: added)
            self.persist()
            self.tableView.insertRows(
                at: (start ..< self.keys.count).map { IndexPath(row: $0, section: 0) },
                with: .automatic
            )
        })
        present(alert, animated: true)
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(title: "清空全部 Key？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            self?.keys.removeAll()
            self?.persist()
            self?.tableView.reloadData()
            self?.setEditing(true, animated: false)
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        keys.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        keys.isEmpty ? nil : "列表顺序即轮换优先顺序。限流时自动使用下一个 Key。"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "key", for: indexPath)
        var config = cell.defaultContentConfiguration()
        let key = keys[indexPath.row]
        config.text = Self.masked(key)
        config.textProperties.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        config.secondaryText = key.hasSuffix(":fx")
            ? "Free · 优先级 \(indexPath.row + 1)"
            : "Pro · 优先级 \(indexPath.row + 1)"
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        cell.showsReorderControl = true
        return cell
    }

    // 始终处于编辑态时隐藏每行左侧红色删除圆，仅保留右侧拖动手柄；删除用左滑。
    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(
        _ tableView: UITableView,
        shouldIndentWhileEditingRowAt indexPath: IndexPath
    ) -> Bool {
        false
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            guard let self else { done(false); return }
            self.keys.remove(at: indexPath.row)
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
        keys.remove(at: indexPath.row)
        persist()
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        let value = keys.remove(at: sourceIndexPath.row)
        keys.insert(value, at: destinationIndexPath.row)
        persist()
        tableView.reloadData()
    }
}

// MARK: - TranslationEngineOrderViewController

/// Reorder translation engines; toggle inclusion via checkmark.
final class TranslationEngineOrderViewController: UITableViewController {
    /// Full ordered list: enabled engines first (user order), then disabled.
    private var ordered: [TranslationEngine]
    private var enabled: Set<TranslationEngine>

    init() {
        let chain = TranslationSettings.engineChain
        var seen = Set<TranslationEngine>()
        var list: [TranslationEngine] = []
        for e in chain where seen.insert(e).inserted {
            list.append(e)
        }
        for e in TranslationEngine.allCases where seen.insert(e).inserted {
            list.append(e)
        }
        self.ordered = list
        self.enabled = Set(chain.isEmpty ? TranslationEngine.allCases : chain)
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "翻译源顺序"
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "engine")
        // 不使用 editButtonItem：在部分系统上会显示成蓝色实心圆。
        // 始终可拖动排序；点选行启用/禁用引擎。
        navigationItem.rightBarButtonItem = nil
        setEditing(true, animated: false)
    }

    private func persist() {
        let chain = ordered.filter { enabled.contains($0) }
        TranslationSettings.engineChain = chain.isEmpty ? TranslationEngine.allCases : chain
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        ordered.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "引擎优先级"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "点选行启用/禁用；拖动手柄调整顺序。自动翻译按从上到下依次尝试。"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "engine", for: indexPath)
        let engine = ordered[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = engine.displayName
        switch engine {
        case .google, .bing, .mymemory:
            config.secondaryText = "无需 Key"
        case .deepl:
            let n = TranslationSettings.deeplAPIKeys.count
            config.secondaryText = n == 0 ? "需要 DeepL Key" : "\(n) 个 Key"
        case .azure:
            config.secondaryText = TranslationSettings.azureAPIKey.isEmpty ? "需要 Azure Key" : "已配置"
        }
        cell.contentConfiguration = config
        cell.accessoryType = enabled.contains(engine) ? .checkmark : .none
        cell.selectionStyle = .default
        cell.showsReorderControl = true
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(
        _ tableView: UITableView,
        shouldIndentWhileEditingRowAt indexPath: IndexPath
    ) -> Bool {
        false
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let engine = ordered[indexPath.row]
        if enabled.contains(engine) {
            // Keep at least one engine enabled.
            if enabled.count <= 1 { return }
            enabled.remove(engine)
        } else {
            enabled.insert(engine)
        }
        persist()
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        let value = ordered.remove(at: sourceIndexPath.row)
        ordered.insert(value, at: destinationIndexPath.row)
        persist()
    }
}
