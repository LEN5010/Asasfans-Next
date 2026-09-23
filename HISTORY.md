# 历史

## 起点：2022 年的 as-as-fans

2022 年 2 月 27 日，akarinini 在 [A-SoulFan/as-as-fans](https://github.com/A-SoulFan/as-as-fans) 提交了第一行代码。Yenaly、JayYoung、oldking139 也陆续参与进来，一起做出了最早的 A-SOUL 粉丝客户端

那时的应用以 Java 为主，界面是侧滑抽屉加七个页面左右切换，音乐、日历和动态站大多直接用内置网页打开。本地只有一个小数据库 `blackList.db`，用来记屏蔽名单和本地订阅。

## 谁接手维护：2025 年的 Fork

510事件之后，ASF项目组解散，原项目很长一段时间没有更新。2025 年，[jiarandiana0307](https://github.com/jiarandiana0307) 在 [自己的 Fork](https://github.com/jiarandiana0307/as-as-fans) 里继续维护和更新，让这个应用还能接着用。
他还维护着项目官网 [fan.asoul.us.kg](https://fan.asoul.us.kg/)，以及枝网查重、枝江文库、A-SOUL Wiki 等站点。

本仓库就是从他的 Fork 起步的。

## 1.3.x：2026 年春夏的修修补补

2026 年 5 月，LEN5010 接手，以 Asasfans Next 的名字发布了 1.3.0 到 1.3.5，8 月又发了 1.3.6。
这一阶段沿用原来的架构，主要修好了一些UI Bug/升级SDK和依赖并迁移到新版本。

## 2.0.0：原生 Android 的最后一版

2026 年 9 月 20 日发布的 2.0.0 是一次大重构，用 Kotlin 和 Compose 把主要流程重写了一遍：

- **导航**：换成今日 / 发现 / 工具 / 资料库 / 我的 五个栏目，宽屏用侧栏。中间的粉色按钮打开工具抽屉，里面放了录音棚、日历、动态站、Wiki、字幕等 13 个工具。原版的嘉然粉 `#E799B0` 回来了，还加上了浅色和深色主题。
- **视频与 UP**：信息流会自动加载下一页，下拉刷新。新增了 UP 主页，能看简介、认证和分页投稿，订阅管理挪到了「我的」。
- **账号与播放**：可以在应用里直接用 B 站官方网页登录，手机不用再给自己扫码，二维码登录也保留着。播放器支持分 P、清晰度、倍速、全屏、进度恢复和只读评论。
- **本地资料**：稍后看、收藏夹、观看历史和书签统一放进资料库，存储换成了 Room 和 DataStore。旧版 v1–v4 数据库里的订阅和屏蔽规则会自动迁移覆盖升级。


| 项目 | v2.0.0 | 1.3.6 |
| --- | --- | --- |
| applicationId | `asasfans.next` | `asasfans.next` |
| 版本 | `2.0.0` / versionCode `200` | `1.3.6` / `136` |
| 语言 | Kotlin + Compose 为主 | Java 为主，少量 Kotlin |
| Java/Kotlin 文件数 | 127 | 41（约 9,427 行） |
| compileSdk / targetSdk / minSdk | `36` / `34` / `24` | `36` / `34` / `24` |
| 本地数据库 | Room + DataStore（兼容旧 v1–v4） | `blackList.db` schema v3 |
| 原生媒体 | Media3、DASH 合并、MP4 兜底、分 P、清晰度、全屏 | 同左 |
| 发布 | GitHub Actions 按 tag 或手动触发，测试、lint、签名 APK、发 Release | 同左 |

支持 Android 7.0 及以上。各版本的发布说明在 `release-notes/` 目录下（1.3.1、1.3.5、1.3.6、2.0.0）。

## 3.0：换成 Flutter

2.0.0 发布的第二天，也就是 2026 年 9 月 21 日，Flutter 重建开始了。
目的是用一套代码同时覆盖 iOS、Android、Windows 和 macOS，再次整合信息流。

## 查阅旧代码

原生 Android 版完整保留在 `old` 分支和 `v2.0.0` 标签里，两者都指向 `a58e5c7780507bb41c9402a2b3f13a6fdc58e69f`。

`old` 分支只用来保存，不再接受新提交。

```sh
git switch old                 # 切过去看完整的旧工程
git show old:<path>            # 不切分支，直接读某个文件
git ls-tree -r --name-only old # 列出全部文件
```

用标签也能读到期内容，例如 `git show v2.0.0:<path>`。
旧版的构建和发布流程均在 `old` 分支和历史标签里。
