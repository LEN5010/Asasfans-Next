# Asasfans Next

<p align="center">
  <img src="assets/brand/asasfans.png" alt="Asasfans Next" width="120" />
</p>

### 若有一天我会离开. 这座城是否还在.        她们会不会依然像现在. 这样日复一日笑着走来
### 若有一天你也离开. 会不会偶尔感怀.        再看看当时艰难和愉快. 再听听那些. 夸张的告白.

面向 A-SOUL 粉丝的内容、日历与社区工具客户端。当前 `dev/flutter-rebuild` 分支正在从原生 Android 迁移到 Flutter，目标平台为 iOS、Android、Windows 和 macOS。

## 当前状态

本分支正在重建核心功能，尚不是完整可替代旧版的产品。已建立四端工程、手机/桌面自适应导航、嘉然粉主题和只读 API 传输层。

已经可用：二创档案列表（筛选、搜索、随机、自动续页、图文详情与大图查看）、历史动态搜索、首页「历史上的今天」、原生直播日历（月视图与当日议程、直播/其他活动切换、离线回退）和社区工具入口。

尚未实现：切片频道（需要独立来源，不能借用二创数据集）、收藏与观看历史等个人资料、Bilibili 登录、UP 主页和视频播放。以上入口在界面中明确标为「即将开放」，不用假数据充数。

版本 `3.0.0-dev.1+201` 仅作为开发标识，不代表已确定或发布下一个正式版本。

原生 Android 线已结束，[v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0) 是它的最终版本，源码与安装包保留在该标签。重构尚未合入 `master`。本仓库的历史、Issues 和 Releases 继续保留，不新增仓库，也不复制旧工程到 `old/`。

## 开发环境

当前固定 Flutter **3.35.4** / Dart **3.9.2**，版本记录在 `.flutter-version`，应用依赖锁定在 `pubspec.lock`。暂不自动升级本机 SDK。

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
# 用户需要运行测试或应用时再执行：
flutter test --no-pub
flutter run -d macos
```

Android 使用 JDK 17、SDK 36、AGP 8.13.1 / Gradle 8.13，最低 API 24；暂保留 targetSdk 34，正式发行前单独验证平台行为升级。Flutter 可能优先选择 Android Studio 自带 JDK，可先用 `flutter doctor -v` 确认。

iOS/macOS 需要可用的 Xcode、对应平台组件以及签名配置。Windows 原生构建需要 Windows 与 Visual Studio C++ 桌面工具链，不能在 macOS 上交叉验证。

## 工程边界

| 路径 | 职责 |
| --- | --- |
| `lib/app` | 启动、依赖装配、路由、自适应导航和主题 |
| `lib/core` | 来源标识、配置、公共只读网络层、系统能力边界 |
| `lib/features` | today、content、calendar、tools、mine、library 功能切片 |
| `lib/shared` | 跨功能复用的纯展示组件 |
| `android` / `ios` / `windows` / `macos` | 系统宿主工程 |
| `test` | 离线契约、组件与布局回归测试，旧版 Room schema 历史样本 |

公开内容来源与 Bilibili 登录、站点账号和播放请求隔离；日历独立接入 ICS；切片不冒充二创。当前不引入尚无实际实现的数据库、播放器或 WebView 依赖。

本地详细计划保存在被忽略的 `docs/Flutter重构计划.md`。`docs/`、`AGENTS.md`、`CONTEXT.md`、SDK 本机配置、签名材料和构建产物不提交。

## Android 数据与发布保护

开发包使用 `asasfans.next.flutterdev`，与旧 Android 应用并存。未来生产包保持 `asasfans.next` 和原签名；接入发布签名前，Gradle 会阻止 release 构建，且不使用模板默认的 debug key 签署生产包。

旧数据迁移已确定不做：原生 Android 线以 [v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0) 为最终版本，Flutter 版的个人资料从零开始，不读取旧应用的数据库与凭据。旧版 Room schema 样本仅作为历史参考保留。

Apple bundle identifier `dev.asasfans.next` 是当前候选值，尚未注册或确认开发者归属；Apple/Windows 模板图标也待替换。

## CI

`Flutter Checks` 配置静态检查与离线测试；手动开启 `build_platforms` 才会构建四端 debug/未签名产物。当前没有 Flutter 正式发布工作流，也不会因标签自动创建 Release。此配置尚待首次远端运行验证。

原 Android 工作流只保留在旧版 Git 历史与未改动的 `master` 中，重构分支不继续执行旧工程的构建或签名发布。

## 来源与致谢

本项目保留了早期开源项目 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans) 的历史来源，后续由当前仓库继续维护和重构，并继续遵循 GPL-2.0 协议发布。

感谢 [jiarandiana0307](https://github.com/jiarandiana0307) 去年对其 [Fork 版本](https://github.com/jiarandiana0307/as-as-fans) 的维护和更新。

感谢 [枝江站](https://asoul.love/)、[ASOUL录音棚](https://studio.asoul.us.kg/) 等 A-SOUL 社区项目。

## 官网与相关站点推荐

- 项目官网：[fan.asoul.us.kg](https://fan.asoul.us.kg/)
- 该官网由 [jiarandiana0307](https://github.com/jiarandiana0307) 维护
- 同时本仓库的重构工作直接从 [jiarandiana0307/as-as-fans](https://github.com/jiarandiana0307/as-as-fans) 的 Fork 起步
- 也推荐关注他维护的其他站点：[枝网查重](https://cnki.asoul.us.kg/)、[枝江文库](https://book.asoul.us.kg/)、[A-SOUL Wiki](https://wiki.asoul.us.kg/)。

Asasfans Next 是非官方粉丝项目，与 Bilibili、A-SOUL 及枝江娱乐等相关公司没有官方关联。

## 反馈与许可证

问题反馈见 [GitHub Issues](https://github.com/LEN5010/Asasfans-Next/issues)。继续使用 [GPL-2.0](LICENSE)，保留原项目历史与素材归属。分发二进制时同时提供对应源码及版权、许可证说明。
