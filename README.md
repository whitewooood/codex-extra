# Codex 声音提醒

一个 macOS 菜单栏小工具，用来监听 Codex Desktop 的会话日志，并在任务完成或失败时直接播放本地声音。

它不依赖 macOS 通知系统，所以即使 Codex 的通知声音不响，也可以通过这个工具发出提醒。

## 功能

- 监听 `~/.codex/sessions/**/*.jsonl`。
- Codex 写入 `task_complete` 时播放完成提醒音。
- 检测到失败事件，或最后一条 assistant 消息像是失败/受阻时，播放失败提醒音。
- 菜单栏面板支持中文状态、开关、试听、选择音频文件、音量调节。
- 可选开启“命令非 0 退出也算失败”。

命令失败判断默认关闭，因为 Codex 经常会运行探索性命令，单个命令非 0 不一定代表整个任务失败。

## 运行

```bash
./script/build_and_run.sh
```

构建后会启动 `dist/Codex 声音提醒.app`。也可以直接使用 Codex Desktop 的 Run 按钮启动。

## 默认声音

- 完成：优先使用 `~/Library/Sounds/codex-notification.wav`，如果不存在则使用系统的 `Glass.aiff`。
- 失败：使用系统的 `Basso.aiff`。

可以在菜单栏面板里分别点击“选择”更换声音文件。
