# Asasfans

Asasfans 是一个面向 A-SOUL 粉丝的 Android 客户端，整合了视频浏览、Bilibili 登录、App 内播放、评论区浏览、订阅 UP、黑名单、音乐、工具、日历和设置等功能。

本项目保留了早期开源项目 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans) 的历史来源，后续由当前仓库继续维护和重构，并继续遵循 GPL-2.0 协议发布。

Asasfans 是非官方粉丝项目，与 Bilibili、A-SOUL 及相关公司没有官方关联。

## 功能

- 浏览 A-SOUL 相关 Bilibili 视频流。
- 支持 App 内播放或跳转 B 站播放。
- 支持 Bilibili 二维码登录和官方 WebView 登录。
- 支持视频详情、分 P、清晰度选择和只读评论区。
- 支持订阅 UP 管理和订阅 UP 视频栏。
- 支持黑名单词、黑名单 UP 和视频黑名单。
- 提供音乐、工具、日历和设置页面。
- 使用 Material 3 主框架和侧边栏导航。

## 构建

在仓库根目录使用 Gradle Wrapper：

```sh
./gradlew assembleDebug
```

常用检查：

```sh
./gradlew testDebugUnitTest
./gradlew lintDebug
```

正式包需要本地签名配置。请在仓库根目录创建 `keystore.properties`，并不要提交 keystore 或密码文件。

## 反馈

问题反馈和功能建议请提交到 [GitHub Issues](https://github.com/LEN5010/Asasfans/issues)。

## 许可证

本项目基于 GNU General Public License v2.0 发布，详见 [LICENSE](./LICENSE)。

如果你分发修改后的 APK 或其他二进制构建产物，需要同时提供对应源码，并保留原项目和本项目的版权及许可证说明。
