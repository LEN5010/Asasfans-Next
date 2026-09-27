# 布局检查点：二创与今日（附 L05–L09 局部修整）

- 目标文件：`CLAUDE_GOAL.md` 与 `PLAN.md`（2026-09-26 审阅稿）。
- 基线：`main@5149575`。前后对照用的 `2a91d3a` 与它在 `lib/`、`test/`、`macos/`、`android/`、`ios/` 上完全相同，只多了 `tool/perf`。
- 当前源码：`main@9bed307`（本地提交，未推送，未运行 CI）。
- 验收包：`docs/flutter/验收包/Asasfans Next.app`，构建自 `54eb868`；之后的 `9bed307` 只改了测试。
- 用户验收：尚未进行。本报告不代写任何接受结论，`accepted_by_user` 未填写。

## 1. 运行环境

| 项 | 值 |
|---|---|
| 宿主 | Apple M3，24 GB，macOS 26.6.2 (25G83)，8 核，内建 Liquid Retina 屏，60 Hz |
| SDK | Flutter 3.47.3 / Dart 3.13.3（`tool/flutterw`，`/Users/len5010/flutter`），lockfile 未改 |
| Profile 渲染 | Impeller，Metal（日志：`Using the Impeller rendering backend (MetalSDF)`） |
| Profile 窗口 | 逻辑 800×600，DPR 2.0，刷新率 60 |
| 玻璃档位 | `auto` 实际为 premium；`smooth` 实际为 solid。macOS 上选不到 standard |
| Profile 数据集 | `tool/perf/perf_fixture.dart`（`perf-fixture-1`）：16 页 × 24 条混合二创，含 1000×30000 长条漫，图片在内存里生成，离线 |
| 无头截图 | `flutter_tester` 软件光栅，Solid 材质；字体为本机 PingFang（`ASASFANS_CJK_FONT` 指向 MobileAsset 目录），拉丁字母也用它 |
| 截图数据集 | `test/visual/two_pages_test.dart` 的 8 件混合作品（2 条短标题视频、竖图、横图、文字、长图、多图、长标题），`visual_fixture.dart` 的其余页面数据，`fanart_journeys_test.dart` 的 40 件作品 |

截图像素不等于逻辑尺寸。每张图的逻辑尺寸、DPR、字号倍率、明暗、材质和渲染器写在同目录 `manifest.json`。窄 macOS 窗口和无头 390 宽视图都不是 Android 真机。

## 2. 实现范围（逐项）

| 项 | 提交 | 主要文件 | 证据 |
|---|---|---|---|
| 封面加载淡入修复 | `98e2ec0` | `media_cover.dart` | 跨断点缩放时原实现抛出 `Cannot clone a disposed image`；改为单子组件淡入一次，同图缩放保留旧解码，换图按地址重新淡入。缩放旅程测试通过 |
| L02/L03 二创自然高度 | `0a1471b` | `fanart_card.dart`、`sliver_content_masonry.dart`、`content_page.dart`、`feed_scroll_view.dart`、`community_feed_view.dart`、`anchor_restore.dart` | 删除 `extentFor`/`videoWordsExtent`；视频标题到作者行的空白由 138.9 px（390 宽）/169 px（1280 宽）变为 0，见 `shots/*/manifest.json` 的 `title_to_byline`。宽度变化保持顶部作品，来回缩放回到原偏移。旅程：第 30 项详情→原动态→返回、冷返回（有/无目标）、跨断点、作者/更多/本体分别点击、最后一项在导航上方 |
| L04 今日顶部摘要 | `299540b` | `today_page.dart`、`app_tokens.dart` | 一个 `CustomScrollView`；日程与继续挑选在阅读宽度内，最新二创占满内容宽度，两行瀑布流最多 5 列；没有按首项定高的行，没有全量测高。测试覆盖 0/1/多项日程、模块全关、事件纵排 |
| L07 日历与我的 | `256b902` | `calendar_event_widgets.dart`、`calendar_page.dart`、`mine_page.dart` | 议程行状态紧跟标题，议程宽 640；我的页从边距开始，管理/应用在宽窗口并排 |
| L08 图片分层预算 | `de374bc` | `media_image_policy.dart`、`fanart_detail_page.dart` | 列表缩略图上限 2 MPx、最长边 8192；详情与完整查看保持 16 MPx。长条漫列表解码 512×15360 → 264×7931，见第 4 节 |
| L05 指针、焦点、原生窗口 | `71f2b35` | `media_card_surface.dart`、`creator_link.dart`、`window_appearance.dart`、`asasfans_app.dart`、`MainFlutterWindow.swift` | 悬停只描淡色边框，键盘焦点 2 px 主色环；无点击的区域（动态正文）不再整块悬停或按压缩放；作者名悬停下划线。macOS 窗口外观跟随应用浅/深，跟随系统时清除覆盖 |
| L06 视频与小说 | `b53b3cb` | `video_card.dart`、`novel_feed_view.dart` | 视频卡够宽时日期/播放数与作者同行；小说按压不缩放，角色一行，阅读全文改为辅助提示，R18 保留查看原帖按钮 |
| 测量工具 | `999f073` | `tool/perf/main.dart`、`run_macos.sh`、`compare.py`、`tool/README.md` | 真实渲染器截图模式；多次运行并排表 |
| L09 遮挡核对 | `78bc16a` | `app_shell.dart`、`asasfans_app.dart` | 发现并修复：键盘 Tab 聚焦的作品、作者名和更多按钮落在底部导航下（焦点底边 806 > 导航顶 746）；提示条压住导航（844 > 746）。导航改为外壳 Scaffold 的 `bottomNavigationBar`（`extendBody` 常开，正文底部内边距与原来相同），焦点定位扣除状态栏和导航遮挡。两条新测试在修改前失败、修改后通过 |
| 测试截图 | `54eb868`、`9bed307` | `fanart_journeys_test.dart`、`two_pages_test.dart` | 最后一项截图改在打开面板之前；补拍动态正文与小说的悬停 |

## 3. 实际命令与退出码

均在仓库根目录，`ASASFANS_FLUTTER_SDK=/Users/len5010/flutter`。

| 命令 | 退出码 | 结果 |
|---|---|---|
| `tool/flutterw test --no-pub test/visual test/content test/today test/handoff test/mine test/calendar test/novels test/shared` | 1 | 601 通过，2 失败（见下） |
| `tool/flutterw test --no-pub test/shared/media_image_policy_test.dart test/content` | 0 | 176 通过 |
| `dart format --output=none --set-exit-if-changed lib test tool` | 0 | 无改动 |
| `tool/flutterw analyze --no-pub` | 0 | No issues found |
| `tool/flutterw test --no-pub`（全量，含 L09 修复） | 1 | 934 通过，2 失败 |
| `tool/visual_capture.sh reports/layout-perf/shots/before test/visual/two_pages_test.dart test/visual/current_pages_test.dart`（临时工作树，`2a91d3a` 加复制进去的 `two_pages_test.dart`） | 0 | 73 条通过，81 张 |
| `tool/visual_capture.sh reports/layout-perf/shots/after test/visual/two_pages_test.dart test/visual/current_pages_test.dart test/visual/fanart_journeys_test.dart` | 0 | 81 条通过，87 张 |
| `tool/perf/run_macos.sh f1-solid-rep1 …`（最终代码 Profile） | 失败 | 屏幕锁定，窗口拿不到前台，入口等待 `resumed` 超时；数据已删除，未计入 |
| `tool/flutterw build macos --profile --no-pub` | 0 | `Asasfans Next.app` 81.2 MB |
| `codesign --verify --deep --strict docs/flutter/验收包/Asasfans Next.app` | 0 | 开发签名，Team 5WR2PV685M |

两条失败都是 `test/visual/directions_test.dart` 的 `dir-a_today 390` 与 `390-dark`：测试专用示意布局 `test/visual/directions/direction_a.dart:208` 的 Column 在 390 宽溢出 6 px。它不在 `lib/`，基线 `2a91d3a` 上同样失败，本轮未处理。

验收包二进制 SHA-256：

```
1992b88b27870c4a84d4e580fb353cc671dd529c2d12f4619b8756feb15a3289  MacOS/Asasfans Next
621938511848f32450e3ae425c3d0956235a46753020f09f06393d7b39d88671  Frameworks/App.framework/Versions/A/App
```

## 4. Profile 单因素对照

方法：`tool/perf/run_macos.sh <label> reports/layout-perf/profile <smooth|auto> 60`。补丁 A/B/C 依次提交在临时工作树的 `perf/factors` 分支上（未推送），每一步只多一个因素。每种配置跑两次，两次都列出，不取平均。场景：进入二创 → 滚轮滚动 60 秒 → 点开长条漫详情和完整长图 → 返回 → 四频道与四主栏往返；同一进程先冷缓存一遍，再暖缓存一遍。窗口不在前台的阶段标为 invalid（本组没有）。每次运行都产出了 JSON 与 footprint 采样；当时逐次的 shell 退出码没有单独记下。

| 配置 | 提交 | 冷滚动 UI P95 (ms) | 冷滚动 raster P95 (ms) | footprint 采样最大 / 峰值 (MB) | 长条漫列表解码 | 点击到详情图 (ms) |
|---|---|---|---|---|---|---|
| 基线，premium | `2a91d3a` | 3.5 / 2.9 | 2.0 / 1.8 | 884 / 1145，828 / 1271 | 512×15360 | 555 / 554 |
| 只改 solid | `2a91d3a` | 4.6 / 3.9 | 1.5 / 1.3 | 628 / 934，591 / 1130 | 512×15360 | 544 / 552 |
| + 主栏目直接切换（补丁 A） | `60470d9` | 3.6 / 5.2 | 1.1 / 1.8 | 533 / 925，573 / 1034 | 512×15360 | 543 / 531 |
| + 封面不做首次淡入（补丁 B） | `64f2408` | 3.9 / 5.3 | 1.2 / 1.8 | 608 / 1037，619 / 1123 | 512×15360 | 549 / 549 |
| + 缩略图预算（补丁 C） | `1577302` | 3.3 / 5.3 | 1.1 / 1.9 | 602 / 904，562 / 780 | 264×7931 | 548 / 554 |

全部阶段的 P50/P95/P99、超预算比例和图片缓存见 `profile/COMPARISON.md`，原始数据在 `profile/*.json`、`*.log`、`*.footprint.txt`。UI 与 raster 是两个线程，不能相加；预算按 60 Hz 的 16.7 ms。

结论（只限这台 Mac 和这份数据）：

1. **玻璃**：premium 比 solid 的 footprint 采样最大值高约 200–290 MB，冷滚动 raster P95 高约 0.5 ms；两者滚动阶段都没有超过 16.7 ms 的帧。玻璃档位默认值本轮不改。
2. **主栏目淡入缩放**：关掉后两次运行的差异小于同配置两次之间的差异，看不出收益。保留现有动效，补丁 A 存在 `patches/`，留给 Android 老机复测。
3. **封面首次淡入**：同样看不出收益。main 上保留淡入，但因为缩放崩溃改成了单子组件实现（`98e2ec0`），补丁 B 已不能直接套用。
4. **缩略图预算**：长条漫列表解码像素降约 73%，两次峰值 1037/1123 → 904/780 MB。已并入 main（`de374bc`）。图片缓存末值 77 → 约 100 MB，是因为缓存上限 100 MB 下能放下更多小图，不是泄漏。
5. **没解释的慢帧**：所有配置在四频道/四主栏往返阶段都有 0.7%–7.1% 的 UI 帧超预算，UI P99 12.9–53.1 ms。以上因素都不能解释它，原始最慢帧保留在表里，留作下一步定位对象。

最终代码（`9bed307`）的 Profile 还没有数据：两次尝试时屏幕都处于锁定状态。解锁屏幕后可以直接运行：

```sh
ASASFANS_FLUTTER_SDK=/Users/len5010/flutter tool/perf/run_macos.sh f1-solid-rep1 reports/layout-perf/profile smooth 60
ASASFANS_FLUTTER_SDK=/Users/len5010/flutter tool/perf/run_macos.sh f2-premium-rep1 reports/layout-perf/profile auto 60
ASASFANS_FLUTTER_SDK=/Users/len5010/flutter tool/perf/run_macos.sh r-shots reports/layout-perf/renderer auto 60 shots
python3 tool/perf/compare.py reports/layout-perf/profile > reports/layout-perf/profile/COMPARISON.md
```

运行期间窗口会出现在屏幕上，不要操作鼠标。

## 5. 截图索引

- `shots/before/`：基线 `2a91d3a`，81 张。
- `shots/after/`：当前 `9bed307`，87 张（多出 6 张旅程图）。
- 文件名 `<场景>_<视图>.png`。视图：`390`（390×844，DPR 2）、`390-dark`、`390-bars`（带 47 状态栏和 34 底部安全区）、`390-x1.6`（字号 1.6 倍）、`320-x2.0`、`600`（600×960，DPR 1）、`840`（840×1000，DPR 1）、`1280`（1280×800，DPR 1）、`1280-dark`。

建议先看这些成对的图：

| 看什么 | 文件 |
|---|---|
| 今日宽屏：左侧全高日程列 → 顶部摘要 + 满宽作品 | `review-today_1280.png`、`review-today_1280-dark.png` |
| 今日 0/1/4 项日程、模块全关 | `review-today-events{0,1,4}_{390,1280}.png`、`review-today-off_{390,1280}.png` |
| 二创手机/宽屏：视频不再补高 | `review-fanart_390.png`、`review-fanart_1280.png`、`review-fanart_840.png` |
| 大字 | `review-fanart_320-x2.0.png`、`review-today_390-x1.6.png` |
| 静止 / 悬停作品 / 悬停作者 / 键盘焦点 | `review-state-{idle,hover-tile,hover-maker,focus}_1280{,-dark}.png` |
| 动态正文、小说悬停 | `review-state-{dynamic,novel}-hover_1280.png` |
| 视频、动态、小说、日历、我的（L06/L07） | `{videos,dynamics,novels,calendar,mine}_{390,390-dark,600,840,1280}.png` |
| 旅程（仅当前） | `journey-30th-back_390-bars.png`、`journey-30th-cold_390-bars.png`、`journey-30th-resize_{1280,840,390-bars}.png`、`journey-last-above-dock_390-bars.png` |

这些都是 Solid 材质的无头渲染，证明布局，不证明玻璃光学、GPU 成本或真机帧时。

## 6. 未完成与未验证

1. **最终代码的 Profile**（Solid/premium）和**真实渲染器截图**（含玻璃、浅深两色）：屏幕锁定，没跑成。命令见第 4 节。
2. **standard 玻璃档**：macOS 上只能得到 premium 或 solid，没有测。
3. **窗口缩放的帧时**：计划场景里的缩放窗口一步没有进 Profile 脚本；缩放后回到原项只在无头测试里验证。
4. **Android 真机**：安装需要单独授权，没有做。窄 macOS 窗口的结论不能外推到 Android。
5. **长条漫详情预览**：详情解码 273×8192，偏糊；源站是否支持服务端裁剪需要探测线上接口，未获授权，没有验证。
6. **Windows 标题栏主题同步**：只做了 macOS。
7. **PLAN 第 4 节的侧栏宽度分档**、**L09 玻璃光学调校**：没有做。前者超出第一检查点的外壳范围，后者需要真实渲染器图作依据。
8. **四端构建与 CI**：没有运行；Android/iOS/Windows 本轮未构建。
9. **directions_test 两条旧失败**：见第 3 节，未处理。
10. 频道/主栏往返阶段的慢帧来源未定位（第 4 节第 5 条）。

## 7. 回滚顺序

从新到旧逐个 `git revert`，互相依赖的必须按这个顺序：

1. 本报告的提交（只含 `reports/`）
2. `9bed307`、`54eb868`：只改测试，可单独回滚
3. `78bc16a`：导航与焦点遮挡；独立
4. `999f073`：测量工具；独立
5. `b53b3cb`：视频与小说；依赖 `71f2b35` 的 `pressScale`，须先于它回滚
6. `71f2b35`：悬停、焦点、窗口外观
7. `de374bc`：图片预算；独立，可单独回滚
8. `256b902`：日历与我的；用到 `299540b` 新增的 `AppTokens.pageWidth`，须先于它回滚
9. `299540b`：今日；用到 `0a1471b` 给 `SliverContentMasonry` 加的 `rows`/`maxColumns`
10. `0a1471b`：二创；它的缩放旅程依赖 `98e2ec0`
11. `98e2ec0`：封面淡入

整段回滚：`git revert <本报告提交> 9bed307 54eb868 78bc16a 999f073 b53b3cb 71f2b35 de374bc 256b902 299540b 0a1471b 98e2ec0`。验收包回滚：旧包已被替换，需要从回滚后的提交重新构建。
