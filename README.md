# Codex 声音提醒

一个 macOS 菜单栏小工具，用来监听 Codex Desktop 的会话日志，并在任务完成或失败时直接播放本地声音。

它不依赖 macOS 通知系统，所以即使 Codex 的通知声音不响，也可以通过这个工具发出提醒。
菜单栏面板也会显示 Codex 本地日志里的最近 token 用量和限额窗口使用率。

## 功能

- 监听 `~/.codex/sessions/**/*.jsonl`。
- Codex 写入 `task_complete` 时播放完成提醒音。
- 检测到失败事件，或最后一条 assistant 消息像是失败/受阻时，播放失败提醒音。
- 菜单栏面板支持中文状态、开关、试听、选择音频文件、音量调节。
- 显示 Codex 最近 token 用量、累计 token、上下文窗口，以及 5 小时/7 天窗口使用率。
- 可选开启“命令非 0 退出也算失败”。
- 暂停监听后会丢弃暂停期间的日志进度，恢复时不会补播旧任务。

命令失败判断默认关闭，因为 Codex 经常会运行探索性命令，单个命令非 0 不一定代表整个任务失败。

## 运行

```bash
./script/build_and_run.sh
```

构建后会更新并启动 `~/Applications/Codex 声音提醒.app`。如果已经安装登录项，Run 会通过 launchd 重启已安装版本，避免留下 `dist` 里的开发进程。也可以直接使用 Codex Desktop 的 Run 按钮启动。

## 安装为常驻工具

安装到当前用户的 Applications 目录：

```bash
./script/build_and_run.sh --install
```

安装登录项，开机登录后自动启动：

```bash
./script/build_and_run.sh --install-login-item
```

移除登录项：

```bash
./script/build_and_run.sh --uninstall-login-item
```

登录项使用 `~/Library/LaunchAgents/com.whitewood.codex-sound-guard.plist`，直接运行 `~/Applications/Codex 声音提醒.app/Contents/MacOS/CodexSoundGuard`，不会修改系统级目录。

## 默认声音

- 完成：优先使用 `~/Library/Sounds/codex-notification.wav`，如果不存在则使用系统的 `Glass.aiff`。
- 失败：使用系统的 `Basso.aiff`。

可以在菜单栏面板里分别点击“选择”更换声音文件。

## 用量显示

用量来自 Codex 写入本机 JSONL 的 `token_count` 事件，包括：

- 当前会话累计 token。
- 最近一次 token 消耗。
- 模型上下文窗口。
- 5 小时和 7 天窗口的使用百分比及重置时间。

这不是 Codex 官方稳定 API，也不是云端账单查询；如果 Codex Desktop 后续调整本地日志格式，面板可能需要跟着更新。

## 失败判定

优先使用 Codex 日志里的失败事件；如果日志里没有明确失败事件，会检查最后的 assistant 消息。当前会识别“未能、无法、受阻、超时、中断、被取消、blocked、timed out、aborted”等表达，并避开“没有失败、没有报错、no error”等常见否定短语。

这仍然是对 Codex 私有 JSONL 日志的本地适配，不是 Codex 官方稳定 API。菜单栏面板会显示最近识别到的事件，用于判断日志格式是否仍然被当前版本识别。
