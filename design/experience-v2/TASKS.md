# Experience V2 执行任务卡

状态：全部是下一轮建议任务，尚未实施。每个任务按四类证据分别验收，不把代码通过等同视觉成功。

顺序约束见tasks.json；建议一个主Agent写入，研究与审查最多两个只读Agent。实际不存在的目录标为建议新增；现有源文件名以当前HEAD核对，不猜函数或接口。

P0＝证据与基线；P1＝设计选择与样板；P2＝系统收口；P3＝逐页与闭环；P4＝验收与交付。

U23受设备条件约束，但U02、U05、U06不以缺少Android SDK为由跳过。U24允许诚实的带缺口交付，不意味着U23获得完成状态。

## U01 · 更新完成度、能力边界和性能验证交接

阶段：P0 ｜ 前置：无

**实际范围**

- `reports/optimization/`
- `android/app/build.gradle.kts`
- `.github/workflows/`
- `design/experience-v2/（建议新增受版本管理目录）`

**实施**

1. 核对当前HEAD和工作区；本包固定7134a40，不覆盖之后的用户修改。按REVIEW逐项修正旧账本，保留原始报告。
2. 把四平台开发构建成功、当前CI跳过测试、709测试为会话自报三件事分开登记。检查现有per-ABI性能工作流，不自动触发付费任务、发布或生产签名。
3. 记录性能对比B0的确切业务状态。f89abb5已经包含先行小修复；要么如实定义此基线，要么独立worktree仅移入必要构建配置，禁止污染当前工作区。
4. 建立真实capability matrix：视频的标签/作者/时间/排序，其他频道各自支持的查询，已有路由、数据与外跳。检查/docs忽略规则，新的计划、参考和任务账本要能被提交。

**证据**

HEAD/status/lockfile及受影响文件；旧32任务交叉表；工作流run与step链接；功能和查询能力矩阵。

**完成标准**

完成度口径准确；新方案没有虚假搜索、播放器、推送或登录承诺；旧性能验证有明确接续入口。

## U02 · 建立真实Widget截图实验台与视觉基线

阶段：P0 ｜ 前置：U01

**实际范围**

- `test/helpers/`
- `test/fixtures/`
- `test/visual/（建议新增）`
- `lib/features/各页面presentation/`
- `design/experience-v2/visual/（建议新增）`

**实施**

1. 复用现有Provider overrides、离线SQLite与图片fixture；为Today/二创/视频/日历/我的/阅读建立确定性的场景，不复制一套假页面。
2. 从当前真实widget生成Solid布局截图；统一390×844逻辑尺寸、DPR、字号、浅深色和固定日期，补1280宽屏。增加长标题、9图、无图、空/错/旧缓存等场景。
3. 检查中文字体是否真正显示，不能接受Ahem方块字；只从执行机系统或明确许可测试字体加载，不把字体文件提供给用户或打包进本执行包。
4. 分别标记headless Flutter、原型、实际设备截图。设置网络失败即报的fixture，不让截图依赖真实B站或生产服务。

**证据**

实际PNG、scenario manifest（commit/fixture/view/theme/textScale/renderer/font）、截图生成命令与退出码；缺条件不能伪造图。

**完成标准**

至少6个当前页面浅深色有真实widget基线；能独立重跑。此任务不需要Android SDK或新的Linux应用发布目标。

## U03 · 提炼参考模式，而非堆积参考链接

阶段：P1 ｜ 前置：U01

**实际范围**

- `REFERENCES.md`
- `design/experience-v2/patterns/（建议新增）`

**实施**

1. 按REFERENCES核验一手版本，最多8组核心设计来源、24张模式卡；先完成12张高频旅程卡。
2. 每卡说明用户任务、进入/退出、状态变化、为什么适用、本项目对应数据与不抄部分；商业截图只做内部研究，不能复制资产分发。
3. LoveIwara读取材料与菜单入口；PiliPlus读取视频卡分层；Apple/Pocket Casts/Tide Guide/Slack对照其官方说明，不能只看一个封面图。
4. 建立拒绝清单：装饰大Hero挤压内容、整页胶囊、假全局搜索、每卡玻璃、为模仿迷你播放器新增播放依赖。

**证据**

模式卡ID、源URL/版本/commit、对应真实路径与验收动作；没有测试过的应用明确仅为文档/源码研究。

**完成标准**

每个参考至少导出一个可执行选择或明确拒绝；研究达到选择依据后停止，不无限扩展项目清单。

## U04 · 信息架构、内容能力与文案合同

阶段：P1 ｜ 前置：U01

**实际范围**

- `lib/app/router/app_router.dart`
- `lib/features/content/domain/`
- `lib/features/mine/presentation/mine_page.dart`
- `lib/features/handoff/domain/`

**实施**

1. 保持4主导航；区分主目的地、频道、查询和内容动作。Tools保持辅助入口，不新增无意义第5主tab。
2. 列每个频道支持的字段；视频未支持keyword时不显示同义搜索框，使用真实筛选/作者查询入口。
3. 我的内容资产与设置分离，旧路径重定向/别名保证原入口继续可达；继续挑选与旧继续观看记录明确区分。
4. 把截图可能暴露的假字段删掉：精选若没有编辑来源就叫最新/最近；不显示假的播放进度、准时推送或云同步状态。

**证据**

路由与任务流图（文本可）、字段/文案表、旧路径兼容测试清单。

**完成标准**

三种候选都遵循同一功能合同，视觉方向不能靠删功能获得简洁。

## U05 · 三种真实布局候选对照

阶段：P1 ｜ 前置：U02, U03, U04

**实际范围**

- `test/visual/或测试专用gallery`
- `TodayPage/FanartCard的可注入展示组件`
- `design/experience-v2/directions/`

**实施**

1. 用相同数据实现A内容刊、B密集工作台、C作品展廊三方向；每个只做今日和二创两屏，共6个真实布局原型。
2. 差异必须体现在区域大小、信息顺序、图片比例、标题/正文关系和操作位置，不能仅变粉色、圆角或玻璃强度。
3. 原型接真实展示组件与fixture，不连生产写入；先以Solid判断设计。给出浅深色、长标题和无图情形。
4. 按任务可发现性、信息清楚、品牌、内容空间、实现成本、低档一致性选择一个方向；没有用户反馈则标记内部选型，默认A，不能声称已获用户批准。

**证据**

6屏成组对照、设计决策表、选择/拒绝原因；所有原型标记prototype而非当前APP截图。

**完成标准**

只保留一个主方向进入U06，不将三个方向平均混合，也不未经评审就全站改组件。

## U06 · 三屏可交互样板与设计闸门

阶段：P1 ｜ 前置：U05

**实际范围**

- `lib/features/today/presentation/`
- `lib/features/content/presentation/`
- `lib/features/mine/presentation/`
- `test/visual/`

**实施**

1. 将胜出方向做成今日＋二创＋我的完整三屏样板，验证首屏、筛选、作品详情返回和收藏反馈。
2. 比较旧版与样板的灰度层级、实际内容可见面积、任务点击路径；保留Solid与玻璃相同几何。
3. 最多两轮集中修正，逐条写问题与变化；不为追求像素差加入无意义布局。
4. 不通过样板验收不得将相同旧卡片复制到全站并宣布重设计完成；内部评审与用户接受单独记录。

**证据**

三屏可交互路径、同fixture前后图、至少筛选/返回/收藏三段实际交互记录，或明确标记尚未执行的设备部分。

**完成标准**

去掉玻璃与色彩后仍能分辨新布局和优先级；主要动作无需猜图标；不依靠新增后端。

## U07 · 从胜出样板抽取语义Token与组件展示

阶段：P2 ｜ 前置：U06

**实际范围**

- `lib/app/theme/app_tokens.dart`
- `lib/app/theme/app_theme.dart`
- `lib/shared/widgets/app_controls.dart`
- `test/visual/component_gallery_test.dart（建议新增）`

**实施**

1. 从已通过样板抽取display/section/body/meta、page/section/item spacing、内容面/chrome/选中语义，不从一组圆角数字倒推全站。
2. 将触摸48dp与视觉尺寸分开，考虑Windows触屏，不只按操作系统名判断。
3. 组件展示覆盖长中文、浅深色、Solid/Regular、禁用/聚焦/选中、1.0/1.3/2.0字号；图标系统保持一致。
4. 不引入新的全局主题框架，不下载字体作为运行必需，不为方便降低对比度或缩字号。

**证据**

Token映射、组件展示截图、触摸边缘与焦点测试。

**完成标准**

Token反映信息语义；不是只增加touch helper就认为排版/密度设计已完成。

## U08 · 导航、页面头部和自适应外壳

阶段：P2 ｜ 前置：U07

**实际范围**

- `lib/app/router/app_shell.dart`
- `lib/app/router/app_router.dart`
- `lib/shared/widgets/app_page_bar.dart`
- `lib/shared/widgets/glass/app_glass_navigation.dart`

**实施**

1. 保留go_router branch状态、现有四导航和旧slug，不更换路由/状态框架。根页可有内容式标题，子页保持清楚返回。
2. 建立页面头部、sliver、底栏和键盘安全区的唯一占位契约，避免旧pageInsets再叠新header导致双留白。
3. 中宽屏采用实际空间决定导航rail与主从布局；禁止简单放大手机卡片。切宽度不能重置查询或阅读位置。
4. 区分导航、频道和筛选的视觉语义；已有浮动/随滚动隐藏不是本轮新增功劳，只有真正改变的行为才记成果。

**证据**

320/390/600/840/1280截图、键盘/返回/深链/切窗测试；边缘遮挡对照。

**完成标准**

每页真实内容不被顶部和底栏遮住，角色与层级不混，低档与高档布局相同。

## U09 · 按频道能力统一查询与渐进筛选

阶段：P2 ｜ 前置：U07, U04

**实际范围**

- `lib/features/content/presentation/content_search_control.dart`
- `lib/features/content/presentation/fanart_filter_bar.dart`
- `lib/features/content/presentation/*feed_view.dart`

**实施**

1. 保留每频道实际查询字段。内容频道与条件层分开，常用条件最多一行；现有条件摘要是局部实现，改成一致摘要而非宣称从零新增。
2. 筛选面板打开复制草稿，连续修改不关闭，应用一次提交，取消不影响内容，清空范围明确。
3. 摘要显示主要1–2项与剩余数，可单项删除；已保存查询的名字与当前条件变化一致。
4. 保留IME组合、取消/generation、局部刷新和滚动状态；一项变化不整屏白闪。

**证据**

各频道有/无查询与多条件截图；草稿取消/应用/快速响应乱序/组合输入测试。

**完成标准**

查询更省空间且完全保留能力；没有可输入但后端不支持的假搜索。

## U10 · 拆分内容呈现家族，停止一种厚卡片包万物

阶段：P2 ｜ 前置：U07

**实际范围**

- `lib/shared/widgets/media_card_surface.dart`
- `lib/shared/widgets/media_cover.dart`
- `lib/shared/widgets/app_panel.dart`
- `lib/features/content/presentation/*card.dart`

**实施**

1. 保留共用交互/语义，但不强制共用可见外框。形成编辑分区、视频卡、作品tile、阅读动态和议程/资料行五类呈现。
2. 视频固定比例与lazy extent保持；作品允许已知比例或稳定的portrait预览；文本不放进假的视频封面盒。
3. 统一次操作入口和键盘/屏幕阅读器语义，不给每个元字段一个chip。
4. 图片策略按实际展示尺寸、BoxFit和DPR处理，cover需要源比例时明确处理/例外；原图与预览URI保持分离。

**证据**

五类展示对比、无图/缺字段/极长标题fixture、共享动作与边缘点击回归。

**完成标准**

视觉有类型差异，代码仍共享必要逻辑；没有为新设计失去图片预算、懒构建或来源入口。

## U11 · 今日：时间与内容主导的首页

阶段：P3 ｜ 前置：U08, U10

**实际范围**

- `lib/features/today/presentation/today_page.dart`
- `lib/features/today/presentation/on_this_day_section.dart`
- `lib/features/today/application/today_providers.dart`

**实施**

1. 以日期和主标题建立身份，用紧凑的下一日程、实际内容和后续分区形成节奏，不只调整旧模块顺序。
2. 尊重用户关闭/排序偏好；无日程时小幅收缩，失败和旧缓存不能伪装成没有内容。
3. 历史模块保留但不强占首屏；精选标签必须有真实编辑/排序依据，否则显示最新。
4. 为U19的可选继续挑选预留单一插槽，没有快照时不留空卡。

**证据**

正常/无日程/全隐藏/旧缓存/跨日/模块失败截图；模块开关和数据顺序测试。

**完成标准**

首次打开能找到接下来的事和真实作品；照片/标题成为主体，而不是大段功能入口。

## U12 · 视频：高密度但不拥挤的发现

阶段：P3 ｜ 前置：U08, U09, U10

**实际范围**

- `lib/features/content/presentation/community_feed_view.dart`
- `lib/features/content/presentation/video_card.dart`
- `lib/features/handoff/presentation/watch_on_bilibili.dart`

**实施**

1. 保留固定extent网格，封面＋两行标题＋一层必要元信息；时长、成员、分类仅用真实可用值。
2. 主点击沿用去B站流程，次动作就近且不盖住主要内容；密度变化由样板决定，不引入播放页。
3. 保留全部/切片/录播及时间/排序/作者能力，筛选摘要与刷新范围明确。
4. 重测滚动到深项→外跳→返回在新卡片高度下确实可见。

**证据**

长标题/缺图/大字、默认/筛选、外跳失败与返回第30项测试；与旧页相同内容前后图。

**完成标准**

可见内容占比和阅读顺序有明确改善；不能只把相同布局换fixed extent当作UI完成。

## U13 · 二创与详情：作品主导，不统一压成视频盒

阶段：P3 ｜ 前置：U08, U09, U10

**实际范围**

- `lib/features/content/presentation/fanart_card.dart`
- `lib/features/content/presentation/fanart_detail_page.dart`
- `lib/features/content/presentation/fanart_image_viewer.dart`
- `lib/shared/widgets/sliver_content_masonry.dart`

**实施**

1. 先从源数据检查是否有可靠尺寸；已知比例直接使用，无尺寸采用稳定预览策略（4:5仅为候选），不能批量下载原图探尺寸或滚动中反复改高。
2. 保留完整查看；超长图明确预览/完整模式和总像素预算，不靠缩小到不可读来解决内存。
3. 纯文本作品使用阅读tile，单图/多图/视频清楚区分，作者、来源与次操作不和作品争位置。
4. 详情打开与返回绑定内容identity，已有锚点与offset恢复兼容新布局；交互手势不和长图滚动/缩放冲突。

**证据**

横/竖/极长/多图/GIF/无图六组截图；打开退出返回与缺失目标测试；真实设备viewer内存另列。

**完成标准**

作品视觉地位明显改变且原始信息可达；不误称现有contain为裁图bug，不把无尺寸数据伪造为自然瀑布流。

## U14 · 动态：阅读层次与稳定多媒体

阶段：P3 ｜ 前置：U08, U09, U10

**实际范围**

- `lib/features/content/presentation/dynamic_feed_view.dart`
- `lib/features/content/presentation/dynamic_card.dart`
- `lib/features/content/presentation/dynamic_rich_text.dart`
- `lib/features/content/presentation/content_images.dart`

**实施**

1. 作者/时间、正文、转发、媒体明确分层；宽屏限制中文阅读行长。
2. 长文展开与收起保持位置，链接/表情/选择/来源语义完整，不能为整卡onTap吞掉文字操作。
3. 成员/类型/日期和返回能力完全保留，屏蔽结果与正常空数据不同。
4. 媒体采用已有预算，避免展开一条动态就预取所有远处原图。

**证据**

长文/嵌套转发/多媒体/缺字段/离线截图与语义测试；query/anchor回归。

**完成标准**

正文成为主体，不需要穿过重复框线找内容；无不可选择文本或失效链接回归。

## U15 · 小说：安静阅读与上下文工具

阶段：P3 ｜ 前置：U08, U09, U10

**实际范围**

- `lib/features/novels/presentation/novel_feed_view.dart`
- `lib/features/novels/presentation/novel_reader_page.dart`

**实施**

1. 列表排版对应作品信息，不使用视频型封面占位；阅读正文优化行长、字体层级、章首和工具位置。
2. 保留SelectionArea、ListView.builder、返回列表位置与现有内容限制。
3. 减少工具干扰但保持可发现返回/来源；不添加TTS、下载引擎、翻页物理模拟或云进度。

**证据**

长章节、200%字号、深色、复制/选择、受限作品信息页的截图与测试。

**完成标准**

不是因为旧reader已lazy就跳过设计；也不能为了重设计重写稳定阅读底层。

## U16 · 日历：日期导航与议程联动

阶段：P3 ｜ 前置：U08, U09

**实际范围**

- `lib/features/calendar/presentation/calendar_page.dart`
- `lib/features/calendar/presentation/calendar_event_widgets.dart`
- `lib/features/library/presentation/calendar_follow_button.dart`

**实施**

1. 窄屏用紧凑日期条与议程组织今天/接下来，月视图可展开；保留日周月选择、回今天、成员/类型筛选。
2. 宽屏日期/议程主从联动，取消/改期的文字和状态优先于颜色装饰。
3. 不改变ICS解析、时区、重复例外和缓存策略；关注只描述当前实现的应用内变化能力。
4. 无活动、加载失败、旧缓存和规则/筛选无结果区分呈现。

**证据**

今天/跨月/改期/取消/多事件/旧缓存与宽屏截图；现有calendar测试完整保持。

**完成标准**

用户能清楚定位下一项日程；不是仅改resume生命周期就标记日历重设计。

## U17 · 我的：本地资料首页，设置退居次级

阶段：P3 ｜ 前置：U08, U10

**实际范围**

- `lib/features/mine/presentation/mine_page.dart`
- `lib/features/preferences/presentation/preferences_controls.dart`
- `lib/features/library/presentation/`
- `lib/features/backup/presentation/`
- `lib/app/router/app_router.dart`

**实施**

1. 收藏/稍后看/记录/书签形成资料入口与必要预览，设置放到明确次级页；不一次性读取整个资料库求数量。
2. 保留全部旧路径与本地登录清理入口；没有账号系统就不造头像登录中心或云同步图标。
3. 规则、订阅、备份仍可访问，危险操作保留影响预览、确认和事务结果。
4. 区分历史播放记录和新继续挑选；不伪称应用知道B站观看进度。

**证据**

空资料/有资料/设置/备份失败/残留登录、大字和旧深链测试；首页与旧版明确对照。

**完成标准**

打开我的看到自己的内容而不是一长页PreferencesControls；数据保护和既有功能完整。

## U18 · 工具、更新与异步状态的一致体验

阶段：P3 ｜ 前置：U08, U09

**实际范围**

- `lib/features/tools/presentation/tools_sheet.dart`
- `lib/features/updates/presentation/`
- `lib/shared/widgets/feed_scroll_view.dart`
- `lib/features/content/presentation/feed_status_footer.dart`

**实施**

1. 工具按真实用途分组，保留辅助圆钮与文字入口；较少动作优先就近菜单，复杂连续设置用稳定面板，不盲目全部底部弹出。
2. 更新页只呈现真实可获得的变化，日程改期/取消与旧记录区分。
3. 首次占位、保留内容刷新、尾部加载、尾部失败、全屏首次失败和规则全隐藏统一语义但不要相同无信息空图。
4. 关闭菜单/弹层焦点回原控件；外链启动失败提供明确回退，不以成功toast掩盖错误。

**证据**

加载/空/错误/旧缓存/全隐藏和工具分组截图；重试不删旧列表、focus、外链失败测试。

**完成标准**

每种状态能回答发生了什么和能做什么；不是只改了工具入口标签。

## U19 · 继续挑选与跨应用返回的有界上下文

阶段：P3 ｜ 前置：U11, U12, U13, U14, U17

**实际范围**

- `lib/features/handoff/application/`
- `lib/features/handoff/domain/`
- `lib/features/handoff/presentation/`
- `lib/features/today/presentation/`
- `lib/app/router/app_shell.dart`

**实施**

1. 把一次性待恢复ReturnContext与最近浏览snapshot明确区分。最多保存一个最新有效上下文，优先复用现有读模型。
2. 附属入口显示频道和真实条件，可关闭；点击仅恢复浏览，不触发外跳；不存在快照不显示。
3. 必要持久化写在提交查询/离开/稳定节点，不每帧写库；清历史/隐私行为覆盖快照，备份与schema变化如有必须记录兼容。
4. 底部同时最多导航＋一个上下文附属区；键盘、完整查看器和模态面板优先，取消/失败不损失原状态。
5. 保持Android原生轻量返回按钮，不新建Flutter engine、不监控其他应用内容。

**证据**

最近记录存在/过期/关闭、冷/热/进程重建返回、连续外跳、消费后不重放的测试；B站真实系统交互留U23。

**完成标准**

形成应用自己的“发现—B站—回来继续”闭环，且不变成假迷你播放器或陈旧会话重放器。

## U20 · Liquid Glass材料与有意义的交互过渡

阶段：P3 ｜ 前置：U08, U09, U10

**实际范围**

- `lib/shared/widgets/glass/`
- `lib/shared/widgets/app_motion.dart`
- `lib/shared/widgets/app_panel.dart`
- `lib/features/preferences/presentation/preferences_controls.dart`

**实施**

1. 使用现有单个玻璃依赖；几何先独立于材质，常驻背景采样区域初始预算约2处，具体以层树与trace验证而非声称等于2个pass。
2. 只做导航选择、筛选面板连续性、内容/详情返回和收藏反馈四类必要过渡，保留已有合适的press动画，不持续播放装饰。
3. Regular与premium按有效档决策，Solid真正不采样；系统减少透明度/高对比/减少动态优先，失败不空白。
4. 不在玻璃整体外套会隔离背景的透明层来做假材质化；弹层背景和前景可读性先于折射强度。
5. C01未被证明成功则继续当前API；自动仍是平台预设时如实标注，不声称已经动态测帧降档。

**证据**

各档同几何截图、busy背景对比、减少动态/透明度与切档不丢状态测试；真实shader录像和帧时留U23。

**完成标准**

玻璃强化导航与操作关系，而不是给每个内容卡增加成本；Solid仍是一套完整好看的界面。

## U21 · 宽屏、输入与无障碍压力走查

阶段：P4 ｜ 前置：U11, U12, U13, U14, U15, U16, U17, U18, U19, U20

**实际范围**

- `test/layout_overflow_test.dart`
- `test/app_shell*_test.dart`
- `test/visual/`
- `lib/shared/widgets/`

**实施**

1. 覆盖320/390/600/840/1280与1.0/1.3/2.0字号，核心页浅深色；重点大字不是只测默认短标题。
2. 检查键盘/触摸/鼠标焦点顺序、Enter/Space/Esc、屏幕阅读器名称与选中状态，触摸目标不相互重叠。
3. 检查模态/底栏/上下文附属区/软件键盘的优先级；resize、横竖屏和返回都保持当前状态。
4. 对灰度截图做层级检查；尺寸矩阵用于找问题，不用几百张自动更新的golden代替人工审阅。

**证据**

压力场景索引、修复前后图、实际命令与问题闭环；真实OS输入缺席明确分开。

**完成标准**

关键文字可读、操作可达、状态连续；不通过调小字体、删入口或放宽golden阈值掩盖问题。

## U22 · 功能回归、平台构建与可安装证据

阶段：P4 ｜ 前置：U21

**实际范围**

- `test/`
- `.github/workflows/`
- `tool/`
- `reports/experience-v2/（建议新增）`

**实施**

1. 每阶段先跑受影响测试，收尾跑完整suite、format和analyze；CI显式启用run_tests，不再只看总绿勾。
2. 在适合宿主构建四平台现有目标；Android补独立perf Release/Profile与arm64/armv7产物，核对manifest/签名及正式无钥匙拒绝。
3. 比较同ABI真实APK，记录code/assets/native差异；新界面不将商业素材/字体/巨大fixture带入正式包。
4. 保存产物hash、模式、commit和命令。没有权限运行CI时输出确切待执行参数，不自动触发或发布。

**证据**

测试日志、失败归因、build退出码、APK报告和证书摘要；未知平台不能写通过。

**完成标准**

工程交付可被复核；709旧报告不自动成为新版本测试证据。

## U23 · 真实设备性能、光学与系统闭环

阶段：P4 ｜ 前置：U22

**实际范围**

- `Android性能验证包`
- `VALIDATION.md原场景`
- `reports/experience-v2/device/（建议新增）`

**实施**

1. 至少目标老机＋普通机，同ABI/mode/data/cache/renderer，重复原场景测UI与raster各自P95/P99、启动分阶段、PSS/live images和请求数。
2. 比较新UI同一场景Solid/Regular/Premium，并与已记录的B0/B1区分构建收益和代码收益。不得拿Debug和Release混比。
3. 用滚动图片/高反差背景录真实导航与弹层，查看黑块、文字反差、shader延迟和切档状态。
4. 真机走B站安装/未装、浮窗拒绝/撤销、进程重建、连续外跳、旋转和停止通知；缺设备保持待验收。

**证据**

设备型号/OS/ABI/renderer/刷新率、trace和原始CSV、真实截图/录像与场景次数；不能用golden代替。

**完成标准**

有数据才宣布流畅/减包收益；未达标要降材料成本或说明残留，而不是调整统计口径。

## U24 · 独立审阅、状态判定与可回退交付

阶段：P4 ｜ 前置：U22, U23

**实际范围**

- `所有本轮差异`
- `reports/experience-v2/FINAL.md`
- `design/experience-v2/tasks.json`
- `README相关说明`

**实施**

1. 只读审阅者对照真实截图、代码、能力矩阵和证据检查，重点旧数据、查询/返回、签名、无障碍与未实测承诺。
2. 修复真实阻塞，每阶段可回退；有schema/备份变化需要说明数据后果，不谎称全部无迁移。
3. 按证据分FULL_VERIFIED / ENGINEERING_AND_LAYOUT_VERIFIED_DEVICE_PENDING / PARTIAL_BLOCKED；用户审美批准另列accepted_by_user，不自动代填。
4. 设备缺失可交付带明确缺口的包，但U23不能改为完成；若还有页面布局/代码没做，不能套用“只差设备”。

**证据**

最终diff、任务四维证据、截图/产物manifest、缺口、回退说明和具体下一步。

**完成标准**

交付证明改变了哪些用户任务和页面结构；不是用行数、token、时间或额度耗尽作为成功指标。

## C01 · 受控试验：0.30.2 → 1.7.2是否值得迁移

阶段：CONDITIONAL ｜ 前置：U02, U06

**实际范围**

- `pubspec.yaml`
- `pubspec.lock`
- `lib/shared/widgets/glass/`
- `test/glass/`

**实施**

1. 启动条件：已获可见样板，具体缺陷/新交互在旧包中实现成本明显，并允许一个独立可回退试验。先核对上游1.x迁移指南和实际本项目调用点。
2. 仅改同一个玻璃依赖，不联动升级Flutter/Riverpod/router/sqlite；把版本锁定在试验记录中。
3. 先迁移一个导航＋一个筛选弹层，检查API、语义、浅深色、reduce motion/transparency和稳定scope；上游skill不能覆盖项目首帧后准备/失败回退/Solid零采样。
4. 如需要await初始化阻塞首屏、重建整个router或引入第二套后端才能运行，则停止并记录不采用原因。
5. 光学/性能必须有真实renderer依据；仅headless通过时仍为待设备验证，不全站铺开新shader。

**证据**

调用点迁移表、独立lockfilediff、两组件前后图和测试；设备trace或明确缺席。

**完成标准**

只有净收益和兼容性成立才并入U20，否则保持0.30.2且主线继续；不得为版本新而强制升级。
