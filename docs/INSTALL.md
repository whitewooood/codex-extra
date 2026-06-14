# 安装

## 下载 Release

1. 打开最新的 GitHub Release。
2. 下载 `CodexUsageMeter-<version>-macOS.zip`。
3. 解压 zip 文件。
4. 将 `Codex Usage Meter.app` 移动到 `~/Applications`。
5. 启动应用。

当前 Release 构建使用 ad-hoc 签名，尚未经过 Apple notarization。macOS 可能显示 Gatekeeper 验证提示，详情见 [SIGNING.md](SIGNING.md)。

## 从源码构建

```bash
git clone https://github.com/whitewooood/codex-extra.git
cd codex-extra
./script/build_and_run.sh
```

## 安装为登录项

```bash
./script/build_and_run.sh --install-login-item
```

该命令会写入：

```text
~/Library/LaunchAgents/com.whitewood.codex-usage-meter.plist
```

## 卸载

移除登录项：

```bash
./script/build_and_run.sh --uninstall-login-item
```

删除已安装的应用：

```bash
rm -rf "$HOME/Applications/Codex Usage Meter.app"
```
