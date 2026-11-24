# BetterTG.Windows → Unigram 集成指南

本扩展**完全独立于 iOS BetterTG**，不修改任何 iOS 源码或仓库。

目标：在 [Unigram](https://github.com/TelegramMessenger/Unigram) 中落地与 iOS 版一致的二次能力。

---

## 1. 推荐集成方式

**Fork Unigram**，把本目录源码以「源文件嵌入」方式加入主工程（避免额外程序集边界问题）：

```
Telegram/
  BetterTG/                    ← 复制本仓库内容到此处
    Models/
    Services/
    ViewModels/
    Views/
    Controls/
    Helpers/
```

在 `Telegram.csproj` / `Telegram.WinUI.csproj` 中确保上述 `.cs` / `.xaml` 被编译（SDK 风格工程默认会包含）。

备选：引用 `BetterTG.Windows.csproj` 为项目引用（需对齐 WinAppSDK 版本）。

---

## 2. 设置入口

在 Unigram 主设置页（例如 `Views/Settings/SettingsPage` 或对应 ViewModel 的菜单列表）增加一项：

- 标题：`BetterTG 扩展`
- 导航目标：`typeof(BetterTG.Windows.Views.Settings.BetterTGExtensionsPage)`

在 `App.xaml.cs`（或导航表）注册页面解析，与现有 `Settings*Page` 并列。

---

## 3. 自动翻译挂钩

### 3.1 消息文本渲染

在消息 Bubble 文本绑定处（通常在 `Controls/Messages` 或 Message ViewModel）：

```csharp
// 伪代码 — 按实际控件名调整
var presenter = new TranslatedMessagePresenter();
presenter.Bind(
    chatId,
    messageId,
    originalPlainText,
    setText: text => messageTextBlock.Text = text,
    setBilingual: (orig, trans) =>
    {
        originalBlock.Text = orig;
        translationBlock.Text = trans ?? string.Empty;
        translationBlock.Visibility = trans != null ? Visibility.Visible : Visibility.Collapsed;
    });
```

在消息回收 / 卸载时调用 `presenter.Unbind()`。

### 3.2 滚动安全

在消息 `ListView` / `ScrollViewer` 上：

```csharp
scrollViewer.ViewChanged += (s, e) =>
{
    if (e.IsIntermediate)
        ScrollingLayoutGuard.Current.NotifyScroll();
    else
        ScrollingLayoutGuard.Current.EndScroll();
};
```

翻译结果回调中：若 `ScrollingLayoutGuard.Current.ShouldDeferLayoutChanges`，只改 `Text`，不要改 Visibility / 高度。

### 3.3 按聊天开关

```csharp
BetterTGSettings.Current.IsAutoTranslateEnabled(chatId)
BetterTGSettings.Current.SetChatException(chatId, enabled: true|false|null)
```

---

## 4. 内容过滤挂钩

在消息即将加入列表 / 渲染前：

```csharp
var text = message.GetPlainText(); // 宿主实现
var isSponsored = message is MessageSponsored /* 或等价判断 */;
if (ContentFilterService.Current.ShouldHideMessage(text, isSponsored))
{
    // skip rendering / do not add to ItemsSource
}
```

**不要**从 TDLib 数据库删除消息，只影响展示。

---

## 5. 多线程下载

对支持 HTTP Range 的直链大文件：

```csharp
await MultiThreadDownloadService.Current.DownloadAsync(
    taskId: fileId.ToString(),
    url: downloadUrl,
    destinationPath: localPath,
    cancellationToken);
```

订阅 `ProgressChanged` 更新 UI 速度（当 `ShowDownloadSpeed` 为 true）。

TDLib 官方文件流仍走 Unigram 原有路径；本服务用于可加速的直链场景，分片数读取 `BetterTGSettings.Current.DownloadChunkCount`。

缓存清理：

```csharp
var vm = new DownloadCacheSettingsViewModel
{
    CacheRoots = new[] { /* Unigram temp / media paths */ }
};
await vm.RunCleanupAsync();
```

---

## 6. 气泡宽度与分享按钮

### 气泡宽度

在计算 bubble `MaxWidth` 时：

```csharp
var kind = MapChatType(chat); // Private / BasicGroup / Supergroup / Channel
var maxW = MessageBubbleLayoutHelper.GetMaxBubbleWidth(availableWidth, kind);
```

### 隐藏频道旁路 Share

在决定是否显示 bubble 旁路分享圆钮时：

```csharp
var show = ShareButtonVisibilityHelper.ShouldShowInlineShareButton(kind, isSavedMessages);
shareButton.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
```

右键 / 长按菜单中的「转发」保持可用。

### 字号

```csharp
var scale = MessageBubbleLayoutHelper.GetMessageFontScale();
messageTextBlock.FontSize = baseFontSize * scale;
```

---

## 7. 启动时

在应用启动（登录后）可选：

```csharp
await TranslationCache.Current.LoadAsync();
```

退出或定时：

```csharp
await TranslationCache.Current.PersistAsync();
```

---

## 8. 与官方翻译的关系

- Unigram / TDLib 自带的 Translate 按钮与 Premium 流程**不要删除**。
- 本模块是额外的自动翻译层，仅在 `BetterTGSettings` 开启时改写展示文本。

---

## 9. 持久化

全部键在 `ApplicationData.LocalSettings` 容器 `BetterTG.Fork` 下，前缀 `BetterTG.fork.*`，与 Unigram 核心设置隔离，也与 iOS `UserDefaults` 无任何共享。

---

## 10. 验收清单

- [ ] 设置 → BetterTG 扩展 可打开，子页可导航
- [ ] 自动翻译：开关、双语、引擎顺序、DeepL/Azure Key、缓存清空
- [ ] 单聊 / 群聊自动出译文；滚动时无异常卡顿或崩溃
- [ ] 内容过滤：黑白名单、隐藏 Ads
- [ ] 分片数变更后新下载生效；清理缓存可执行
- [ ] 群组/频道气泡更宽；频道旁路 Share 隐藏；私聊宽度不变
- [ ] iOS 仓库与构建完全未改动
