# BetterTG.Windows

将 [BetterTG](https://github.com/zongai/BetterTG)（iOS）的二次开发能力移植到 [Unigram](https://github.com/TelegramMessenger/Unigram)（Windows）的扩展模块。

**本仓库路径仅包含 Windows 扩展源码，不修改也不依赖 iOS 客户端工程。**

## 功能（与 iOS PROJECT_RULES 对齐）

1. **消息级自动翻译**  
   全局开关 / 按聊天例外、双语显示、多引擎链（Google → Bing → DeepL → Azure → MyMemory）、SHA256 文本缓存、滚动中禁止强制重布局。

2. **内容过滤**  
   黑/白名单（白名单优先）、隐藏赞助消息（Ads）。

3. **多线程下载 + 缓存清理**  
   分片 4–32（默认 16）、速度显示、按天数/容量清理。

4. **群组/频道 UI**  
   气泡近满宽、隐藏频道旁路分享圆钮（菜单转发仍可用）、消息字号 85%–150%。

设置入口统一为：**设置 → BetterTG 扩展**。

## 目录结构

```
BetterTG.Windows/
  Models/           常量与翻译模型
  Services/
    BetterTGSettings.cs
    Translation/    引擎 + 缓存 + 编排
    ContentFilter/
    Download/
  ViewModels/Settings/
  Views/Settings/   XAML 设置页
  Controls/         TranslatedMessagePresenter
  Helpers/          气泡宽度、Share 可见性、滚动守卫
  Docs/INTEGRATION.md
```

## 使用方式

见 [Docs/INTEGRATION.md](Docs/INTEGRATION.md)。

简要步骤：

1. Fork Unigram  
2. 将本目录源码放入 `Telegram/BetterTG/`  
3. 在设置导航中挂上 `BetterTGExtensionsPage`  
4. 在消息 Bubble、下载、列表滚动处按文档挂钩  

## 构建说明

当前 CI 环境为 Linux，无法在沙箱内完成 WinUI 编译。请在 **Windows + Visual Studio 2022+**（含 Windows App SDK / WinUI 工作负载）上：

```powershell
# 若作为独立库
dotnet build BetterTG.Windows.csproj

# 或直接编进 Unigram 解决方案后构建 Telegram.WinUI / 主工程
```

需要自备 Telegram `api_id` / `api_hash`（Unigram 常规要求）。

## 许可

与 Unigram 一致，扩展代码按 **GPL-3.0** 使用；接入 Unigram 时遵循其 LICENSE。
