# BetterTG Fork (zongai)

基于 [BetterTG](https://github.com/levochkaa/BetterTG) 的二次开发，保留官方主功能与协议，增加体验与 CI。

> **说明：** 本仓库是 **BetterTG（UIKit + TDLib + XcodeGen）**，不是 Telegram-iOS（Bazel）。CI 使用 `xcodebuild` 产出未签名 IPA，而不是 Bazel `release_arm64`。

## 与官方差异

| 功能 | 入口 | 默认 |
|------|------|------|
| 消息级自动翻译 | 设置 → **BetterTG 扩展** → 自动翻译 | 关 |
| 内容过滤（广告 / 关键词） | 设置 → **BetterTG 扩展** → 内容过滤 | 关 |
| 多线程下载 + 缓存清理 + 速度 | 设置 → **BetterTG 扩展** → 下载与缓存 | 多线程开 / 清理关 |

设置均通过 `UserDefaults`（`BetterTG.fork.*` 键）持久化。

### 1. 自动翻译

- 模块：`BetterTG/Services/Translation/`
  - `TranslationTypes` / `TranslationServices` / `TranslationCoordinator` / `AutoTranslator` / `TranslationSettings`
- 引擎链：Google → DeepL → Azure → MyMemory（可 failover、冷却、磁盘缓存）
- DeepL / Azure 需在设置中填写 API Key；Google / MyMemory 无需 Key
- 开启后对可见文本消息调用 `translateIfNeeded`（已是目标语言则跳过）
- 官方「显示翻译按钮」与 Premium 翻译流程保留；自动翻译独立开关

### 2. 内容过滤

- `ContentFilterSettings`：`hideAds`、`filterEnabled`、黑名单 / 白名单（白名单优先）
- 隐藏赞助消息：`ChatSponsoredMessagesContext.activate()` 在 `hideAds` 时直接返回
- 关键词：合并消息列表时过滤文本消息

### 3. 下载与缓存

- `DownloadCacheSettings` + `MultipartDownloadConfig`（分片 4–32，默认 16）
- 前台时 `DownloadCacheSettings.applyOnForeground()` 应用配置并按间隔清理临时/缓存目录
- `DownloadSpeedTracker`：媒体下载状态无障碍文案附带实时速度（如 `1.2 MB / 5.0 MB · 2.5 MB/s`）

## 构建与安装 IPA

1. 仓库 Secrets：`TELEGRAM_API_ID`、`TELEGRAM_API_HASH`（[my.telegram.org](https://my.telegram.org)）
2. Actions → **Build Unsigned IPA** → **Run workflow**（默认 push 不触发，仅手动构建）
3. Artifact 下载 `BetterTG-unsigned-ipa`，或从 Release `build-N` 获取  
   命名：`BetterTG-{version}-{build}-build{run}.ipa`
4. 使用 SideStore / TrollStore 等安装未签名包（需自签或相应工具）
5. `sidestore-apps.json` 在成功构建后由 CI 回写版本信息

### 本地

```bash
./setup.sh --api-id ID --api-hash HASH --no-relay --bundle-id com.zongai.BetterTG
./build.sh build --no-code-signing --release
```

需要 Xcode 26.3（CI 与当前工程对齐）。
