# 更新日志

项目的重要变化会记录在这里。

本项目参考 Keep a Changelog，并使用语义化版本。

## [0.3.3] - 2026-06-15

### 新增

- Preferences 的“启动项”改为登录时启动开关。
- Preferences 的“声音”页新增安静时段设置，可在指定时间段暂停自动完成/失败提示音。

### 变更

- 试听按钮会绕过安静时段，方便确认当前提示音配置。

## [0.3.2] - 2026-06-15

### 变更

- 重做 Preferences 窗口为侧边栏设置布局，分离通用、声音和额度配置。
- 设置页增加运行状态、日志数量、启动项状态和当前用量摘要。
- README 增加由真实 SwiftUI 渲染的 Preferences 截图。
- GitHub Release notes 改为自动读取当前版本的 CHANGELOG 条目，并把签名/公证状态放入独立分发说明。

## [0.3.1] - 2026-06-15

### 修复

- 启动时从最近 Codex 日志回填 token_count 事件，让用量趋势打开后就有最近几小时数据。
- 会话排行改为展示最近用户任务标题、最近 token、总 token 和比例条，减少只看到 session 文件名的问题。
- 设置按钮改用显式 AppKit 设置窗口，修复菜单栏应用里 Preferences 打不开的问题。

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
