// AutoTranslateSettingsViewController.swift

import UIKit

/// Settings > Language > Auto-Translate (fork feature).
final class AutoTranslateSettingsViewController: SettingsListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "自动翻译"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func makeSections() -> [SettingsSection] {
        let engines = TranslationSettings.engineChain
        let engineDetail = engines.map(\.displayName).joined(separator: " → ")
        return [
            SettingsSection(header: nil, footer: nil, rows: [
                SettingsRow(
                    title: "自动翻译非目标语言",
                    detail: "可见消息自动译为设定语言",
                    style: .subtitle,
                    accessory: .toggle(isOn: TranslationSettings.autoTranslateNonTarget, onChange: { [weak self] on in
                        TranslationSettings.autoTranslateNonTarget = on
                        self?.reload()
                    }),
                ),
                SettingsRow(
                    title: "目标语言",
                    detail: TranslationSettings.targetLanguage,
                    accessory: .disclosure,
                    action: { [weak self] in self?.pickTargetLanguage() }
                ),
            ]),
            SettingsSection(
                header: "引擎顺序（失败自动切换）",
                footer: "Google / MyMemory 无需 Key；DeepL、Azure 需填写 API Key。",
                rows: [
                    SettingsRow(title: "当前链路", detail: engineDetail, style: .subtitle),
                    SettingsRow(
                        title: "DeepL API Key",
                        detail: TranslationSettings.deeplAPIKey.isEmpty ? "未设置" : "已设置",
                        accessory: .disclosure,
                        action: { [weak self] in
                            self?.editKey(title: "DeepL API Key", current: TranslationSettings.deeplAPIKey) {
                                TranslationSettings.deeplAPIKey = $0
                            }
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
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            save(alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            self?.reload()
        })
        present(alert, animated: true)
    }
}
