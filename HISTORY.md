# 历史：原生 Android 版本（至 v2.0.0）

Asasfans Next 在转向 Flutter 之前是一个原生 Android 应用。这一条线以 [v2.0.0](https://github.com/LEN5010/Asasfans-Next/releases/tag/v2.0.0) 收尾，源码与安装包保留在该标签，未被删除或改写。

本文记录它的范围和演进，供了解项目来历、查阅旧行为或对照重构目标使用。它不是当前开发计划。

## 由来

项目沿袭早期开源项目 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans)，本仓库的工作直接从 [jiarandiana0307 的 Fork](https://github.com/jiarandiana0307/as-as-fans) 起步，继续遵循 GPL-2.0。致谢与相关站点见 [README](README.md)。

## 两个阶段

早期版本（至 `1.3.6`）是「视频客户端＋社区网站入口合集」：Java 为主，`DrawerLayout` + `ViewPager2` 七个页面，视频列表分热门二创、热门切片、最新发布和本地订阅 UP，音乐/日历/动态站主要由 WebView 承载。本地数据是 `blackList.db`（schema v3），存屏蔽名单与本地订阅。

`2.0.0` 是主要使用流程的一次重构，用 Kotlin + Compose 重建主界面：

- **导航**：五栏改为今日 / 发现 / 工具 / 资料库 / 我的，宽屏用侧栏；居中粉色按钮打开工具抽屉，整合录音棚、日历、动态站、Wiki、字幕等 13 个工具。恢复原版嘉然粉 `#E799B0`，提供浅色与深色主题。
- **视频与 UP**：自动信息流、下拉刷新、追加失败保留内容、有界补页；新增 UP 主页（简介、认证、本地订阅、自动分页投稿）。订阅管理移到「我的」。
- **账号与播放**：新增应用内官方网页登录（手机不必给自己扫码），保留二维码登录；播放器支持分 P、清晰度、倍速、全屏、进度恢复和只读评论。网络验证失败不清除已有账号。
- **本地资料**：资料库统一稍后看、收藏夹、观看历史和书签，改用 Room 与 DataStore；兼容旧版 v1–v4 数据库并迁移订阅与屏蔽规则，保持 `asasfans.next` 标识和签名，可覆盖升级。

当时明确留在范围外的：订阅更新聚合、评论写操作、音乐与日历的原生化（仍走内置网页）。长视频、高画质和全部设备生命周期场景未完成完整验证。

## 技术参数

| 项目 | v2.0.0 | 1.3.6 基线 |
| --- | --- | --- |
| applicationId | `asasfans.next` | `asasfans.next` |
| 版本 | `2.0.0` / versionCode `200` | `1.3.6` / `136` |
| 语言 | Kotlin + Compose 为主 | Java 为主，少量 Kotlin |
| Java/Kotlin 文件数 | 127 | 41（约 9,427 行） |
| compileSdk / targetSdk / minSdk | `36` / `34` / `24` | `36` / `34` / `24` |
| 本地数据库 | Room + DataStore（兼容旧 v1–v4） | `blackList.db` schema v3 |
| 原生媒体 | Media3、DASH 合并、MP4 兜底、分 P、清晰度、全屏 | 同左 |
| 发布 | GitHub Actions 按 tag 或手动触发，测试/lint/签名 APK/发 Release | 同左 |

支持 Android 7.0 及以上。历史发布说明见 `release-notes/`（1.3.1、1.3.5、1.3.6、2.0.0）。

## 查阅旧代码

`old/android` 分支专门保留这条线，与 `master`、`v2.0.0` 标签同指 `a58e5c7780507bb41c9402a2b3f13a6fdc58e69f`。它是只读保留点，不接受新提交。

```sh
git switch old/android                # 切过去看完整旧工程
git show old/android:<path>           # 不切分支读某个文件
git ls-tree -r --name-only old/android # 列出全部文件
```

用 `v2.0.0` 标签同样可以读到相同内容（`git show v2.0.0:<path>`）。分支的作用是让旧代码在分支列表里直接可见，不必先知道标签名。

Flutter 重构在 `dev/flutter-rebuild` 分支进行，尚未合入 `master`。旧 Android 的构建与发布流程只保留在 `old/android`、历史标签和未改动的 `master` 中。

## 与 Flutter 版的关系

Flutter 版的产品目标承接这条线的未完成需求，但**不迁移旧数据**：个人资料从独立的新存储从零建立，不读取、修改或删除旧应用的数据库与凭据。

这意味着从旧版升级的用户，订阅、屏蔽名单和偏好不会自动带过来。旧版 2.0.0 仍可通过标签获取和安装。

当年面向 2.0 的完整路线文档和这次重构的详细计划都保存在维护者本地（`docs/` 不进版本库），其中的待办与结论属于旧计划，不驱动当前开发。
