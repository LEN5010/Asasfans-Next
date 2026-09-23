# Asasfans Next

<p align="center">
  <img src="assets/brand/asasfans.png" alt="Asasfans Next" width="120" />
</p>

### 若有一天我会离开. 这座城是否还在.        她们会不会依然像现在. 这样日复一日笑着走来
### 若有一天你也离开. 会不会偶尔感怀.        再看看当时艰难和愉快. 再听听那些. 夸张的告白.

Asasfans Next 是一个面向 A-SOUL 粉丝的聚合客户端，你可以在这里找到 A-SOUL相关视频、二创、历史动态、小说、日程和社区工具。

本项目保留了早期开源项目 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans) 的历史来源，后续由当前仓库继续维护和重构，并继续遵循 GPL-2.0 协议发布。

感谢 [jiarandiana0307](https://github.com/jiarandiana0307) 在 2025 年对其 [Fork 版本](https://github.com/jiarandiana0307/as-as-fans) 的维护和更新。

感谢 [枝江站](https://asoul.love/)、[ASOUL录音棚](https://studio.asoul.us.kg/) 等 A-SOUL 社区项目。

## 官网与相关站点推荐

- 项目官网：[fan.asoul.us.kg](https://fan.asoul.us.kg/)
- 该官网由 [jiarandiana0307](https://github.com/jiarandiana0307) 维护
- 同时本仓库的重构工作直接从 [jiarandiana0307/as-as-fans](https://github.com/jiarandiana0307/as-as-fans) 的 Fork 起步
- 也推荐关注他维护的其他站点：[枝网查重](https://cnki.asoul.us.kg/)、[枝江文库](https://book.asoul.us.kg/)、[A-SOUL Wiki](https://wiki.asoul.us.kg/)。

Asasfans Next 是非官方粉丝项目，与 Bilibili、A-SOUL 及枝江娱乐等相关公司没有官方关联。

## 3.0（开发中）

`main` 分支上是 Flutter 版，版本号 `3.0.0-dev.1+201` 只是开发标识，还没有正式发行，暂时也不能完全替代旧版。

原生 Android 版在 [v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0) 画上了句号，源码和安装包都留在这个标签和 `old` 分支里，想用稳定版的话可以继续装它。项目从 2022 年一路走到现在的经过、旧版的功能和技术参数，都写在 [HISTORY.md](HISTORY.md) 里。

## 功能

- **今日**：今天的日程、历史上的今天、最新切片和最新二创。手机上从上往下排，宽屏时日程和历史左右并排。
- **内容**：视频、二创、动态、小说四个频道。
  - 视频来自 asasfans 后端索引，分全部 / 切片 / 录播，点开跳到 B 站观看。
  - 二创有成员和分类快捷筛选，宽屏用错位瀑布流，手机用紧凑双列。
  - 历史动态保留头像、表情、图片、视频和转发，可以按成员、类型、日期筛选。
  - 小说可以在应用里阅读，R18 作品只显示作品信息和原帖链接。
- **日历**：日、周、月视图，按成员和类型筛选，可关注日程并在应用内收到变动提醒。
- **我的**：收藏、稍后看、浏览记录、时间书签、本地订阅、内容规则。
- **工具**：底栏右侧的圆钮打开工具面板，可见录音棚、日历、动态站、枝网查重、Wiki 等社区站点。
- 手机用悬浮底栏，宽屏用侧栏；主栏目切换、页面转场和加载都有动画，系统关闭动画时会自动跳过。

## 构建

Flutter 固定为 **3.47.3**（Dart **3.13.3**），下载地址和校验值记在 `tool/flutter-sdk.json`。请用仓库自带的启动脚本，它会先核对本机 SDK 的版本：

```sh
tool/flutterw pub get --enforce-lockfile
tool/flutterw analyze --no-pub
tool/flutterw build macos --profile --no-pub
```

Windows 上用 `tool/flutterw.ps1`，格式化用 `tool/flutterw --dart format`。更完整的工具链说明见 [tool/README.md](tool/README.md)。

各平台要求：

- iOS 15 / macOS 12 起，需要 Xcode 和对应的签名配置。
- Android 最低 API 24，Java 编译目标 17，Android SDK 36。
- Windows 需要 Visual Studio 的 C++ 桌面开发组件，只能在 Windows 上构建。

### GitHub Actions

两条 workflow 都只能手动触发，推送和 PR 不会自动运行：

- `Flutter Checks`：固定 SDK 的格式检查和静态分析，勾选 `run_tests` 时再跑全量测试。
- `Flutter Development Validation`：构建 Android Debug、iOS Debug（无签名）和 macOS / Windows Profile 开发包，不签名，也不发布。

Android 开发包的包名是 `asasfans.next.flutterdev`，可以和旧版 `asasfans.next` 装在同一台手机上。正式包会沿用 `asasfans.next` 和原来的签名，在确认能覆盖安装旧版之前，正式发布会一直暂停。签名文件和密码只放在本地，不要提交到仓库。

## 反馈

问题反馈和功能建议请提交到 [GitHub Issues](https://github.com/LEN5010/Asasfans-Next/issues)。

## 许可证

本项目基于 GNU General Public License v2.0 发布，详见 [LICENSE](./LICENSE)。

如果你分发修改后的安装包或其他二进制构建产物，需要同时提供对应源码，并保留原项目和本项目的版权及许可证说明。第三方组件的许可见 `third_party/README.md`。
