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

## 菜单栏显示

Preferences 的“通用”页可以选择菜单栏显示模式：

- 仅图形。
- 5 小时用量百分比。
- 7 天用量百分比。
- 最近 token。

## 失败判定

“命令非 0 退出也算失败”默认关闭。Codex 经常会运行探索性命令，单个命令非 0 不一定代表整个任务失败。

## 用量阈值

Preferences 的“阈值”页保存 5 小时窗口和 7 天窗口的剩余额度提醒阈值。当前版本先集中管理阈值配置，后续可以在此基础上加入低额度声音或系统通知。

## 重置偏好设置

退出应用后，删除偏好设置：

```bash
defaults delete com.whitewood.codex-monitor
```
