# 固定的 Flutter 工具链

`flutter-sdk.json` 固定官方 stable 版本、完整 revision、Dart 版本与各宿主压缩包的 SHA-256。不要用 `flutter upgrade` 或浮动的 `stable` 替代这个清单。

## 安装

1. 按宿主与 CPU 选择清单中的 `artifacts` 项，下载其 `url`。
2. 使用 `shasum -a 256`（macOS）、`sha256sum`（Linux）或 `Get-FileHash -Algorithm SHA256`（Windows）校验下载文件，与清单的 `sha256` 完整比较。
3. 只有校验一致才解压。可更新原有独立 SDK 目录，保持其 PATH 不变；若由 Homebrew/FVM 等管理，则按管理器方式安装并重新校验。不对有本地修改的 SDK 直接覆盖。
4. `tool/flutterw --verify-sdk`（Windows：`tool/flutterw.ps1 --verify-sdk`）确认 SDK。启动脚本使用该 SDK 自带 Dart，不需要 Python、FVM 或额外 pub 包。

默认校验 PATH 中安装的 Flutter；也可用进程环境变量 `ASASFANS_FLUTTER_SDK` 显式选择同版本 SDK，例如 CI 的 `FLUTTER_ROOT`。使用 FVM/shim 或项目 `.toolchains/flutter/<version>/` 隔离安装时，也请设置该变量指向真实 SDK 根目录。这不放宽版本检查，脚本不修改系统 PATH、不自动下载，校验失败不回退到其他 SDK。回退时同时恢复工程与锁文件，不能混用。

## 使用

```sh
tool/flutterw --version --machine
tool/flutterw pub get --enforce-lockfile
tool/flutterw --dart format --output=none --set-exit-if-changed lib test tool
tool/flutterw analyze --no-pub
tool/flutterw test --no-pub
```

Windows 使用 `tool/flutterw.ps1` 和相同参数。命令在仓库根目录执行，参数原样传给 Flutter；`--dart` 则传给同一套 SDK 的 Dart。SDK 缺失、Git revision 不符、SDK 源码有改动或缓存版本不符会明确失败，不静默继续。

IDE 的 Flutter SDK 路径也应指向同一目录。本机绝对路径、SDK 二进制、下载包及生成配置不提交。SDK 版本升级必须一起检查清单、pubspec、锁文件与 CI；新版本构建成功不等于真机或生产签名验收通过。
