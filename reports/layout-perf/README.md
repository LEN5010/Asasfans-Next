# 布局检查点：二创与今日（附 L05–L10）

- 目标文件：`CLAUDE_GOAL.md` 与 `PLAN.md`（2026-09-26 审阅稿）。
- 基线：`main@5149575`。前后对照用的 `2a91d3a` 与它在 `lib/`、`test/`、`macos/`、`android/`、`ios/` 上完全相同，只多了 `tool/perf`。
- 最后一个代码提交：`7b08f8b`，已推送到 `origin/main`（普通推送，未强推）。之后的提交只含报告。
- 验收包：`docs/flutter/验收包/Asasfans Next.app`，构建自 `7b08f8b`。
- 开发 CI：Flutter Development Validation，run [36319499703](https://github.com/LEN5010/Asasfans-Next/actions/runs/36319499703)（`c56e2d4`）、[36320050840](https://github.com/LEN5010/Asasfans-Next/actions/runs/36320050840)（`fdce00f`）与 [36323962719](https://github.com/LEN5010/Asasfans-Next/actions/runs/36323962719)（`7b08f8b`），三次都是四端成功，见第 3 节。
- 用户验收：已接受。2026-09-27 用户回复原话为：能接受，授权你写。`accepted_by_user` 是按这条明确授权记入 `docs/flutter/执行状态.json` 的，不是内部判定；范围是 `7b08f8b` 的交付，包括 840 宽二创从 4 列变 3 列。

## 1. 运行环境

| 项 | 值 |
|---|---|
| 宿主 | Apple M3，24 GB，macOS 26.6.2 (25G83)，8 核，内建 Liquid Retina 屏，60 Hz |
| SDK | Flutter 3.47.3 / Dart 3.13.3（`tool/flutterw`，`/Users/len5010/flutter`），lockfile 未改 |
| Profile 渲染 | 应用窗口，Impeller Metal（日志：`Using the Impeller rendering backend (MetalSDF)`） |
| Profile 窗口 | 逻辑 800×600，DPR 2.0，刷新率 60 |
| Profile 玻璃档位 | `auto` 实际为 premium；`smooth` 实际为 solid。macOS 应用里选不到 standard |
| Profile 数据集 | `tool/perf/perf_fixture.dart`（`perf-fixture-1`）：16 页 × 24 条混合二创，含 1000×30000 长条漫，图片在内存里生成，离线 |
| 无头布局截图 | `flutter_tester` 软件光栅，Solid 材质 |
| 真实渲染器截图 | `flutter_tester --enable-impeller`：本机 GPU 上的 Impeller，三档玻璃都真实绘制；不是应用窗口，不含帧时 |
| 字体 | 本机 PingFang（`ASASFANS_CJK_FONT` 指向 MobileAsset 目录），拉丁字母也用它 |
| 截图数据集 | `two_pages_test.dart` 的 8 件混合作品（2 条短标题视频、竖图、横图、文字、长图、多图、长标题），`visual_fixture.dart` 的其余页面数据，`fanart_journeys_test.dart` 的 40 件作品 |

截图像素不等于逻辑尺寸。每张图的逻辑尺寸、DPR、字号倍率、明暗、实际绘制的玻璃档位和渲染器写在同目录 `manifest.json`。窄 macOS 窗口和无头 390 宽视图都不是 Android 真机。

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
| 测量工具 | `999f073` | `tool/perf/main.dart`、`run_macos.sh`、`compare.py`、`tool/README.md` | 应用窗口截图模式；多次运行并排表 |
| L09 遮挡核对 | `78bc16a` | `app_shell.dart`、`asasfans_app.dart` | 发现并修复：键盘 Tab 聚焦的作品、作者名和更多按钮落在底部导航下（焦点底边 806 > 导航顶 746）；提示条压住导航（844 > 746）。导航改为外壳 Scaffold 的 `bottomNavigationBar`（`extendBody` 常开，正文底部内边距与原来相同），焦点定位扣除状态栏和导航遮挡。两条新测试在修改前失败、修改后通过 |
| 测试截图 | `54eb868`、`9bed307` | `fanart_journeys_test.dart`、`two_pages_test.dart` | 最后一项截图改在打开面板之前；补拍动态正文与小说的悬停 |
| 旧失败清零 | `2c09680` | `test/visual/directions/direction_a.dart` | 示意原型的议程行写死 56 高，本机字体需要 62，在 390 宽溢出 6 px；改为最小 56、随字体长高。全量测试的两条失败因此消失 |
| L09 各档同功能 | `5aa68c3` | `glass_tiers_test.dart`、`visual_harness.dart`、`visual_capture.sh` | 二创与今日在 solid/standard/premium × 手机/宽屏 × 浅/深下做同一组操作：实际绘制档位、切到今日再切回且列表位置不变、更多菜单、提示条在导航上方、键盘焦点不进导航。普通模式与 Impeller 模式各 12 条全部通过 |
| Windows 标题栏跟随 | `fdce00f` | `windows/runner/flutter_window.{h,cpp}`、`win32_window.h`、`window_appearance.dart`、`test/core/window_appearance_test.dart` | 与 macOS 同一个 channel：浅/深设置 `DWMWA_USE_IMMERSIVE_DARK_MODE`，跟随系统时交还 `UpdateTheme`；系统主题变化后重新套用显式选择。Dart 测试钉住只在 macOS/Windows 发送、发送的值、宿主无桥接时不报错。CI Windows 作业编译通过；Windows 上的实际效果没有机器验证 |
| L09 玻璃调校 | `c56e2d4` | `app_glass_style.dart`、`glass_reference_integration_test.dart` | 去掉玻璃库默认的 1.5 倍背景饱和度，光晕 0.75 → 0.4，tint 浅 0.35 → 0.50、深 0.24 → 0.40；厚度、模糊、折射、色散保持库默认。数据见第 4.2 节 |
| 锁屏下强制 resume | `e92664f` | `tool/perf/main.dart`、`run_macos.sh`、`tool/README.md` | `ASASFANS_PERF_FORCE_RESUMED=true` 时测量入口自己把生命周期设为 resumed，锁屏时也照常出帧；JSON 记录 `lifecycle_forced`。只改测量工具，结果见 4.3 |
| 二创列数断崖 | `e94cf14`、`7b08f8b` | `sliver_content_masonry.dart`、`media_grid_delegate_test.dart` | 基线的列数规则在正文宽 740–759 给 5 列，到 760 反而只有 3 列。`0a1471b` 把页面边距从 16 改成 24 后，800 宽窗口的正文正好从 768 落到 752，二创从 3 列变成 5 列，锁屏对照里滚动的 UI 超预算帧升到 26–28%（4.3）。`e94cf14` 先改成与视频网格同列数，随后发现 840/1280 宽会少列、卡片变大；`7b08f8b` 退回二创自己的最小宽度，只把 760 以下的列数封顶在 760 处的列数。代价：正文 580–759 由 4–5 列变 3 列（840 窗口侧栏旁正文 692，卡片约 168 → 222 px），需要用户看。测试钉住 280–2400 宽内列数只增不减（1.0 与 1.6 倍字号） |
| 缩放锚点改为阅读位置 | `360bc2d` | `anchor_restore.dart` | 宽度变化时保持可见区域从上往下 40% 处那件作品（并排时取左边那件），原来保持的是顶边那件。在 `e94cf14` 的 2 列下，30 号作品在 840 宽被挤到屏幕外（更多按钮底边 1032.8 > 1001），由旅程测试发现 |

## 3. 实际命令与退出码

均在仓库根目录，`ASASFANS_FLUTTER_SDK=/Users/len5010/flutter`。按时间顺序，最后一组是交付状态。

| 命令 | 退出码 | 结果 |
|---|---|---|
| `tool/flutterw test --no-pub test/visual test/content test/today test/handoff test/mine test/calendar test/novels test/shared`（`78bc16a` 之前） | 1 | 601 通过，2 失败（directions_test，后由 `2c09680` 修复） |
| `tool/flutterw test --no-pub test/shared/media_image_policy_test.dart test/content` | 0 | 176 通过 |
| `tool/visual_capture.sh reports/layout-perf/shots/before test/visual/two_pages_test.dart test/visual/current_pages_test.dart`（临时工作树，`2a91d3a` 加复制进去的 `two_pages_test.dart`） | 0 | 73 条通过，81 张 |
| `tool/visual_capture.sh reports/layout-perf/shots/after test/visual/two_pages_test.dart test/visual/current_pages_test.dart test/visual/fanart_journeys_test.dart`（`9bed307`） | 0 | 81 条通过，87 张 |
| `tool/perf/run_macos.sh f1-solid-rep1 …`（最终代码，应用窗口） | 失败 | 屏幕锁定，窗口拿不到前台，入口等待 `resumed` 超时；数据已删除，未计入 |
| `tool/flutterw test --no-pub test/visual/glass_tiers_test.dart` | 0 | 12 通过（各档都退回 solid，只验证操作） |
| `tool/flutterw test --no-pub --enable-impeller test/visual/glass_tiers_test.dart` | 0 | 12 通过（三档真实绘制，并断言实际档位） |
| `ASASFANS_VISUAL_IMPELLER=1 tool/visual_capture.sh …/renderer-before-glass-tuning test/visual/glass_tiers_test.dart`（`5aa68c3`） | 0 | 24 张，6 段片段 |
| `dart format --output=none --set-exit-if-changed lib test tool`（`c56e2d4`） | 0 | 无改动 |
| `tool/flutterw analyze --no-pub`（`c56e2d4`） | 0 | No issues found |
| `tool/flutterw test --no-pub`（全量，`c56e2d4`） | 0 | 956 通过，0 失败 |
| `ASASFANS_VISUAL_IMPELLER=1 tool/visual_capture.sh reports/layout-perf/shots/renderer test/visual/glass_tiers_test.dart`（`c56e2d4`） | 0 | 18 条通过，24 张，6 段片段 |
| `tool/flutterw build macos --profile --no-pub`（`c56e2d4`） | 0 | `Asasfans Next.app` 81.2 MB |
| `codesign --verify --deep --strict docs/flutter/验收包/Asasfans Next.app` | 0 | 开发签名，Team 5WR2PV685M |
| `git push origin main` | 0 | `5149575..c56e2d4` |
| `gh workflow run flutter-development-validation.yml --ref main`（第一次） | 0 | run 36319499703 on `c56e2d4`：success。android（`build apk --debug`）、ios（`build ios --debug --no-codesign`）、macos（`build macos --profile`）、windows（`build windows --profile`）四个作业都成功；产物 android 84.3 MB、ios 41.8 MB、macos 29.5 MB、windows 17.5 MB（压缩后），只做开发构建，不发布 |
| `tool/flutterw test --no-pub test/core/window_appearance_test.dart`（`fdce00f`） | 0 | 2 通过 |
| `tool/flutterw analyze --no-pub`（`fdce00f`） | 0 | No issues found |
| `tool/flutterw build macos --profile --no-pub`（`fdce00f`） | 0 | 81.2 MB，替换验收包，`codesign --verify` 通过 |
| `git push origin main` | 0 | `c093afe..fdce00f` |
| `gh workflow run flutter-development-validation.yml --ref main`（第二次） | 0 | run 36320050840 on `fdce00f`：success，四个作业都成功；windows 产物 17,469,423 → 17,485,250 字节，新 runner 代码已编入 |
| `ASASFANS_PERF_FORCE_RESUMED=true tool/perf/run_macos.sh probe-locked reports/layout-perf/profile-locked smooth 15`（锁屏，`2583df8` 加未提交的强制 resume） | 0 | 冷缓存正常出帧；暖缓存滚动 UI P50 16.6 ms，冷缓存 2.7 ms，判断为系统限频（4.3） |
| 交替运行 base / `e92664f`，每个各 2 次（`ASASFANS_PERF_FORCE_RESUMED=true`，`smooth`，15 秒） | 0 ×4 | `locked-{base,final}-rep{1,2}` |
| 临时无头测试 `test/visual/zz_scroll_cost_test.dart`，在 main 与基线工作树各跑 2 次 | 0 | 每帧耗时 2.3 倍，定位到列数（4.3）；测试用后删除，未提交 |
| `tool/flutterw test --no-pub test/shared test/content test/today test/handoff test/visual`（`e94cf14` 的改动，未提交时） | 1 | 512 通过，1 失败：跨断点旅程 30 号作品在 840 宽被挤出屏幕，由 `360bc2d` 修复 |
| 交替运行 base / `360bc2d`，各 2 次 | 0 ×4 | `locked-base-rep{3,4}`、`locked-fixed-rep{1,2}` |
| 交替运行 base / `7b08f8b`，各 2 次 | 0 ×4 | `locked-base-rep{5,6}`、`locked-cap-rep{1,2}` |
| 同一临时无头测试在 `360bc2d`、`7b08f8b` 上各跑 2 次 | 0 | 见 4.3；随后删除 |
| `dart format --output=none --set-exit-if-changed lib test tool`（`7b08f8b`） | 0 | 318 个文件无改动 |
| `tool/flutterw analyze --no-pub`（`7b08f8b`） | 0 | No issues found |
| `tool/flutterw test --no-pub`（全量，`7b08f8b`） | 0 | 959 通过，0 失败 |
| `tool/visual_capture.sh reports/layout-perf/shots/after …`（测试文件同 `9bed307` 那次，`7b08f8b`） | 0 | 81 条通过，87 张 |
| `ASASFANS_VISUAL_IMPELLER=1 tool/visual_capture.sh reports/layout-perf/shots/renderer test/visual/glass_tiers_test.dart`（`7b08f8b`） | 0 | 18 条通过，24 张，6 段片段 |
| `tool/flutterw build macos --profile --no-pub`（`7b08f8b`） | 0 | 81.2 MB，替换验收包；新包与替换后的包 `codesign --verify --deep --strict` 都为 0 |
| `git push origin main` | 0 | `2583df8..7b08f8b` |
| `gh workflow run flutter-development-validation.yml --ref main`（第三次） | 0 | run 36323962719 on `7b08f8b`：success，android、ios、macos、windows 四个作业都成功；产物 android 84.3 MB、ios 41.8 MB、macos 29.5 MB、windows 17.5 MB（压缩后），只做开发构建，不发布 |

验收包二进制 SHA-256（`7b08f8b`）：

```
6f80ecc3b4f2c7062de41463cdf94871071178c878512032c6bac3ac2e258d54  MacOS/Asasfans Next
810ff76f7d15df842c0a04c0b48ae11552addff14b7ace45491e856c67060b75  Frameworks/App.framework/Versions/A/App
```

## 4. 性能与光学

### 4.1 Profile 单因素对照（应用窗口）

方法：`tool/perf/run_macos.sh <label> reports/layout-perf/profile <smooth|auto> 60`。补丁 A/B/C 依次提交在临时工作树的 `perf/factors` 分支上（未推送，已删除，补丁在 `patches/`），每一步只多一个因素。每种配置跑两次，两次都列出，不取平均。场景：进入二创 → 滚轮滚动 60 秒 → 点开长条漫详情和完整长图 → 返回 → 四频道与四主栏往返；同一进程先冷缓存一遍，再暖缓存一遍。窗口不在前台的阶段标为 invalid（本组没有）。每次运行都产出了 JSON 与 footprint 采样；当时逐次的 shell 退出码没有单独记下。

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
2. **主栏目淡入缩放**：关掉后两次运行的差异小于同配置两次之间的差异，看不出收益。保留现有动效，补丁 A 留给 Android 老机复测。
3. **封面首次淡入**：同样看不出收益。main 上保留淡入，但因为缩放崩溃改成了单子组件实现（`98e2ec0`），补丁 B 已不能直接套用。
4. **缩略图预算**：长条漫列表解码像素降约 73%，两次峰值 1037/1123 → 904/780 MB。已并入 main（`de374bc`）。图片缓存末值 77 → 约 100 MB，是因为缓存上限 100 MB 下能放下更多小图，不是泄漏。
5. **没解释的慢帧**：所有配置在四频道/四主栏往返阶段都有 0.7%–7.1% 的 UI 帧超预算，UI P99 12.9–53.1 ms。以上因素都不能解释它，原始最慢帧保留在表里，留作下一步定位对象。

最终代码在前台应用窗口里的 Profile 还没有数据：每次尝试时屏幕都处于锁定状态。锁屏下强制 resume 的对照见 4.3，它只能做同轮相对比较，不能代替前台数据。解锁屏幕后可以直接运行：

```sh
ASASFANS_FLUTTER_SDK=/Users/len5010/flutter tool/perf/run_macos.sh f1-solid-rep1 reports/layout-perf/profile smooth 60
ASASFANS_FLUTTER_SDK=/Users/len5010/flutter tool/perf/run_macos.sh f2-premium-rep1 reports/layout-perf/profile auto 60
python3 tool/perf/compare.py reports/layout-perf/profile > reports/layout-perf/profile/COMPARISON.md
```

运行期间窗口会出现在屏幕上，不要操作鼠标。

### 4.2 真实渲染器与玻璃调校（L09）

`flutter test --enable-impeller` 让 `flutter_tester` 用本机 GPU 上的 Impeller 绘制，`ImageFilter.isShaderFilterSupported` 为 true，三档玻璃都真实绘制，不需要前台窗口。一个障碍：`liquid_glass_widgets` 检测到 `FLUTTER_TEST` 环境变量时，会从资源包根目录的 `shaders/` 加载 premium 着色器（按它自己仓库的布局），而本应用的资源在 `packages/liquid_glass_widgets/shaders/`。`visual_capture.sh` 在 Impeller 模式下把这两个编译好的着色器复制一份到根目录，只影响测试资源包，不影响应用。

测量：手机视图（390×844，DPR 2，带状态栏和底部安全区）二创页，底栏压在 fixture 里颜色最杂的作品上。

- 背景彩度：底栏四个标签区域内的 Hasler–Süsstrunk colorfulness。越低，背景越不抢。
- 标签对比度：今日标签区域内 3%/97% 分位亮度的 WCAG 对比度。小字需要 4.5:1。

| 档位 | 调校前（`5aa68c3`）彩度 / 对比度 | 调校后（`c56e2d4`）彩度 / 对比度 |
|---|---|---|
| solid 浅 | 32.1 / 14.24 | 32.1 / 14.24 |
| solid 深 | 32.3 / 7.24 | 32.3 / 7.24 |
| standard 浅 | 32.2 / **4.33** | 22.0 / 4.88 |
| standard 深 | 34.2 / 5.39 | 23.4 / 6.45 |
| premium 浅 | 29.8 / **4.48** | 21.2 / 4.99 |
| premium 深 | 36.1 / 4.98 | 24.1 / 6.22 |

solid 的彩度主要来自选中项的粉色底块，不是背景。调校前 standard/premium 浅色的标签低于 4.5:1，调校后全部高于。厚度、模糊、折射、色散没改，图里仍能看到下层颜色和折射，只是不再被放大。

片段（`renderer/clip-*.mp4`）：每档浅深各一段，信息流从底栏下方滚过 60 帧，再切到今日 24 帧、切回 24 帧。逐帧渲染，帧间隔为应用时间 16 ms，按 60 fps 合成，所以播放速度等于实际速度。它展示画出来的样子，不是屏幕录像，也不说明帧时。

### 4.3 锁屏下的强制 resume 对照与二创列数

屏幕锁定时窗口拿不到前台，测量入口一直等 `resumed`。`e92664f` 加了开关 `ASASFANS_PERF_FORCE_RESUMED=true`：入口自己把生命周期设为 resumed，引擎照常出帧，JSON 里记 `lifecycle_forced: true`。这组数据有两个限制：

- **系统限频**：窗口不在前台时，进程运行约 10 秒后被降频。探测运行（`probe-locked`）同一场景下，暖缓存滚动 UI P50 16.6 ms，冷缓存只有 2.7 ms。所以暖缓存阶段的绝对值不可信，只在同一轮交替运行之间比较；冷缓存阶段受影响小，但也不和 4.1 的前台数据比。
- **不是前台窗口**：没有合成到屏幕，也不代表用户看到的流畅度。

做法：场景同 4.1，solid，滚动 15 秒。base 是 `2a91d3a` 加上 `e92664f` 对 `tool/perf` 的改动（`lib/` 与基线相同，JSON 里的提交记为 `2a91d3a+dirty`）。每轮按 base、候选、base、候选交替运行。全部阶段见 `profile-locked/COMPARISON.md`，原始数据在 `profile-locked/`。

| 轮 | 运行 | 提交 | 冷滚动帧数 | 冷滚动 UI P50 / P95 (ms) | 冷滚动 raster P95 (ms) | 暖滚动 UI P50 / P95 (ms) | 暖滚动 UI 超预算 |
|---|---|---|---|---|---|---|---|
| 1 | base-rep1 / rep2 | `2a91d3a`+工具 | 847 / 840 | 1.9 / 5.6，1.9 / 5.3 | 2.0，2.0 | 6.8 / 20.0，5.6 / 15.4 | 7.3%，3.9% |
| 1 | final-rep1 / rep2 | `e92664f` | 895 / 894 | 2.7 / 4.9，2.7 / 4.8 | 1.1，1.2 | 13.1 / 30.6，12.7 / 30.0 | **28.3%，26.2%** |
| 2 | base-rep3 / rep4 | `2a91d3a`+工具 | 842 / 846 | 1.8 / 5.4，1.8 / 5.3 | 2.0，2.0 | 7.5 / 15.2，7.7 / 17.5 | 3.9%，5.7% |
| 2 | fixed-rep1 / rep2 | `360bc2d` | 861 / 862 | 2.0 / 5.7，2.1 / 5.5 | 1.8，1.7 | 8.6 / 15.5，8.8 / 16.3 | 4.2%，4.9% |
| 3 | base-rep5 / rep6 | `2a91d3a`+工具 | 847 / 848 | 1.8 / 5.2，1.7 / 5.2 | 1.9，1.8 | 7.8 / 16.9，7.8 / 16.2 | 5.2%，4.9% |
| 3 | cap-rep1 / rep2 | `7b08f8b` | 860 / 864 | 2.0 / 5.7，2.0 / 5.2 | 1.6，1.7 | 8.6 / 14.6，8.8 / 15.0 | 3.4%，3.4% |

定位：用临时无头测试（800×600 视图，DPR 2，384 件二创；每帧先 `jumpTo` 20 px 再 `pump`，量 build/layout/paint 的墙钟时间，不含 raster）在两个工作树各跑两次：

| 代码 | 800 宽窗口的正文宽 / 列数 | 384 件总高 (px) | 向下滚动每帧 P50 / P95 (ms) |
|---|---|---|---|
| `2a91d3a` | 768 / 3 | 53,788 | 约 4.5 / 8.3 |
| `e92664f` | 752 / 5 | 22,817 | 约 10.5 / 13.8 |
| `360bc2d` | 752 / 3 | 55,957 | 5.2 / 8.1，5.1 / 8.2 |
| `7b08f8b` | 752 / 3 | 55,957 | 5.1 / 8.2，5.1 / 7.9 |

`e92664f` 每帧耗时约为基线的 2.3 倍，和每滚动一像素要布局的作品数（2.36 倍）对得上。原因是第 2 节的列数断崖：边距改为 24 后，800 宽窗口正好落在 5 列那一段，自然高度下作品又比原来的统一高度矮，同一屏里的作品多了一倍多。

结论（只限这台 Mac、锁屏条件）：

1. `e92664f` 在暖缓存滚动时 UI 超预算 26–28%，同轮基线 4–7%：这是本轮布局改动带来的退化，4.1 的前台运行当时用的是 `2a91d3a` 链上的因素补丁，没有测到。
2. `7b08f8b` 同轮对照 3.4%/3.4% 对 5.2%/4.9%，冷滚动 UI P95 5.2–5.7 对 5.2，回到基线水平。差值在同配置两次之间的波动范围内，不算提升。
3. footprint 采样最大值在各次之间 664–1026 MB，没有随代码变化的规律，这组数据不下内存结论。


- `shots/before/`：基线 `2a91d3a`，81 张（Solid，软件光栅）。
- `shots/after/`：`7b08f8b`，87 张（Solid，软件光栅）。和上一版（`9bed307`）相比只有 840 宽的二创/今日和缩放旅程变了：二创 4 列 → 3 列。
- `shots/renderer-before-glass-tuning/`：`5aa68c3`，Impeller，三档 × 二创/今日 × 手机/宽屏 × 浅/深，24 张 + 6 段片段。
- `shots/renderer/`：`7b08f8b`，同上，调校后。图片和片段与 `c56e2d4` 那次逐字节相同（手机和 1280 宽的列数没变），只有 manifest 里的提交更新了。
- 文件名 `<场景>_<视图>.png`。视图：`390`（390×844，DPR 2）、`390-dark`、`390-bars`（带 47 状态栏和 34 底部安全区）、`390-x1.6`（字号 1.6 倍）、`320-x2.0`、`600`（600×960，DPR 1）、`840`（840×1000，DPR 1）、`1280`（1280×800，DPR 1）、`1280-dark`。

建议先看这些：

| 看什么 | 文件 |
|---|---|
| 今日宽屏：左侧全高日程列 → 顶部摘要 + 满宽作品 | `before/` 与 `after/` 的 `review-today_1280.png`、`review-today_1280-dark.png` |
| 今日 0/1/4 项日程、模块全关 | `review-today-events{0,1,4}_{390,1280}.png`、`review-today-off_{390,1280}.png` |
| 二创手机/宽屏：视频不再补高 | `review-fanart_390.png`、`review-fanart_1280.png`、`review-fanart_840.png` |
| 840 宽二创/今日由 4 列变 3 列（需要用户看） | `before/` 与 `after/` 的 `review-fanart_840.png`、`review-today_840.png` |
| 大字 | `review-fanart_320-x2.0.png`、`review-today_390-x1.6.png` |
| 静止 / 悬停作品 / 悬停作者 / 键盘焦点 | `review-state-{idle,hover-tile,hover-maker,focus}_1280{,-dark}.png` |
| 动态正文、小说悬停 | `review-state-{dynamic,novel}-hover_1280.png` |
| 视频、动态、小说、日历、我的（L06/L07） | `{videos,dynamics,novels,calendar,mine}_{390,390-dark,600,840,1280}.png` |
| 旅程（仅当前） | `journey-30th-back_390-bars.png`、`journey-30th-cold_390-bars.png`、`journey-30th-resize_{1280,840,390-bars}.png`、`journey-last-above-dock_390-bars.png` |
| 玻璃三档，真实渲染，调校前后 | `renderer-before-glass-tuning/` 与 `renderer/` 的 `glass-{solid,standard,premium}-{fanart,today}_{390-bars,390-bars-dark,1280,1280-dark}.png` |
| 滚动与切换片段 | `renderer/clip-{solid,standard,premium}_390-bars{,-dark}.mp4` |

## 6. 未完成与未验证

1. **最终代码在前台应用窗口里的帧时**：屏幕一直锁定，窗口拿不到前台，没有数据。锁屏下强制 resume 的同轮对照（4.3）找到并确认修复了一处滚动退化，但它被系统限频，只能做相对比较；光学图由 Impeller 渲染补上。前台帧时和宿主内存仍需解锁后运行，命令见 4.1。报告提交后又挂了 55 分钟的等待，每 30 秒检查一次锁屏状态，打算解锁后立即运行；到时仍锁定，什么都没运行。第二次等待中屏幕于 12:08 解锁，脚本自动弹出测量窗口，当时用户正在使用电脑，把窗口关掉了；用户表示不需要这项测量，已停止，不完整的数据已删除。最终代码的前台帧时没有数据。
2. **屏幕录像**：锁屏下无法录屏。已用 Impeller 逐帧渲染的片段代替展示画面，真正的录屏仍需用户在解锁的机器上做。
3. **standard 档在 macOS 应用里的成本**：standard 已在 Impeller 下真实绘制并验证功能，但 macOS 应用只有 premium/solid，standard 的帧时和内存要在 Android 上测。
4. **窗口缩放的帧时**：计划场景里的缩放窗口一步没有进 Profile 脚本；缩放后回到原项只在无头测试里验证。
5. **Android 真机**：安装需要单独授权，没有做。
6. **长条漫详情预览**：详情解码 273×8192，偏糊；源站是否支持服务端裁剪需要探测线上接口，未获授权，没有验证。
7. **Windows 标题栏的实际效果**：已实现（`fdce00f`），CI 编译通过；没有 Windows 机器，运行时切换浅/深是否即时重绘标题栏没有验证。
8. **侧栏宽度分档**：PLAN 第 4 节说表中阈值是候选值，允许简化成两档，不要强造第三种模式。现有两档（<840 底栏，≥840 侧栏）保持不变；目标文件要求两屏样板经用户审阅后再推广，这一项留待审阅后决定。
9. **频道/主栏往返阶段的慢帧**来源未定位（4.1 第 5 条）。
10. **840 宽二创列数**：`7b08f8b` 让正文 580–759 的二创从 4–5 列变成 3 列，卡片变宽（840 窗口约 168 → 222 px）。用户已接受（2026-09-27）。
11. **用户验收**：已接受，见开头。

## 7. 回滚顺序

从新到旧逐个 `git revert`，互相依赖的必须按这个顺序：

1. 本报告的提交（只含 `reports/`）
2. `7b08f8b`：二创列数封顶；它把 `e94cf14` 的做法换掉，须先于 `e94cf14` 回滚。两个都回滚后回到有断崖的基线规则
3. `360bc2d`：缩放锚点；独立，可单独回滚
4. `e94cf14`：二创列数跟随视频网格（已被 `7b08f8b` 替换）
5. `e92664f`、`2583df8`：测量工具的强制 resume 与上一版报告；不影响应用
6. `fdce00f`：Windows 标题栏；改的是 `71f2b35` 建立的桥接，可单独回滚
7. `c56e2d4`：玻璃调校；独立，可单独回滚（同时回滚它改的钉值测试）
8. `5aa68c3`：三档对照测试与 Impeller 截图；只改测试和工具
9. `2c09680`：示意原型议程行；只改测试
10. `58e1f9b`：上一版报告
11. `9bed307`、`54eb868`：只改测试
12. `78bc16a`：导航与焦点遮挡；独立
13. `999f073`：测量工具；独立
14. `b53b3cb`：视频与小说；依赖 `71f2b35` 的 `pressScale`，须先于它回滚
15. `71f2b35`：悬停、焦点、窗口外观
16. `de374bc`：图片预算；独立，可单独回滚
17. `256b902`：日历与我的；用到 `299540b` 新增的 `AppTokens.pageWidth`，须先于它回滚
18. `299540b`：今日；用到 `0a1471b` 给 `SliverContentMasonry` 加的 `rows`/`maxColumns`
19. `0a1471b`：二创；它的缩放旅程依赖 `98e2ec0`
20. `98e2ec0`：封面淡入

代码已推送，回滚用新的 revert 提交，不改写历史。验收包回滚：旧包已被替换，需要从回滚后的提交重新构建。
