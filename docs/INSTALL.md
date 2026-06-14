# 安装

## 下载 Release

1. 打开最新的 GitHub Release。
2. 下载 `CodexMonitor-<version>-macOS.dmg`。
3. 打开 dmg 文件。
4. 将 `Codex Monitor.app` 拖到 Applications。
5. 启动应用。

也可以下载 `CodexMonitor-<version>-macOS.zip`，手动解压后移动到 `~/Applications`。

当前 Release 构建使用 ad-hoc 签名，尚未经过 Apple notarization。macOS 可能显示 Gatekeeper 验证提示，详情见 [SIGNING.md](SIGNING.md)。

## 从源码构建

```bash
git clone https://github.com/whitewooood/codex-extra.git
cd codex-extra
./script/build_and_run.sh
```

## 安装为登录项

从 App 的 Preferences 开启“登录时启动”时，macOS 13 或更新版本会优先使用系统登录项服务。

源码脚本也可以安装当前用户的 LaunchAgent：

```bash
./script/build_and_run.sh --install-login-item
```

该命令会写入：

```text
~/Library/LaunchAgents/com.whitewood.codex-monitor.plist
```

## 卸载

移除登录项：

```bash
./script/build_and_run.sh --uninstall-login-item
```

删除已安装的应用：

```bash
rm -rf "$HOME/Applications/Codex Monitor.app"
```
