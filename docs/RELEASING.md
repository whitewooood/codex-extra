# 发布

## 版本

在 `VERSION` 中写入下一个语义化版本号。

## 本地打包

```bash
./script/package_release.sh
```

产物会写入：

```text
dist/release/CodexUsageMeter-<version>-macOS.zip
dist/release/CodexUsageMeter-<version>-macOS.zip.sha256
```

## GitHub Release

1. 提交版本号和 changelog 更新。
2. 创建并推送 tag：

   ```bash
   git tag v<version>
   git push origin main v<version>
   ```

3. GitHub Release workflow 会构建 macOS zip，并发布 release assets。

## 备注

Release 产物使用 ad-hoc 签名，尚未 notarize。详情见 [SIGNING.md](SIGNING.md)。
