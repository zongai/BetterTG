# 落地完成检查清单

## 已实现模块

### P1 设置与配置
- [x] `BetterTGSettings` — ApplicationData 容器 `BetterTG.Fork`，键前缀 `BetterTG.fork.*`
- [x] 自动翻译 / 过滤 / 下载 / UI 全部配置项
- [x] 按聊天例外（JSON）
- [x] 设置 ViewModels + XAML 页面（扩展入口、自动翻译、内容过滤、下载缓存）

### P2–P3 自动翻译
- [x] 五引擎：Google、Bing、DeepL（多 Key 轮换）、Azure、MyMemory
- [x] 可排序引擎链 + 启用开关
- [x] SHA256 文本缓存（内存 + 可选落盘）
- [x] `TranslationService` 编排、状态机、「翻译中…」
- [x] 双语 / 点击切换（`ToggleShowOriginal`）
- [x] `ScrollingLayoutGuard` + `IsListScrolling`（滚动中不强制改布局）
- [x] `TranslatedMessagePresenter` 绑定辅助

### P4 内容过滤
- [x] 黑/白名单（白名单优先）
- [x] `HideAds` 赞助消息
- [x] `ShouldHideMessage` 统一入口

### P5 下载与缓存
- [x] 分片 4–32，Range 多线程下载 + 单流回退
- [x] 进度 / 速度事件
- [x] 按天数 + 容量清理

### P6 UI 规则
- [x] 群组/频道近满宽、私聊 ~82%
- [x] 频道旁路 Share 隐藏（Saved Messages 除外）
- [x] 消息字号 85%–150%

### 文档
- [x] README.md
- [x] INTEGRATION.md
- [x] HOOK_SNIPPETS.md
- [x] CHECKLIST.md

## 未在本沙箱执行（需 Windows 主机）

- [ ] 克隆 Unigram 并嵌入源码
- [ ] Visual Studio 编译通过
- [ ] 真机/虚拟机联调 TDLib 消息流

## iOS 隔离确认

- 未修改 `/home/workdir/artifacts/BetterTG*` 下任何 iOS 业务源码
- 未修改 `PROJECT_RULES.md` 的 iOS CI / Bundle 规则
- Windows 代码全部位于 `artifacts/BetterTG.Windows/`
