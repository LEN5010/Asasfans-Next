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
| 个人资料 | 收藏夹、稍后看、浏览/外跳记录、本地订阅、内容规则、分页、JSON 备份与事务合并恢复、播放进度与时间书签存储 | 无真实播放位置上报；大数据与恢复验收 |
| UP 与订阅 | 原生 UP 资料/投稿；多 UP 分页合并、失败隔离、持久已读状态 | 真实分页与风控验收；无后台轮询或离线投稿缓存 |
| Bilibili 账号 | 安全存储、扫码、官方网页登录、会话取消、退出失败重试 | 原生桥接/四端验收、自动 Cookie 刷新；平台限制见下文 |
| 视频与评论 | 原生详情、分 P、只读评论/楼中楼/图片；取流与媒体网络基础 | **播放采用外跳 B 站，不建设内置播放器**；评论富文本与账号生命周期验收 |

当前已接入中性明暗主题、材质偏好、自适应导航、共享卡片/弹层和四端原 A 图标；还需对照 LoveIwara 收敛真实页面。SDK 升级已完成，[上一轮四端开发构建](https://github.com/LEN5010/Asasfans-Next/actions/runs/35874899297)成功，界面和设备效果由用户验收，不用历史测试数量代替。

开发方式：**UI/组件阶段全部完成后，集中做必要检查与编译，再交付人类验收。** 不逐页运行、自建实验或追求测试数量；禁止防御性编程和过度测试编写，如无必要勿增实体。

网页登录源码面向 Android/iOS/macOS，Windows 当前仅扫码。Android API 28+ 使用独立浏览器目录；API 24–27 开发包可网页登录，**生产包的旧浏览器存储隔离尚未解决，当前禁用该路径**。不会以提高最低 Android 版本代替解决此问题。

## 数据与产品边界

- 手机导航：今日 / 内容 / 工具（居中抽屉）/ 日历 / 我的；宽屏使用侧栏。订阅管理位于“我的”。[LoveIwara](https://github.com/FoxSensei001/LoveIwara) 作为布局与组件接法参考；已有 MIT 适配见 `third_party/README.md`，不搬业务、品牌素材或整套架构。
- 本地订阅不修改 B 站关注；收藏不等于下载；浏览、外部打开、更新已读均不等于实际观看。评论只读。
- 个人资料使用独立 SQLite，新库 schema v9；备份导出 v6、兼容受支持的旧格式，以事务合并而非清空替换。手机导出交给系统分享，桌面使用保存对话框。
- 账号凭据使用系统安全存储，不进入普通数据库、备份、二创 API、日历或工具站请求；媒体请求独立处理鉴权，签名播放地址不持久化。
- **旧 Android 数据迁移已取消**：Flutter 个人资料从零建立，不读取、修改或删除旧数据库与凭据。新库不兼容或损坏时不以清库恢复。覆盖安装须核对实际旧 APK 与新包的签名证书、版本号并进行设备验收；即使允许覆盖，**订阅、屏蔽名单、收藏与历史也不会自动带过来**；旧数据仍留在设备上，只是不再被读取。

## 开发

固定 Flutter **3.47.3** / Dart **3.13.3**。官方下载地址、SHA-256 和完整 revision 见 `tool/flutter-sdk.json`；`.flutter-version` 与 CI 同步固定版本，依赖锁定在 `pubspec.lock`。启动脚本校验已安装的 Flutter，也可通过 `ASASFANS_FLUTTER_SDK` 显式指定目录，不自动替换错误版本。安装与校验步骤见 [工具链说明](tool/README.md)。

```sh
# 仅全部开发完成后按需执行，不是逐次编辑的检查清单：
tool/flutterw pub get --enforce-lockfile
tool/flutterw analyze --no-pub
tool/flutterw build macos --profile --no-pub
```

其他平台用手动开发构建 CI，不在本机重复构建。现有测试只在真实行为变更/已知缺陷需要时选用，全量回归需要明确选择。

Windows 使用 `tool/flutterw.ps1`。格式化使用 `tool/flutterw --dart format`，避免 PATH 中的 Dart 与项目 Flutter 不一致。Apple 最低系统为 iOS 15 / macOS 12；Android API 24 保留。新 SDK/UI 的四端运行与性能验收单独记录，旧版本的测试或 CI 成功不构成新版本验证。

Android：Java 编译目标 17、SDK 36、AGP 8.13.1 / Gradle 8.14.3 / Kotlin 2.2.20、最低 API 24、targetSdk 34。这是满足目标 Flutter 最低要求的兼容组合，不使用跳过依赖检查的参数。Flutter 可能优先使用 Android Studio 自带 JDK，先确认实际选择。Apple 工程采用目标 Flutter 的 Swift Package Manager 接线，不支持它的安全存储插件仍由 CocoaPods 管理；原生依赖锁文件一起保留。iOS/macOS 需要 Xcode、平台组件和签名；Windows 需要 Windows 与 Visual Studio C++ 桌面工具链，不能在 Mac 上交叉验收。

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

两个 workflow 都只接受手动触发，push/PR 不自动运行：

- `Flutter Checks`：固定 SDK、格式和静态分析；`run_tests` 默认关闭，只有明确要求时运行现有全量测试。
- `Flutter Development Validation`：Android Debug、iOS Debug 无签名、macOS/Windows Profile；只产生开发包，不接受许可证、不使用生产签名、不发布。

旧的手动生产签名打包任务已从 Flutter 检查配置中移除；签名配置与历史 Git 记录保留。完成全部开发阶段再集中调用，不把 CI 当每次修改的闸门。

Android 开发包为 `asasfans.next.flutterdev`；未来生产包保持 `asasfans.next` 与原签名。release 构建目前由签名验收门槛阻断，不使用 debug key 兜底。Apple bundle ID `dev.asasfans.next`、Apple 分发和 Windows 安装身份尚待确认；四端品牌图标已有原路径资产，实际桌面/启动器效果待用户验收。

解除 Android 发布门槛前必须实际完成这几项，缺一项就继续阻断：在受控环境接入原 release key（不提交进版本库）；用它构建的包能覆盖安装已有的 `asasfans.next`，且升级后旧版个人数据不被当成损坏库重置；开发包与生产包可以并存，开发包不顶替原包；产物能追溯到具体提交与测试结果。删除门禁或改用 debug key 都不算完成。

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
