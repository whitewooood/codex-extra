# 签名与 Notarization

当前 Release 产物使用 ad-hoc 签名：

```bash
codesign --force --deep --sign - "Codex Monitor.app"
```

这足够用于本地开发和带 checksum 的 GitHub Release，但不等同于 Developer ID 签名和 Apple notarization。

## 用户可能看到什么

macOS Gatekeeper 可能提示无法验证开发者。对于当前 release 产物来说，这是预期行为。

## 后续正式分发可补充

面向更广泛用户分发时，可以继续补充：

- Developer ID Application 证书签名。
- Hardened runtime。
- Apple notarization。
- Stapled notarization ticket。

这些步骤需要 Apple Developer 账号；当前仓库暂未自动化。
