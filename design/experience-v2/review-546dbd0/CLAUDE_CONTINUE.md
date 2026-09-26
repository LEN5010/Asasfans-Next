# 继续 Experience V2 的工作目标

请以仓库当前 `claude/zen-babbage-ll6g3y` 的实际 HEAD 为起点，先记录它与审阅基线 `546dbd046f221e6ab1b9ef2f51b1b20ee30fed76` 的差异。不得硬重置或覆盖之后的用户修改。

阅读本包 REVIEW.md、FOLLOWUP_TASKS.md，以及仓库 reports/experience-v2/FINAL.md、design/experience-v2/TASKS.md 与 ACCEPTANCE.md。

方向：继续 A「内容刊」，不重新选型、不再搜一大批优秀App、不重写底层。该方向是本次审阅建议，不是用户已签字接受；accepted_by_user 仍保持 pending，除非用户另有明确指令。

首先针对下面三个问题写能失败的测试，并按实际结果修复：
1. 二创图片/文字从带筛选列表进入详情，再打开原动态时，origin/query/anchor没有传给handoff，默认变成Today。
2. QuerySummary长keyword/长无断点字符串内部Row缺少宽度约束，以及“清空”范围歧义。
3. 所有fanart包括视频都4:5 cover，以及首张长图详情把作者/正文推得过远。测试媒体要包含边缘文字，不只用渐变圆点。

随后按FOLLOWUP_TASKS完成有界收口：媒体布局与decode同步、恢复请求token/generation（先验证风险，不伪造复现）、署名触摸目标/窄屏视频行/大字标签/日历控件收敛、U18状态与工具、U20必要交互。

缺Android SDK或手机不是停止U18/U20代码和headless布局的理由。可在Solid实现行为、结构和减少动态测试；真实玻璃和GPU只能待设备验证。不要把现有默认路由动画当作新的详情连续性，也不要把写PNG当作像素回归。

保持4个主导航、所有已有路由、保存数据、内容规则、备份、query generation、外跳、返回、arm64/armv7以及有效档回退。不得加播放器/账号/同步/推送后端，不升级SDK/Riverpod/router/sqlite，不引入第二套玻璃库，不为视觉探测批量下载原图，不把系统字体或大型fixture放进正式包。

只由一个主agent写代码；其他agent如使用仅做只读审阅。先跑受影响测试，再阶段全测。每个工作包写实际变更、命令、退出码、对应截图、缺口和可回退提交。继承测试应保留业务断言，必要布局改写要说明；不得扩大阈值、随意skip或自动覆盖所有golden来涂绿。

不自动推送、开PR、触发CI、发布、签正式包或开启付费服务。仅在用户明确授权后执行对应远程动作。未授权时输出准确的待运行CI分支/参数：Flutter Checks需要run_tests=true；性能工作流使用隔离perf包与批准的测试签名。

完成时分别给CODE、LAYOUT、DESIGN、DEVICE证据。所有代码/页面/本地布局及可执行构建完成后，才可说“只差设备”；仍有任何未做主线则PARTIAL_BLOCKED并逐项解释。不能将用户的审美验收自行设置通过。提供正确的阶段级逆依赖回退路径，不宣称所有提交能任意无序revert。
