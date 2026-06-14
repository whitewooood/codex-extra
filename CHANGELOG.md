# 更新日志

项目的重要变化会记录在这里。

本项目参考 Keep a Changelog，并使用语义化版本。

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
