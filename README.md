# Asasfans Next

<p align="center">
  <img src="assets/brand/asasfans.png" alt="Asasfans Next" width="120" />
</p>

### 若有一天我会离开. 这座城是否还在.        她们会不会依然像现在. 这样日复一日笑着走来
### 若有一天你也离开. 会不会偶尔感怀.        再看看当时艰难和愉快. 再听听那些. 夸张的告白.

面向 A-SOUL 粉丝的内容、日历与社区工具客户端。当前在 `dev/flutter-rebuild` 分支以 Flutter 重建，目标平台为 **iOS / Android / Windows / macOS**，保留嘉然粉配色。

**这是开发中的内容浏览版本，尚不能完整替代旧版。** `3.0.0-dev.1+201` 仅为开发标识，不是正式发行版本。原生 Android 线以 [v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0) 为最终版本；源码和安装包保留在该标签，重构尚未合入 `master`。

## 功能进度

下表描述**源码实现范围**，不代表四端运行验收通过。

| 模块 | 已有源码 | 主要缺口 |
| --- | --- | --- |
| 内容与首页 | 二创档案、历史动态、最新视频/切片/录播；搜索、筛选、随机、自动续页、图文与大图查看 | 部分筛选、真实来源与布局验收 |
| 日历与工具 | 原生日/周/月视图、成员筛选、事件详情、持久缓存、日程关注；分组工具外跳 | 重复规则展开、系统提醒和系统日历集成 |
| 个人资料 | 收藏夹、稍后看、浏览/外跳记录、本地订阅、内容规则、分页、JSON 备份与事务合并恢复、播放进度与时间书签存储 | 进度/书签的界面接入、大数据与恢复验收 |
| UP 与订阅 | 原生 UP 资料/投稿；多 UP 分页合并、失败隔离、持久已读状态 | 真实分页与风控验收；无后台轮询或离线投稿缓存 |
| Bilibili 账号 | 安全存储、扫码、官方网页登录、会话取消、退出失败重试 | 原生桥接/四端验收、自动 Cookie 刷新；平台限制见下文 |
| 视频与评论 | 原生详情、分 P、只读评论/楼中楼/图片；取流与媒体网络基础 | **播放仍外跳 B 站，尚无内置播放器**；评论富文本、播放与生命周期验收 |

当前新增实现经过依赖解析和 Dart 静态分析；新增测试源码未执行，原生插件、真实来源和四端设备行为未完成验收。历史测试结果不能覆盖本次新增代码。

网页登录源码面向 Android/iOS/macOS，Windows 当前仅扫码。Android API 28+ 使用独立浏览器目录；API 24–27 开发包可网页登录，**生产包的旧浏览器存储隔离尚未解决，当前禁用该路径**。不会以提高最低 Android 版本代替解决此问题。

## 数据与产品边界

- 手机导航：今日 / 内容 / 工具（居中抽屉）/ 日历 / 我的；宽屏使用侧栏。订阅管理位于“我的”。[LoveIwara](https://github.com/FoxSensei001/LoveIwara) 仅为布局参考，不复制其代码、素材或配色。
- 本地订阅不修改 B 站关注；收藏不等于下载；浏览、外部打开、更新已读均不等于实际观看。评论只读。
- 个人资料使用独立 SQLite，新库 schema v6；备份导出 v4、兼容 v1–v3，以事务合并而非清空替换。手机导出交给系统分享，桌面使用保存对话框。
- 账号凭据使用系统安全存储，不进入普通数据库、备份、二创 API、日历或工具站请求；媒体请求独立处理鉴权，签名播放地址不持久化。
- **旧 Android 数据迁移已取消**：Flutter 个人资料从零建立，不读取、修改或删除旧数据库与凭据。新库不兼容或损坏时不以清库恢复。

## 开发

固定 Flutter **3.35.4** / Dart **3.9.2**（见 `.flutter-version`），依赖锁定在 `pubspec.lock`。

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
# 以下由开发者按需执行，不代表当前已运行通过：
flutter test --no-pub
flutter run -d macos
```

Android：JDK 17、SDK 36、AGP 8.13.1 / Gradle 8.13、最低 API 24、targetSdk 34。Flutter 可能优先使用 Android Studio 自带 JDK，先确认实际工具链选择。iOS/macOS 需要 Xcode、平台组件和签名；Windows 需要 Windows 与 Visual Studio C++ 桌面工具链，不能在 Mac 上交叉验收。

| 路径 | 职责 |
| --- | --- |
| `lib/app` | 启动、依赖装配、路由、主题和自适应导航 |
| `lib/core` | 跨功能模型、分离的网络边界、新存储与平台能力 |
| `lib/features` | 按功能划分 domain / data / application / presentation |
| `lib/shared` | 共享展示组件 |
| `android` / `ios` / `windows` / `macos` | 原生宿主与插件桥接 |
| `test` | 离线契约、存储、组件和布局测试源码 |

本地详细文档入口为 `docs/README.md`。`docs/`、`AGENTS.md`、`CONTEXT.md`、SDK 本机配置、凭据、签名材料和构建产物保持 Git 忽略；公开说明以本 README 为准。

## CI 与发布

`Flutter Checks` 配置格式检查、静态分析和离线测试；手动开启 `build_platforms` 才构建四端 debug/未签名产物，当前仍待远端验证。没有 Flutter 正式发布工作流，也不因标签自动创建 Release。

Android 开发包为 `asasfans.next.flutterdev`；未来生产包保持 `asasfans.next` 与原签名。release 构建目前由签名验收门槛阻断，不使用 debug key 兜底。Apple bundle ID `dev.asasfans.next`、Apple 分发和 Windows 安装身份尚待确认；Apple/Windows 品牌图标也待完善。

旧 Android 构建与发布流程仅在历史标签及 `master` 中保留。

## 项目历史

原生 Android 线已结束，[v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0) 是它的最终版本，源码与安装包保留在该标签，另有 `old/android` 分支指向同一提交作为只读保留点。本仓库的历史、Issues 和 Releases 继续保留，不新增仓库，也不复制旧工程到目录。

那一版的功能范围、技术栈、参数对照和查阅方式见 [HISTORY.md](HISTORY.md)。

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
