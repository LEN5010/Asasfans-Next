# Asasfans Experience V2 — 审阅与设计执行包

审阅日期：2026-09-26。旧计划基线`98e52c291f7aa94d8344f43ec6df0a9fd52cff27`，当前审阅基线`7134a40cb6579d9d5831f76a9859a6c2196855ef`。

**结论：本轮有实质工程改善，但UI重设计远未完成。下一轮采用设计先行、三屏样板闸门与独立设备验收，不再从统一旧卡片包装开始。**

本包是计划与审阅，不包含已经实施的新UI、应用截图、已运行的Flutter测试或真机结果。实际执行过的是两个已取得Debug APK的字节/hash统计、其嵌入原始Dart源码的索引/比较，以及GitHub代码与CI读取。当前检查CI跳过测试；仓库709通过是前一执行会话报告。

## 文件入口

| 文件 | 用途 |
|---|---|
| [REVIEW.md](REVIEW.md) | 本轮完成度、真实CI/包体、未完成事项与32任务交叉审阅 |
| [PLAN.md](PLAN.md) | 新方向、逐页规格、材料/交互/性能边界和执行方法 |
| [REFERENCES.md](REFERENCES.md) | 一手来源、借鉴模式、不抄部分与版本注意事项 |
| [TASKS.md](TASKS.md) | U01–U24与C01条件试验的范围、任务和完成标准 |
| [tasks.json](tasks.json) | 机器可读依赖与证据账本；初始均not_started |
| [ACCEPTANCE.md](ACCEPTANCE.md) | 视觉、输入、数据、构建、设备验收与最终状态 |
| [GOAL_PROMPT.md](GOAL_PROMPT.md) | 下一轮Claude工作目标正文 |
| [evidence/](evidence/) | 实际APK比较、源码hash索引、CI观察、旧任务交叉表 |

## 使用

将本包放进工作区可版本管理的位置，例如`design/experience-v2/`，先核对`.gitignore`。本仓库原`docs/`目录被忽略，不能只把新计划放那里然后认为协作者能读取。不要覆盖根CLAUDE.md或用户未提交的修改；执行前以实际HEAD与本基线比较。

本包建议新增的文件/组件是实施建议，不冒充现有API。原型需要在下一轮用真实widget和fixture生成；没有生成任何假装已完成的界面图。条件升级1.7.2不阻塞Solid布局主线。

## 证据文件

- [apk-comparison.json](evidence/apk-comparison.json)：原始APK大小、SHA256与内部各项；不是外层artifact ZIP。
- [source-comparison.json](evidence/source-comparison.json)：170份当前runtime Dart源码与基线166份的路径/行数/blob hash变化。索引覆盖不等于所有文件逐行人工审查。
- [ci-observations.json](evidence/ci-observations.json)：读取到的最新4平台开发build与checks步骤。
- [old-task-crosswalk.json](evidence/old-task-crosswalk.json)：仓库自报状态与本次审阅解释。

证据未包含APK、完整仓库源码、任何字体、密钥或用户生产数据，避免不必要的大型分发。所有源码链接固定当前审计commit，商业/库文档注明检索日期与使用边界。
