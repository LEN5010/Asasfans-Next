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

## 离线原生界面检查

```sh
tool/flutterw run -d macos --target tool/preview/main.dart
```

这是显式的开发入口，带 `OFFLINE` 标记，不由正式 `lib/main.dart` 引用。使用与测试相同的内存 SQLite、内存凭证和固定日程，内容源为空；不读取应用个人库或 Keychain，不打开登录浏览器或外链，并禁止创建 HTTP 客户端。用于验证真实原生启动、窗口、导航与材质能力，不冒充真实来源/账号/数据验收。不要用生产入口代替它做“离线”检查。

## U2 材质原型（尚未接入正式页面）

```sh
tool/flutterw run -d macos --profile --target tool/glass/main.dart
```

该入口只绘制本地网格与文字，禁止网络，不读取个人库、Keychain 或 WebView。三个场景是五槽导航、按钮组与 root overlay 面板。系统透明度桥接只读；原型开关是应用内模拟，不会更改 OS 设置。

- **折射 A/B 对照**：两份相同网格、形状、模糊与色调，只改变折射率 1.0 / 1.22。回退路径不可作为真折射证据。
- **运行 3×30 秒对照**：同一 Profile 进程分别记录清晰与液态三轮滚动、UI/raster 帧时间、刷新率、原始样本与静止帧数。运行期间不要锁屏、切换应用或并发执行测试/构建；锁屏/失效路径标记的轮次无效。
- 控制台 `GLASS_PROBE_OUTPUT` / `GLASS_REFRACTION_OUTPUT` 指向当前应用沙盒中本次生成的临时 JSON/PNG。PNG 是 Flutter render capture，不冒称 OS 录屏。复制到本地证据目录后只清理该已确认的临时目录。

`ImageFilter.isShaderFilterSupported` 与 shader 加载成功只是能力信号。没有原生折射、性能、生命周期和各设备证据时，不把源码/Widget 测试记成玻璃验收完成。主库失败采用真正的实色层，不把其 standard/minimal 模糊路径称为完整液态或清晰模式。Windows/Android 尚无独立减少透明度桥接，明确返回 unavailable，而不是假称该设置已关闭。
