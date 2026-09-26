# 参考库：提取模式，不收集一堆“好看截图”

检索日期：2026-09-26。Apple 与商业应用来自官方产品/设计说明；开源项目只声明实际检视的文件，未声称完整运行这些应用。图片搜索返回的旧版界面只能用作结构历史参考，不能称为当前 Liquid Glass 截图。

## 来源与转译

| ID | 一手来源 | 提取原则 | 本项目使用 | 明确不抄 |
|---|---|---|---|---|
| A1 | [Apple · Meet Liquid Glass / WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/) | 功能导航层、材料层次、内容不与玻璃争夺注意力。 | 用于底栏、少量页面操作区；列表卡片不逐个折射。 | 把原生 iOS 的自动适配当成 Flutter 包也自动具备；到处玻璃。 |
| A2 | [Apple · Communicate your brand identity on iOS / WWDC26](https://developer.apple.com/videos/play/wwdc2026/251/) | 平台熟悉感与品牌表达可以分开；内容层可以承载身份。 | 嘉然粉色、作品、日期叙事与文案承担品牌；返回、焦点、导航行为保持熟悉。 | 把所有按钮做成同色特殊造型，或照搬整套 Apple 应用。 |
| A3 | [Apple · Design intuitive search experiences / WWDC26](https://developer.apple.com/videos/play/wwdc2026/292/) | 搜索的范围与放置位置必须一致。 | 按各 repository 已有查询能力呈现搜索/筛选，不造一个不能兑现的全局搜索。 | 看到 Apple 搜索 tab 就给本项目添加第五主导航。 |
| A4 | [Pocket Casts · Liquid Glass / iOS 8.13, 2026-06-11](https://blog.pocketcasts.com/2026/06/11/liquid-glass/) | 导航附属区承载持续任务；选择状态优先安排底部空间。 | 将“继续挑选”做成可关闭的上下文入口，而不是另开播放器。 | 复制播放器、队列、付费体系；让多个底部浮层同时竞争。 |
| A5 | [Tide Guide · Liquid Glass showcase](https://developer.apple.com/videos/play/meet-with-apple/257/) | 连续调整选项时，反复关闭的多级菜单会打断任务。 | 筛选采用不因一次选择就关闭的有状态面板，提交一次、取消无副作用。 | 把所有筛选永久摊开，或把多级菜单换成更长的巨型菜单。 |
| A6 | [Slack · Liquid Glass showcase](https://developer.apple.com/videos/play/meet-with-apple/255/) | 比较真实原型，并允许否决漂亮但不适合内容的头部样式。 | 同一 fixture 比较三种结构，先做高频三屏，再规模化迁移。 | 把“加玻璃”当成产品目标，或把原型试验写成已验证用户偏好。 |
| A7 | [Things · 官方功能说明](https://culturedcode.com/things/features/) | 标题、分组与就近操作帮助浏览和组织内容。 | 今日与日历用清楚的时间分组和排版，不把每条信息装进同样的大卡片。 | 照搬任务创建、自然语言解析、同步和提醒系统。 |
| A8 | [Fantastical · 官方产品说明](https://flexibits.com/fantastical) | 日期导航与不同细节密度的日历视图。 | 窄屏日期条联动议程，宽屏日期面板与议程并列。 | 复制完整个人日历生态、天气、会议安排和第三方账号。 |
| A9 | [PiliPlus · VideoCardV 源码](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/a30fcc31043e10cd38c198f47ddd7b23fd6e6163/lib/common/widgets/video_card/video_card_v.dart) | 垂直视频卡将封面、时长、标题、元信息和次操作分层。 | 借鉴视频信息密度；元字段只显示本项目真实已有值。 | 复制播放器、网络层或它的 29px 更多按钮；不能继承不合适的触摸目标。 |
| A10 | [LoveIwara · glass 材料与就近菜单](https://github.com/FoxSensei001/LoveIwara/blob/94d0f0a438115428531722349eb0f6e258f7bd7e/lib/app/ui/widgets/glass/liquid_glass_material.dart) | 页面、菜单与弹层统一材料入口；菜单关注触发位置。 | 在项目现有 AppGlassScope/AppPanel 边界内保持一致，并审查返回与焦点。 | 搬入两套玻璃后端、账号/播放器架构；把它的性能注释当成本项目测试。 |
| F1 | [Flutter · matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html) | 实际 widget 可以进行像素快照比较。 | 无设备时先验证 Solid 布局；真实玻璃和 GPU 性能另做设备验收。 | 将 golden 通过等同审美通过，或拿 fallback 截图充当真实玻璃。 |
| F2 | [Flutter · performance best practices](https://docs.flutter.dev/perf/best-practices) | 关注构建范围与昂贵合成操作。 | 避免为视觉给每张卡添加背景采样；逐项进行同条件前后比较。 | 仅靠 const、缓存上限或一个质量枚举就宣布流畅。 |
| F3 | [liquid_glass_widgets · 1.7.2 变更记录](https://pub.dev/packages/liquid_glass_widgets/changelog) | 1.x 导航/交互与无障碍 API 有变化；0.30.2 不能直接套用新示例。 | 安排有界升级试验，成功才迁移同一个依赖。 | 直接升级所有依赖，或把库的性能声明当成老手机结果。 |
| F4 | [liquid_glass_widgets · 0.x→1.0 迁移指南](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/docs/MIGRATION_0.x_TO_1.0.md) | 破坏性 API 调整有明确迁移说明。 | 逐个核对当前真实调用点，固定试验版本与 lockfile。 | 看到新名字就重写 router、存储或所有页面。 |
| F5 | [liquid_glass_widgets · 上游 Agent Guide](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/skills/liquid-glass-widgets/SKILL.md) | 提供版本相关组件词典和使用约束。 | 只把核实过且适合项目的 API 规则纳入本地参考。 | 让上游 skill 覆盖本项目的首帧、Solid 保底、状态稳定和性能预算。 |

## 每张模式卡必须包含

```text
ID / 来源 URL / 版本、日期或 commit
场景：用户在做什么，不只是这一页叫什么
入口 → 状态变化 → 退出或返回
解决的问题
可借鉴的结构 / 行为 / 动效
不适用部分与平台差异
Asasfans 对应页面、组件与已有数据字段
验收任务、截图状态与预算
```

首批上限：8 组应用/设计来源（Apple 合并为一组）与 24 张模式卡。超出必须说明新增问题；不为丰富资料而无限扩展。先写 12 张与“今日—发现—B 站—返回—收藏”相关的卡，达到可执行程度后再补其他页。

## 第一批建议模式

R01 根页的编辑式标题；R02 图像主导的作品展示；R03 次操作贴近内容而不盖住标题；R04 日期条与议程联动；R05 导航附属持续任务；R06 搜索作用域；R07 草稿筛选的连续调整；R08 分离主导航/频道/条件；R09 内容身份驱动返回；R10 收藏后的就地反馈；R11 宽屏主从布局；R12 浅深色与无障碍下的相同几何。

这些是新计划提出的模式标签，不是某个参考 App 官方命名。

## 研究与实现的边界

参考 UI 的组织方法，不复制商业素材或品牌标识，不打包系统字体。复用开源代码前核对相关文件许可证及分发义务；默认采用独立实现。当前已有 LoveIwara 的 attribution 不因改造而删除。不要将 SF 字体或平台受限符号资源移植分发到 Android。

## 版本陷阱

本项目锁定 0.30.2；检索到的包版本是 1.7.2，其 pubspec 声明 Flutter >=3.41.0、Dart >=3.5.0 <4.0.0。与项目 SDK 的版本范围看似相容，不代表运行兼容性已经验证。上游 Agent Guide 的部分建议（例如启动前等待初始化、Scaffold 统一替换、minimal 档仍用 BackdropFilter）不能不加判断地覆盖本项目约束。升级试验必须保留失败回退、不采样 Solid 档与路由状态，不能把“有官方 skill”当成安全证明。
