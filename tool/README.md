# 开发工具

## 固定 SDK

以 `tool/flutter-sdk.json`、`.flutter-version` 和 pubspec.lock 为准。命令统一用 `tool/flutterw`；Windows 用 `tool/flutterw.ps1`。

本机正式 SDK 是 `/Users/len5010/flutter`。可通过进程变量 `ASASFANS_FLUTTER_SDK` 指定该目录，不改全局 PATH、不自动安装其他 SDK。

## 当前开发方式

先完成主计划的全部 UI/组件开发阶段；中途不自动测试、构建或启动应用。不写新的材质实验、基准与证据工具。

轻量源码格式整理可按需执行；只有最终集中交付时才执行必要静态检查/编译。CI 均为手动触发，默认不运行全量测试。格式化时如 `.dart_tool` 已清理，可显式使用项目语言版本，避免因缺少 package_config 而按新语言版本重排旧代码：

```sh
ASASFANS_FLUTTER_SDK=/Users/len5010/flutter tool/flutterw --dart format --language-version=3.9 <本次修改的文件>
```

项目 SDK 是 Dart 3.13.3；上述 3.9 是 pubspec 的包语言版本，不是使用旧 SDK。

## 保留的工具

- `flutterw` / `flutterw.ps1` / `flutter_sdk.dart`：复用同一套已固定 SDK。
- `brand/generate_icons.cjs`：从原 A 路径生成四端资产，仅在确需改图标时使用。
- `preview/`：现有隔离内存数据入口。仅用户明确要求离线演示时使用，不作为开发闸门，不自动运行。

已删除独立玻璃 probe、折射对照和 3×30 秒基准工具。正式组件直接服务真实页面；材质效果由用户在最终开发包验收。参考适配许可见 `third_party/README.md`。
