# Unigram 完整客户端集成

目标：在 [Unigram](https://github.com/TelegramMessenger/Unigram) 上编译**带 BetterTG 扩展**的完整 Windows Telegram 客户端。

## 为何不能只靠 `BetterTG.Windows.exe`

先前发布的 `BetterTG.Windows.exe` 只是扩展设置宿主，**不含** TDLib / 登录 / 聊天。

完整客户端必须：

1. 递归克隆 Unigram  
2. 配置 `api_id` / `api_hash`（[my.telegram.org](https://my.telegram.org/apps)）  
3. 还原 vcpkg 依赖、编译 TDLib  
4. 用 Visual Studio / MSBuild 编译 WinUI 工程  
5. 将 BetterTG 源码挂入消息/设置/下载路径  

官方说明：https://github.com/TelegramMessenger/Unigram/blob/develop/Documentation/Build-instructions.md  

## CI 工作流

`.github/workflows/build-unigram-client.yml`（`workflow_dispatch`）会在 `windows-latest` 上尝试上述流程。

需要仓库 Secrets（与 iOS IPA 相同）：

- `TELEGRAM_API_ID`
- `TELEGRAM_API_HASH`

首次全量编译可能耗时数小时，并受 Runner 磁盘/超时限制；失败时请查看 Actions 日志。

## 本机编译（推荐）

在 **Windows + VS 2022/2026**（含 .NET 桌面、C++、Clang、Windows 11 SDK）上：

```powershell
git clone --recursive https://github.com/TelegramMessenger/Unigram.git
# 写入 Telegram/Constants.Secret.cs（见模板）
# 将本仓库 Windows/ 下库源码按 Docs/INTEGRATION.md 挂入
# 按 Unigram Build-instructions 构建
```
