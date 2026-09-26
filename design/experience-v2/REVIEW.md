# 本轮更新独立复核

审阅日：2026-09-26。原计划 `98e52c291f7aa94d8344f43ec6df0a9fd52cff27` → 新提交 `7134a40cb6579d9d5831f76a9859a6c2196855ef`。

## 结论

这轮不是无效更新。它完成了多项可以在源码中确认的性能与状态改造，但并未完成原计划中主要的视觉/信息架构重设计。当前状态仍应归为 **PARTIAL_BLOCKED**，而不是“全部完成，只差手机测一下”：T16、T23、T24仍未做，多个页面只有性能或状态增量。

“界面看起来仍是原来的”有结构性依据；本文不声称已在手机运行或做像素级视觉比较。

## 证据口径

通过 GitHub connector 读取最新分支、比较提交、报告、关键源文件、workflow/jobs/logs 与真实产物；通过两份Debug APK里的原始Dart源文本建立文件hash对照。当前索引170份Dart文件、27282行；原索引166份、26312行；共有34份既有运行时文件变动、4份新增。这里的行数不含测试、平台项目或未编入kernel的文件，不等于整个仓库代码量。已核对多个核心文件的Git blob hash与GitHub返回一致。

本环境未执行Flutter、单元测试、Release构建或真机走查。709通过来自仓库执行报告，不是本次重跑。本文实际执行了ZIP/APK拆包、SHA256、源码文本hash与差异分析。

## 任务账本不等于完成率

账本32项主线：9 verified、13 in_progress、7 blocked_external、3 not_started。9/32只代表自报状态的数量，不代表加权产品完成度。条件任务T33/T34/T36不适用有合理依据；T35解析热点仍待实际输入和设备证据。

尤其T15：只加热区helper不能满足原合同里排版、密度、层级与所有触控入口的要求。T08、T10、T11可以确认结构/测试方向，仍不能替代设备内存、画质和系统返回测量。

## 新CI证据修正

[开发构建run 36226439271](https://github.com/LEN5010/Asasfans-Next/actions/runs/36226439271)，2026-09-26 07:19–07:24 UTC，同HEAD：Android Debug、iOS Debug（无签名）、macOS Profile、Windows Profile均成功。报告“没有任何构建证据”已滞后。

[检查run 36226437173](https://github.com/LEN5010/Asasfans-Next/actions/runs/36226437173)：format/analyze成功；可选测试步骤**skipped**。日志确认格式化286份文件零变化、分析无错误。不能据此声称CI独立跑过709条测试。

已有 [perf workflow](https://github.com/LEN5010/Asasfans-Next/blob/7134a40cb6579d9d5831f76a9859a6c2196855ef/.github/workflows/flutter-performance-validation.yml) 不等于已有perf产物。此次取得的是Debug产物，没有Android AOT B0/B1、同设备trace或真实玻璃截图。当前来源没有支持这些验收已经完成的证据。

## 两份实际APK

| 对象 | APK原始字节 | 十进制MB | SHA256 |
|---|---:|---:|---|
| 基线 | 166,921,660 | 166.921660 | `c211b83da10136cf95f815c1be350d69ca83eaaa457f751b1a4ed953c9b67ae1` |
| 本轮 | 166,965,972 | 166.965972 | `576aea779524a820a02b5e5e4da283981b6c1b4af1e75c95c92b44098e2caee4` |

增量 **+44,312字节**，实质上体积没变。这里没有把外层84MB左右的artifact ZIP冒充APK，也没有把两个Debug包比较冒充AOT优化收益。原来的引擎/多ABI/调试资源结构仍占主导。

## 为什么视觉没有明显新一代感

| 文件/链路 | 核对结果 | 对体验的含义 |
|---|---|---|
| `app_shell.dart` / `app_router.dart` | 原始文本hash相同 | 主导航组织与稳定壳体未重设计；已有浮栏不能重复算成新成果 |
| `app_theme.dart` / `app_page_bar.dart` | 相同 | 一般页面标题仍使用16px/w600的紧凑语法；根页没有独立编辑式头部 |
| `media_card_surface.dart` | 相同 | 视频和作品仍共享带边框卡片壳；主体陈列语法没有改变 |
| `app_tokens.dart` | 新增触摸目标辅助；既有颜色、半径、字体结构保留 | 是可达性改善，不是完整新设计系统 |
| `fanart_card.dart` | 普通图16:9，masonry图4:3 | 不能因用了masonry就称自然比例画廊；插画仍像视频封面单元 |
| `content_page.dart` / `fanart_filter_bar.dart` | 频道、搜索、两行快捷条件、局部条件摘要并列 | 导航和查询的视觉语义仍拥挤；不是完全没摘要，而是未统一和压缩 |
| `today_page.dart` | 主要调整手机顺序、生命周期、全关闭提示 | 模块优先级改善，不等于新的内容构图与持续任务入口 |
| `mine_page.dart` | 新增17行工具入口；偏好仍整块放根页 | 资料首页仍像设置目录，而非用户的本地内容空间 |

源码证据入口：[AppPageBar](https://github.com/LEN5010/Asasfans-Next/blob/7134a40cb6579d9d5831f76a9859a6c2196855ef/lib/shared/widgets/app_page_bar.dart)；[FanartCard](https://github.com/LEN5010/Asasfans-Next/blob/7134a40cb6579d9d5831f76a9859a6c2196855ef/lib/features/content/presentation/fanart_card.dart)；[Mine](https://github.com/LEN5010/Asasfans-Next/blob/7134a40cb6579d9d5831f76a9859a6c2196855ef/lib/features/mine/presentation/mine_page.dart)；完整hash见evidence/source-comparison.json。

## 前一版计划的流程问题

旧计划写了逐页方向和视觉回归，也明确过Solid与玻璃分开验证。但它把有决定力的视觉验收放在P5，前面缺少“多个真实方案→选定方案→关键三屏先通过”的硬闸门。抽象要求如“紧凑、清晰、克制”容易被解释为原布局上调顺序、加helper、修测试；于是工程进展可观，用户感受到的产品变化却很小。

修正不是再写更多形容词，而是让UI任务的完成证据包含：**实际页面、不同结构方案、关键用户流程、尺寸状态矩阵、人工视觉判断**。没有设备不能成为整个布局轨道停工的理由，Flutter的widget像素快照可先完成；真实Impeller/Skia/原生交互则另设设备闸门。

## 全32项逐项交叉表

| ID | 仓库自报 | 独立复核范围 | 下一步 |
|---|---|---|---|
| T01 | verified | 范围与基线已有记录 | 保持；加上新 HEAD、CI 与 capability matrix。 |
| T02 | verified | 原报告声称检查和709测试通过；当前CI验证format/analyze，测试被跳过 | 重新跑受影响测试及阶段全测；不把CI绿等同709用例独立复核。 |
| T03 | in_progress | 只有部分host测量；设备场景和integration scaffold不足 | 拆开 headless布局场景与设备性能场景，两者都落实脚本入口。 |
| T04 | blocked_external | perf身份与workflow有实现；当前成功的是开发构建 | 补真实perf产物、签名/manifest检查及正式无钥匙拒绝测试。 |
| T05 | blocked_external | 未提供Android AOT B0/B1 | 选择并记录可比基线；f89abb5之前已有小型修复，不能称完全原样98e52c2。 |
| T06 | blocked_external | 尚无AOT依赖成本归因 | 保留依赖；用真实AOT包审计，不再拿debug ZIP大小比较。 |
| T07 | in_progress | Solid/standard/premium策略已做；自动目前是平台预设而非帧时自适应 | 代码方向可保留；按真实渲染器验证，并保持稳定scope。 |
| T08 | verified | 统一分桶预览/解码策略已实现 | 结构性接受；解码柔化、总内存和大字图像清晰度待视觉/设备验证。 |
| T09 | in_progress | 详情预览与viewer16MP上限已做 | 极长图可读性与退出内存尚不能宣称达标；16MP不是应用内存总上限。 |
| T10 | verified | 二创/视频/动态identity恢复、冷查询与有界追页已做 | 保留实现；新布局后复核实际可见矩形、遮挡、删项与取消。 |
| T11 | verified | 仅当前和最近频道mounted；controller继续保留必要内容 | 接受结构改进；未证明PSS下降或长场景没有积累。 |
| T12 | verified | 固定视频网格与规则投影复用有实现 | 保持；不可将相同几何的性能改造写成视频UI重设计。 |
| T13 | verified | host SQL测量支持暂不引入worker | 接受不做复杂化的决定；不外推为老机实测。 |
| T14 | verified | 可见性恢复与根偏好select已有改造 | 保持；真机隐藏页面请求数、跨日与生命周期仍需场景证据。 |
| T15 | verified | 新增touch helper；主题整体不变；部分segments仍40dp | 按完整合同应改为部分完成：缺全局层级、组件展示与所有热区检查。 |
| T16 | not_started | router、shell与页面栏原文本未变 | 属于本轮新体验主线；只改呈现，不破坏已稳定导航状态。 |
| T17 | in_progress | 搜索旁筛选、all-hidden提示已有；全量条件摘要未统一 | 保留已有草稿/应用/取消与部分摘要，不重造查询控制器。 |
| T18 | in_progress | 低档保底和部分语义已有，未有完整光学/a11y走查 | 布局先headless；光学另分档验证。 |
| T19 | in_progress | 手机模块排序改变；无继续挑选与根页新构图 | 不是完整今日重设计，纳入U11/U19。 |
| T20 | in_progress | 性能网格和返回改进，卡片信息结构大体原样 | 纳入新的媒体呈现与外跳语义验收。 |
| T21 | in_progress | 修了文字卡点击/图片策略/返回；封面仍固定16:9或4:3 | 作品陈列本体未重做，不能把masonry命名等同自然比例画廊。 |
| T22 | in_progress | 查询返回和状态提示改变 | 阅读排版、引用层级与多图构图需单独交付。 |
| T23 | not_started | 现有lazy reader未改 | 不是性能故障，但新排版和阅读工具栏任务尚未实施。 |
| T24 | not_started | 日历仅生命周期改动，布局未重做 | 新增日期条/议程联动，不更换ICS/domain。 |
| T25 | in_progress | 性能偏好与工具入口有增量 | Mine仍嵌入全部PreferencesControls；资料/设置的信息架构未分离。 |
| T26 | in_progress | 工具文字入口已加 | 用途分组、真实更新语义、关闭后焦点尚须验证。 |
| T27 | blocked_external | Dart恢复改善；原生系统闭环待设备 | 保留轻量返回服务，系统权限和进程重建待真机。 |
| T28 | blocked_external | 报告已经滞后：同HEAD四平台开发构建成功 | 更新为构建已验证、运行/输入待验证；不是全平台体验验收通过。 |
| T29 | in_progress | 报告有检查；最新CI测试被跳过 | 追加完整测试和perf签名检查，保留真实退出码。 |
| T30 | blocked_external | 没有真实截图集；将整个视觉任务归因无设备过宽 | Solid widget截图可先做；真实玻璃截图仍需匹配renderer。 |
| T31 | blocked_external | 没有同设备AOT性能闭环 | 继续未验证；debug包约166.97MB，不代表优化后Release大小。 |
| T32 | in_progress | 报告诚实标注PARTIAL_BLOCKED但证据已部分过时 | 更新证据，维持部分完成判断，不错误改成仅待真机。 |

## 需要补齐而非推翻的底座

保留统一图片策略、两频道驻留、identity恢复、规则投影、生命周期可见性、Solid档和正式签名保护。新UI会改变卡高、标题栏高度和安全区，所以需要重新测锚点“实际可见且未被遮挡”，但不能借此重写网络、数据库、路由和业务控制器。

## 本次不认定为缺陷的事项

没有证据就不把所有keepAlive判为泄漏；不强制SQL worker；不强制磁盘缓存；不把库升级当成已经证明的性能改进；不因源码行数没有减少就认为运行时优化失败；不要求每页都必须玻璃化。
