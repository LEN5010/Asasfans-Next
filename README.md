<p align="center">
  <img src="assets/brand/asasfans.png" alt="Asasfans Next" width="112" />
</p>

<h1 align="center">Asasfans Next</h1>

<p align="center">
  A-SOUL 粉丝的聚合客户端：二创、视频、动态、小说、日程和社区工具，放在一个应用里。
</p>

<p align="center">
  <a href="https://github.com/LEN5010/Asasfans-Next/releases"><img alt="Release" src="https://img.shields.io/github/v/release/LEN5010/Asasfans-Next?include_prereleases&label=%E7%89%88%E6%9C%AC&color=E799B0" /></a>
  <img alt="Platforms" src="https://img.shields.io/badge/%E5%B9%B3%E5%8F%B0-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-8A3E59" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47.3-02569B?logo=flutter" />
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/LEN5010/Asasfans-Next?label=%E8%AE%B8%E5%8F%AF%E8%AF%81" /></a>
</p>

<p align="center">
  <a href="https://github.com/LEN5010/Asasfans-Next/releases">下载</a> ·
  <a href="https://github.com/LEN5010/Asasfans-Next/issues">反馈</a> ·
  <a href="https://fan.asoul.us.kg/">项目官网</a> ·
  <a href="HISTORY.md">项目历史</a>
</p>

<h3 align="center">若有一天我会离开. 这座城是否还在. 她们会不会依然像现在. 这样日复一日笑着走来</h3>
<h3 align="center">若有一天你也离开. 会不会偶尔感怀. 再看看当时艰难和愉快. 再听听那些. 夸张的告白.</h3>

<p align="center">
  <img src=".github/readme/phones.png" alt="今日、二创、二创详情和日历页面" />
</p>

## 功能

- **今日**：本周日程条，每天的成员色点一眼看清；下一场直播浮在最前，还有多久开始写在旁边。下面是随机二创、最新切片和历史上的今天。
- **二创**：按成员、分类、类型筛选和搜索，图文在应用里看大图和原图，视频跳到 B 站。随机二创是单独的一页，往下滑会一直抽新的。
- **视频**：来自 asasfans 后端索引，分全部 / 切片 / 录播，点开去 B 站观看。
- **动态**：历史动态单列阅读，保留表情、图片、视频、预约和转发，可以按成员、类型、日期筛选。
- **小说**：卡片瀑布流，全年龄作品直接在应用里读，R18 作品只显示作品信息。
- **日历**：日 / 周 / 月视图，按成员和类型筛选；关注的日程有变动时，应用里会提醒。
- **我的**：收藏、稍后看、浏览记录、时间书签、本地订阅、内容规则、备份与恢复，资料只存在本机。
- **工具**：录音棚、日历、动态站、枝网查重、Wiki 等社区站点，从底栏右侧的圆钮打开。
- **检查更新**：启动时查一次 GitHub 有没有新版本，也可以在 我的 → 应用 里手动检查。

成员应援色贯穿日程、标签和头像，支持浅色和深色主题。手机用悬浮底栏，平板和电脑用侧栏，系统关闭动画、调大字体时界面会跟着变化。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/readme/desktop-dark.png" />
  <img src=".github/readme/desktop.png" alt="电脑宽屏上的今日页面" />
</picture>

<sub>截图中的作品、作者和日程是演示数据。</sub>

## 下载

在 [Releases](https://github.com/LEN5010/Asasfans-Next/releases) 页面下载对应平台的文件：

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Android 7.0+ | `-android.apk` | 签名与 2.0 相同，可以覆盖安装 |
| Windows 10+（x64） | `-windows-x64.zip` | 解压后运行 `asasfans_next.exe` |
| macOS 12+ | `-macos.zip` | 未经 Apple 公证，首次请右键点应用 → 打开 |
| iOS 15+ | 暂不提供 | 可以自行从源码构建 |

3.0 是 Flutter 重写的版本，目前处于预发布阶段。原生 Android 版停在 [v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0)，源码在该标签和 `old` 分支里。2.0 的收藏、订阅和屏蔽规则不会迁移到 3.0。

## 从源码构建

Flutter 固定为 **3.47.3**（Dart **3.13.3**），下载地址和校验值记在 `tool/flutter-sdk.json`。请用仓库自带的启动脚本，它会先核对本机 SDK 的版本：

```sh
tool/flutterw pub get --enforce-lockfile
tool/flutterw analyze --no-pub
tool/flutterw build macos --profile --no-pub
```

Windows 上用 `tool/flutterw.ps1`，格式化用 `tool/flutterw --dart format`。更完整的工具链说明见 [tool/README.md](tool/README.md)。

- iOS 15 / macOS 12 起，需要 Xcode 和对应的签名配置。
- Android 最低 API 24，Java 编译目标 17，Android SDK 36。
- Windows 需要 Visual Studio 的 C++ 桌面开发组件，只能在 Windows 上构建。

Android 开发包的包名是 `asasfans.next.flutterdev`，可以和正式版装在同一台手机上。正式包沿用 `asasfans.next` 和原来的签名；签名文件和密码只放在本地或 CI 密钥里，不要提交到仓库。

### GitHub Actions

所有 workflow 都只能手动触发，推送和 PR 不会自动运行：

- `Flutter Checks`：固定 SDK 的格式检查和静态分析，勾选 `run_tests` 时再跑全量测试。
- `Flutter Development Validation`：构建 Android Debug、iOS Debug（无签名）和 macOS / Windows Profile 开发包，不签名，也不发布。
- `Flutter Release`：为已有的版本标签构建签名 APK、Windows 和 macOS 安装包，放进一个草稿 Release，确认后再手动发布。
- `Flutter Performance Validation`：按需构建独立身份的 Android 性能测量包及体积报告。

## 致谢

本项目源自 2022 年的开源项目 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans)，由当前仓库继续维护和重构，并继续遵循 GPL-2.0 协议发布。

感谢 [jiarandiana0307](https://github.com/jiarandiana0307) 在 2025 年对其 [Fork 版本](https://github.com/jiarandiana0307/as-as-fans) 的维护和更新，本仓库的重构工作就是从这个 Fork 起步的。他还维护着项目官网 [fan.asoul.us.kg](https://fan.asoul.us.kg/)，以及 [枝网查重](https://cnki.asoul.us.kg/)、[枝江文库](https://book.asoul.us.kg/)、[A-SOUL Wiki](https://wiki.asoul.us.kg/) 等站点。

感谢 [枝江站](https://asoul.love/)、[ASOUL 录音棚](https://studio.asoul.us.kg/) 等 A-SOUL 社区项目。

## 反馈

问题反馈和功能建议请提交到 [GitHub Issues](https://github.com/LEN5010/Asasfans-Next/issues)。

## 声明与许可证

Asasfans Next 是非官方粉丝项目，与 Bilibili、A-SOUL 及枝江娱乐等相关公司没有官方关联。内容版权归原作者所有。

本项目基于 GNU General Public License v2.0 发布，详见 [LICENSE](./LICENSE)。
