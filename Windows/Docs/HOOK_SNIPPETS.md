# Unigram 挂钩代码片段（复制后按实际类型名调整）

## A. 设置菜单项

在 Settings 列表构造处增加：

```csharp
// 示例：SettingsViewModel 或 SettingsPage 的菜单集合
items.Add(new SettingsMenuItem
{
    Title = "BetterTG 扩展",
    Glyph = "\uE8D1", // 或任意 Fluent 图标
    PageType = typeof(BetterTG.Windows.Views.Settings.BetterTGExtensionsPage)
});
```

## B. ChatType → BetterTGChatKind

```csharp
using BetterTG.Windows.Helpers;
using Telegram.Td.Api;

static BetterTGChatKind MapKind(Chat chat)
{
    return chat.Type switch
    {
        ChatTypePrivate => BetterTGChatKind.Private,
        ChatTypeSecret => BetterTGChatKind.Secret,
        ChatTypeBasicGroup => BetterTGChatKind.BasicGroup,
        ChatTypeSupergroup s when s.IsChannel => BetterTGChatKind.Channel,
        ChatTypeSupergroup => BetterTGChatKind.Supergroup,
        _ => BetterTGChatKind.Private
    };
}
```

## C. 消息列表滚动

```csharp
using BetterTG.Windows.Helpers;

void OnMessagesViewChanged(object sender, ScrollViewerViewChangedEventArgs e)
{
    if (e.IsIntermediate)
        ScrollingLayoutGuard.Current.NotifyScroll();
    else
        ScrollingLayoutGuard.Current.EndScroll();
}
```

## D. 过滤入列表

```csharp
using BetterTG.Windows.Services.ContentFilter;

bool ShouldShow(Message message)
{
    var text = message.GetCaptionOrText(); // 宿主已有工具方法
    var sponsored = message.Content is MessageSponsoredMessage; // 按 TDLib 实际类型
    return !ContentFilterService.Current.ShouldHideMessage(text, sponsored);
}
```

## E. 气泡 MaxWidth

```csharp
using BetterTG.Windows.Helpers;

double available = messagesPanel.ActualWidth - padding;
var kind = MapKind(currentChat);
bubble.MaxWidth = MessageBubbleLayoutHelper.GetMaxBubbleWidth(available, kind);
```

## F. 旁路 Share 按钮

```csharp
using BetterTG.Windows.Helpers;

bool showShare = ShareButtonVisibilityHelper.ShouldShowInlineShareButton(
    MapKind(chat),
    isSavedMessages: chat.Id == clientService.Options.MyId /* 或宿主等价判断 */);
inlineShareButton.Visibility = showShare ? Visibility.Visible : Visibility.Collapsed;
```

## G. 启动加载翻译缓存

```csharp
// App 启动或 Session 就绪后
_ = BetterTG.Windows.Services.Translation.TranslationCache.Current.LoadAsync();
```
