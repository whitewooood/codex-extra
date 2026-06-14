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

你可以在 Preferences 的“声音”页选择自定义音频文件，并调整音量。

## 安静时段

Preferences 的“声音”页可以开启安静时段，并设置开始/结束时间。安静时段内会暂停自动完成/失败提示音；“试听”按钮仍会播放，方便确认声音文件和音量。

## 菜单栏显示

Preferences 的“通用”页可以选择菜单栏显示模式：

- 仅图形。
- 5 小时用量百分比。
- 7 天用量百分比。
- 最近 token。

## 失败判定

“命令非 0 退出也算失败”默认关闭。Codex 经常会运行探索性命令，单个命令非 0 不一定代表整个任务失败。

## 登录时启动

Preferences 的“通用”页提供登录时启动开关。macOS 13 或更新版本会优先使用系统 Login Items 服务；在开发构建或系统服务不可用时，会回退到当前用户的 LaunchAgent：

```text
~/Library/LaunchAgents/com.whitewood.codex-monitor.plist
```

如果 LaunchAgent 指向的 App 已被移动或删除，Preferences 会显示失效状态，重新开启即可写入新的位置。

## 更新检查

Preferences 的“通用”页可以开启自动检查更新。该功能默认关闭；开启后，应用每天最多请求一次 GitHub Releases latest API；发现新版本时只显示提醒，并打开 GitHub Release 下载页，不会自动下载或替换应用。

菜单面板底部的“更新”按钮可以随时手动检查。

## 用量阈值

Preferences 的“阈值”页保存 5 小时窗口和 7 天窗口的剩余额度提醒阈值。当前版本先集中管理阈值配置，后续可以在此基础上加入低额度声音或系统通知。

## 重置偏好设置

退出应用后，删除偏好设置：

```bash
defaults delete com.whitewood.codex-monitor
```
