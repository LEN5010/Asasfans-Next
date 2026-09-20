# Asasfans Next

<p align="center">
  <img src="app/src/main/res/mipmap-xxxhdpi/icon_asasfans_next_logo.png" alt="Asasfans Next" width="120" />
</p>

### 若有一天我会离开. 这座城是否还在.        她们会不会依然像现在. 这样日复一日笑着走来
### 若有一天你也离开. 会不会偶尔感怀.        再看看当时艰难和愉快. 再听听那些. 夸张的告白.

Asasfans Next 是一个面向 A-SOUL 粉丝的 Android 客户端，整合了视频浏览、Bilibili 登录、App 内播放、评论区浏览、订阅 UP、黑名单、音乐、工具、日历和设置等功能。

本项目保留了早期开源项目 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans) 的历史来源，后续由当前仓库继续维护和重构，并继续遵循 GPL-2.0 协议发布。

感谢 [jiarandiana0307](https://github.com/jiarandiana0307) 去年对其 [Fork 版本](https://github.com/jiarandiana0307/as-as-fans) 的维护和更新。

感谢 [枝江站](https://asoul.love/)、[ASOUL录音棚](https://studio.asoul.us.kg/) 等 A-SOUL 社区项目。

## 官网与相关站点推荐

- 项目官网：[fan.asoul.us.kg](https://fan.asoul.us.kg/)
- 该官网由 [jiarandiana0307](https://github.com/jiarandiana0307) 维护
- 同时本仓库的重构工作直接从 [jiarandiana0307/as-as-fans](https://github.com/jiarandiana0307/as-as-fans) 的 Fork 起步
- 也推荐关注他维护的其他站点：[枝网查重](https://cnki.asoul.us.kg/)、[枝江文库](https://book.asoul.us.kg/)、[A-SOUL Wiki](https://wiki.asoul.us.kg/)。

Asasfans Next 是非官方粉丝项目，与 Bilibili、A-SOUL 及枝江娱乐等相关公司没有官方关联。

## 2.0.0

2.0 使用 Kotlin、Compose、Room 和 DataStore 重建主要使用流程，保留原版嘉然粉配色与本地资料。完整更新见 [2.0.0 更新说明](release-notes/2.0.0.md)。

## 功能

- 今日与发现视频流支持滚动自动续载、下拉刷新和失败重试。
- 支持 App 内播放或跳转 B 站；提供分 P、清晰度、倍速、进度恢复和只读评论。
- 支持 Bilibili 官方网页登录与二维码登录，账号凭据使用加密本地存储。
- 点击 UP 头像或昵称进入原生主页，查看简介、订阅及分页投稿，或跳转 B 站空间。
- 本地订阅管理位于「我的」，与 B 站账号关注独立。
- 资料库提供稍后看、收藏夹、观看历史、播放进度和书签。
- 支持关键词、Tag、UP 和视频屏蔽规则。
- 底栏中间的工具抽屉整合录音棚、日历、社区导航等站点，各工具使用独立图标。
- 手机底栏与宽屏侧栏布局、浅色与深色主题。
- 支持旧版 v1–v4 本地数据库迁移，保留旧数据库与追更恢复记录。

## 构建

使用 JDK 17 和 Android SDK 36，在仓库根目录使用 Gradle Wrapper：

```sh
./gradlew assembleDebug
```

常用检查：

```sh
./gradlew testDebugUnitTest
./gradlew lintDebug
```

正式包需要本地签名配置。请在仓库根目录创建 `keystore.properties`，并不要提交 keystore 或密码文件。

### GitHub Actions 发布

仓库提供 `Android Release` workflow。推送 `v*` tag，或在 Actions 页面手动输入已存在的 tag 后，流水线会检出该标签，核对应用版本与更新说明，运行测试、lint、编译设备测试 APK，再构建并校验签名 APK，上传 APK 和 SHA-256 校验文件到对应 GitHub Release。

例如 `v2.0.0` 必须对应 `versionName "2.0.0"`，更新说明位于 `release-notes/2.0.0.md`。分支与 PR 的 `Android Checks` 不需要发布签名凭据。

需要在 GitHub 仓库的 `Settings -> Secrets and variables -> Actions` 配置以下 Secrets：

- `ANDROID_KEYSTORE_BASE64`：`asasfans-release.jks` 的 Base64 内容
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

本地生成 Base64 示例：

```sh
base64 -i asasfans-release.jks | pbcopy
```

## 反馈

问题反馈和功能建议请提交到 [GitHub Issues](https://github.com/LEN5010/Asasfans-Next/issues)。

## 许可证

本项目基于 GNU General Public License v2.0 发布，详见 [LICENSE](./LICENSE)。

如果你分发修改后的 APK 或其他二进制构建产物，需要同时提供对应源码，并保留原项目和本项目的版权及许可证说明。
