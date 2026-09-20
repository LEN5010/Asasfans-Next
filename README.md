# Asasfans Next

<p align="center">
  <img src="assets/brand/asasfans.png" alt="Asasfans Next" width="120" />
</p>

### 若有一天我会离开. 这座城是否还在.        她们会不会依然像现在. 这样日复一日笑着走来
### 若有一天你也离开. 会不会偶尔感怀.        再看看当时艰难和愉快. 再听听那些. 夸张的告白.

面向 A-SOUL 粉丝的内容、日历与社区工具客户端。当前 `dev/flutter-rebuild` 分支正在从原生 Android 迁移到 Flutter，目标平台为 iOS、Android、Windows 和 macOS。

## 当前状态

本分支正在重建核心功能，尚不是完整可替代旧版的产品。已建立四端工程、手机/桌面自适应导航、嘉然粉主题和只读 API 传输层。

已有源码实现：二创档案列表（筛选、搜索、随机、自动续页、图文详情与大图查看）、历史动态搜索、独立社区来源的最新视频/切片/录播、今日内容摘要、原生日历（日/周/月、成员筛选、事件详情和持久缓存）与分组社区工具。主题和首页模块偏好已接入新 SQLite 存储。

个人资产已有源码：多收藏夹、稍后看、详情浏览/外部打开记录、本地订阅管理、日程关注及改期同步；列表使用带修订校验的自动分页。收藏快照保留正文和公开图片引用，不下载视频；本地订阅不写入 Bilibili 关注，日程关注不等于系统提醒。

备份与恢复已有源码：版本化 JSON（v3，兼容 v1/v2）、导入预览和事务合并，不清空已有资料；桌面保存文件，手机使用系统分享。不包含凭据、临时播放地址或日历缓存。

内容规则已有源码：按来源区分的内容/作者屏蔽、文本屏蔽词、精确 Tag、启停与期限、撤销，以及可选订阅优先。规则接入发现流、首页和随机结果；未知 Tag 不冒充已知空值，规则不会删除个人收藏或历史。

原生 UP 主页已有源码：头像/简介/已知统计、本地订阅、搜索/排序/自动续页与显式 B 站外跳；手机整页滚动，桌面资料侧栏与投稿网格。B 站元数据走独立只读通道，无账号时匿名；风控不显示成空投稿。视频作者、二创详情、历史动态和订阅管理已连接原生主页，豆瓣作者仍按来源外跳。

订阅更新已有源码：逐 UP 投稿分页、按发布时间有界合并与去重、失败隔离、共享排队/限流、规则过滤和全部/未读视图；已读状态持久化并纳入备份，与观看历史独立。订阅管理仍在“我的”，内容频道和管理页均可打开更新流。投稿结果目前仅会话内保留，没有后台轮询或离线投稿缓存。

账号已有源码：安全存储、QR 登录、Android/iOS/macOS 官方网页登录、登录验证、代际取消与退出失败重试；Windows 当前使用 QR，不展示 WebView 按钮。Cookie 只提供给固定 HTTPS B 站 API，不进入二创站、日历、工具或备份。Android API 28+ 使用独立登录浏览器目录；生产包在 API 24–27 的浏览器隔离方案尚未完成，当前禁用该路径以避免触碰旧版数据，开发包仍可网页登录。

网页登录和安全存储提交前记录待清理标志，覆盖登录中断/部分写入的重启窗口；浏览器初始化、重载和关闭串行，关闭失败保留重试入口。原生 Cookie/浏览器桥接尚未构建或设备验收，自动 Cookie 刷新尚未实现。

原生视频详情与只读评论已有源码：封面/简介/作者、本地订阅、收藏/稍后看、按 CID 选择分 P、最赞/最新评论、置顶去重、自动续页和楼中楼/图片查看。手机整页滚动，宽屏详情/评论双栏；视频播放仍明确外跳 B 站。评论没有发送、点赞或删除操作，表情与提及目前保留文本形式。

播放底层已有部分源码：WBI 取流、DASH/MP4 元信息、实际可选画质、逐跳鉴权/取消/Range 媒体通道及仅本地引用的 MPD 生成器。尚未接入播放器或本地媒体服务，没有实际播放证据；这些不算内置播放功能完成。

尚未完成：账号/网页 Cookie 桥接的四端原生验收、旧 Android 版本生产网页登录隔离、大规模数据性能/内存验证、播放进度与书签和内置视频播放。UP、订阅更新、详情和评论也待真实来源与设备验收；真正观看历史须等播放器接入，不把浏览详情、外部打开或更新已读算作观看完成。

当前改动仅经过依赖解析和静态分析；新增离线测试源码尚未执行，原生插件构建、真实来源联调和四端设备验收仍待完成。日历暂不展开 RRULE/RDATE/EXDATE。

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
| `lib/core` | 来源标识、配置、公共只读网络层、新存储与系统能力边界 |
| `lib/features` | today、content、account、creator、subscriptions、calendar、tools、mine、library、preferences、backup、rules 等功能切片 |
| `lib/shared` | 跨功能复用的纯展示组件 |
| `android` / `ios` / `windows` / `macos` | 系统宿主工程 |
| `test` | 离线契约、组件与布局回归测试，旧版 Room schema 历史样本 |

公开内容来源与 Bilibili 登录、站点账号和播放请求隔离；日历独立接入 ICS；切片不冒充二创。新存储位于应用支持目录的 `asasfans_flutter/personal.sqlite3`，当前 schema v5 保存偏好、日历缓存与上述个人资产，另有本地游标修订元信息、内容规则、规则设置和更新已读状态；不存凭据或播放直链。账号凭据使用独立系统安全存储，SQLite 只存不含身份信息的退出清理标志。未知或更高版本的数据库会报错，不通过清库恢复。播放器依赖仍未引入；登录 WebView 是独占浏览器存储，不供工具站复用。

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
