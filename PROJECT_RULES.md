# BetterTG (zongai) — 跨对话默认规则

本文件供后续对话与自动化沿用。实现细节见 `FORK.md`。

## 仓库与身份

| 项 | 值 |
|----|-----|
| 上游 | https://github.com/levochkaa/BetterTG |
| 本仓库 | https://github.com/zongai/BetterTG |
| Bundle ID | `com.zongai.BetterTG` |
| 工程 | UIKit + TDLib + **XcodeGen**（**不是** Telegram-iOS / Bazel） |
| Xcode / iOS | **Xcode 26.3** / deploymentTarget **iOS 26.0** |
| GitHub Token | `/home/workdir/artifacts/.grok/secrets/github_token` |

## 功能范围（二次开发）

仅在官方能力上增加下列体验，**保留主功能与协议**：

1. **消息级自动翻译**（`BetterTG/Services/Translation/`）
2. **内容过滤**（广告 / 关键词黑白名单）
3. **多线程下载 + 自动清理缓存 + 速度显示**
4. **群组/频道 UI**：气泡近满宽、**隐藏旁路转发圆钮**（长按菜单仍可转发）

设置统一入口：**设置 → BetterTG 扩展**。

持久化键前缀：`BetterTG.fork.*`（UserDefaults）。

### 自动翻译约定

- 设置：自动翻译开关、**显示双语**、目标语言、引擎顺序、DeepL 多 Key、Azure Key、**聊天例外**、**翻译缓存**
- 引擎默认链：Google → Bing → DeepL → Azure → MyMemory（可排序/禁用）
- Google / Bing / MyMemory **免 Key**；DeepL 支持多 Key 轮换；Azure 需 Key
- **文本级缓存**（SHA256）：相同原文跨消息复用；可在设置清空
- **按聊天覆盖**：`isAutoTranslateEnabled(chatID:)` = 例外 ?? 全局开关
- 双语开：原文 + 译文；双语关：默认译文，点击切换原文/译文
- 显示：先「翻译中…」，译文到达后淡入；滚动中禁止 `invalidateLayout()`
- 消息字号：设置 → BetterTG 扩展 → 消息文字大小（85%–150%）
- 不破坏官方 translateChats / Premium 流程

### 内容过滤约定

- 入口：BetterTG 扩展 → 内容过滤
- 白名单优先于黑名单；黑/白名单为可增删排序列表（一行一词）
- `hideAds` 时不展示赞助消息

### 下载与缓存约定

- 分片可配 4–32（默认约 16）
- 前台 apply 配置；可按天数 / 上限清理

### UI 约定

- 群组 / 超级群 / 频道：气泡横向近满屏；私聊保持约 82% 宽
- 频道旁路 **share 按钮关闭**（`MessageShareButton.kind` 对非收藏夹返回 nil）
- 设置管理页：不要用易显示异常的 `editButtonItem` 实心圆；始终可拖动排序时用 `editingStyle = .none`，右侧按钮精简以免标题被挤成 “D…”

## CI / 发布

| 规则 | 说明 |
|------|------|
| **默认 push 不构建** | 仅 `workflow_dispatch` 手动触发 |
| Runner | `macos-latest`，选用 Xcode **26.3** |
| 签名 | **无签名**（`CODE_SIGNING_ALLOWED=NO`） |
| Secrets | `TELEGRAM_API_ID`、`TELEGRAM_API_HASH` |
| IPA 命名 | `BetterTG-{MARKETING_VERSION}-{CURRENT_PROJECT_VERSION}-build{run}.ipa` |
| Release 标签 | `build-{run_number}` |
| sidestore `version` | `{MARKETING_VERSION}-build{run}`，须与 Release 一致 |
| sidestore 必填 | `file`、`downloadURL`、`version`、`versionDate`、`versionDescription`、`size`、`bundleIdentifier`、`minOSVersion` |
| Source URL | https://raw.githubusercontent.com/zongai/BetterTG/main/sidestore-apps.json |

Workflow：`.github/workflows/build-ipa.yml`。

### 触发构建

```text
POST /repos/zongai/BetterTG/actions/workflows/build-ipa.yml/dispatches
body: {"ref":"main"}
```

用户说「构建」→ 手动 dispatch；「查构建」→ 查最新 run / Release / sidestore 是否对齐。

## 工程约束

- 用 XcodeGen 生成工程；源码在 `BetterTG/` 下由 folder 同步收录
- 兼容 SDK：无 iOS 27+ 独占 API 硬依赖（已 stub `UIHingeInteraction` / `reservedRegions` 等）
- C++ interop：`abs` 使用 `Swift.abs`
- 改设置 UI 时保持与系统 Settings 风格一致（insetGrouped）

## 对话工作流

1. 改代码在 clone 的仓库中完成 → commit → push `main`
2. **不要**默认因 push 触发 CI；用户明确说「构建」再 dispatch
3. 构建失败先拉 Actions 日志再修
4. `sidestore-apps.json` 与最新成功 Release 的 version / file / downloadURL / size 必须一致
5. 跨对话以本文件 + `FORK.md` + 仓库现状为准

## 关键路径备忘

```
BetterTG/Services/Translation/     翻译模块
BetterTG/Views/Settings/
  BetterTGExtensionsSettingsViewController.swift
  AutoTranslateSettingsViewController.swift
  ContentFilterSettingsViewController.swift
  DownloadCacheSettingsViewController.swift
BetterTG/Views/Message/MessageView.swift
BetterTG/Views/Message/MessageShareButton.swift
.github/workflows/build-ipa.yml
sidestore-apps.json
FORK.md
PROJECT_RULES.md                   # 本文件
```
