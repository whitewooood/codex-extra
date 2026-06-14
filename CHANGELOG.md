# 更新日志

项目的重要变化会记录在这里。

本项目参考 Keep a Changelog，并使用语义化版本。

## [0.3.0] - 2026-06-15

### 新增

- 最近 6 小时 token 用量趋势图。
- 最近 Codex session token 用量排行。
- 独立 Preferences 窗口，用于管理声音、登录项、阈值和菜单栏显示模式。
- 菜单栏显示模式支持仅图形、5 小时百分比、7 天百分比和最近 token。
- DMG 背景图与 Applications 拖拽安装指引。

## [0.2.0] - 2026-06-14

### 变更

- 用户可见名称从 Codex Usage Meter 改为 Codex Monitor，更准确覆盖用量、状态和提醒用途。
- Release 产物新增 macOS dmg，保留 zip 作为备用下载格式。
- README 改用由真实 SwiftUI 界面渲染的 PNG 截图。
- 打包脚本和登录项 bundle id 更新为 `com.whitewood.codex-monitor`，并保留旧版本清理逻辑。

## [0.1.0] - 2026-06-14

### 新增

- macOS 菜单栏 Codex 本地 token 用量图形指示器。
- 5 小时窗口与 7 天窗口剩余额度显示。
- 以 Codex 用量、状态和提醒设置为核心的菜单栏面板。
- 基于 Codex 本地 JSONL 日志的完成与失败声音提醒。
- 使用用户级 LaunchAgent 的登录项安装脚本。
- 覆盖日志解析、回放和失败分类的 Swift 测试。
- GitHub Actions CI。

### 备注

- 当前应用为本地使用做 ad-hoc 签名，尚未 notarize。
- Codex JSONL 日志属于 Codex Desktop 的私有实现细节，未来版本可能变化。
