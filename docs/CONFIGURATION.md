# 配置

Codex Monitor 会将偏好设置保存在当前用户的 `UserDefaults` 中。

## 会话日志目录

默认目录：

```text
~/.codex/sessions
```

应用会扫描该目录下最近的 `.jsonl` 文件，并监听 Codex 写入的 `token_count`、`task_complete` 等事件。

## 提示音

默认完成提示音：

```text
~/Library/Sounds/codex-notification.wav
```

如果该文件不存在，会回退到：

```text
/System/Library/Sounds/Glass.aiff
```

默认失败提示音：

```text
/System/Library/Sounds/Basso.aiff
```

你可以在设置的“声音”页选择自定义音频文件，并调整音量。

## 安静时段

设置的“声音”页可以开启安静时段，并设置开始/结束时间。安静时段内会暂停自动完成/失败提示音；“试听”按钮仍会播放，方便确认声音文件和音量。

## 菜单栏显示

设置的“通用”页可以选择菜单栏显示模式：

- 仅图形。
- 5 小时用量百分比。
- 7 天用量百分比。
- 最近用量。

## 失败判定

“命令失败也提醒”默认关闭。Codex 经常会运行探索性命令，单个命令非 0 不一定代表整个任务失败。

## 登录时启动

设置的“通用”页提供登录时启动开关。macOS 13 或更新版本会优先使用系统 Login Items 服务；在开发构建或系统服务不可用时，会回退到当前用户的 LaunchAgent：

```text
~/Library/LaunchAgents/com.whitewood.codex-monitor.plist
```

LaunchAgent 使用 `/usr/bin/open -gj Codex Monitor.app` 启动应用，避免直接执行 app 内部二进制。若 LaunchAgent 指向的 App 已被移动、删除，或仍使用旧启动方式，设置会显示需要修复；点击“修复登录项”即可重写并重新加载配置。

## 更新检查

设置的“通用”页可以开启自动检查更新。该功能默认关闭；开启后，应用每天最多请求一次 GitHub Releases latest API；发现新版本时只显示提醒，并打开 GitHub Release 下载页，不会自动下载或替换应用。

菜单面板底部的“更新”按钮可以随时手动检查。

## 用量阈值

设置的“额度”页可以开启或关闭额度提醒配置，并保存 5 小时窗口和 7 天窗口的剩余额度提醒阈值。关闭额度提醒配置时阈值会保留，但不可编辑。

## 重置偏好设置

退出应用后，删除偏好设置：

```bash
defaults delete com.whitewood.codex-monitor
```
