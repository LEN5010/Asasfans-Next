# Information architecture and copy contract (U04)

All three directions in U05 follow this contract. None of them may win by dropping a capability.

## Layers

| Layer | Items | Visual grammar (V2) | Behaviour kept |
|---|---|---|---|
| Destination | 今日 · 内容 · 日历 · 我的 (+ 工具 as an action) | Bottom glass bar on phones; rail at ≥ 840 | go_router branches keep their stacks, queries and scroll. Tools stay a sheet, never a 5th branch |
| Channel | 视频 · 二创 · 动态 · 小说 | Text tabs: selected is bold with an accent underline, unselected is secondary text. No filled pill | One `ContentPage`. Only 2 channels stay mounted. Old slugs redirect |
| Condition | Per channel, see CAPABILITIES.md | One summary line ("嘉然 · 绘画 · 最新" + 清空), plus at most one quick row where it earns its place, plus the draft panel | Draft/apply/cancel, saved queries, generation-safe loading |
| Content action | 收藏 · 稍后看 · 查看来源 · 屏蔽 | Trailing "更多" at 48 dp, long-press, right-click | `showContentActions` |
| Setting | Appearance, glass, home modules, rules, backup, subscriptions | Reached from 我的 → 设置 or 管理 rows, never inline on the Mine root (U17) | All `/mine/*` paths stay valid |

## Flows (text diagram)

```
今日 ──next event──▶ 日历 (selected day)
  │ ──work tile──▶ 作品详情 ──back──▶ 今日 (same scroll)
  │ ──查看二创──▶ 内容/二创
  └ ──继续挑选 (U19, optional)──▶ 内容/<channel>?query → anchor
内容/视频 ──card──▶ B站 (external) ──return entry / system back──▶ 内容/视频 + query + anchor
内容/二创 ──filter button──▶ draft panel ──应用──▶ summary updates
           ──tile──▶ 作品详情 ──image──▶ 查看器 (original)
我的 ──收藏/稍后看/记录/书签──▶ library pages
     ──设置──▶ preferences page (new route /mine/settings, U17)
     ──管理──▶ rules / subscriptions / backup / calendar follows / updates
```

## Copy table

| Where | Use | Never |
|---|---|---|
| Today content modules | "最新二创", "最新切片" (the providers fetch newest first) | "精选", "推荐", "热门" |
| Today next-event | "接下来" plus the time, or "今天 20:00" | "即将提醒你" |
| Video order | "最新", "最热" (the source's score) | "推荐" |
| Fanart text work | "文字作品" | a fake cover |
| 继续观看 (existing) | "继续观看" means the local records of opened videos | "播放进度" |
| 继续挑选 (new) | "继续挑选 · <channel> / <conditions>" | "继续播放" |
| Updates | "应用内更新" (collected when the app runs) | "通知已开启", "实时提醒" |
| Hand-off | "在 B站观看 ↗", "去 B 站看 ↗" | "播放" |
| Mine header | "我的内容" | avatar, nickname, login, sync status |

## Old-path compatibility checklist (tests that must keep passing)

- `/content/clips` → videos with kind=clips (`test/content/content_page_test.dart`)
- `/mine/rules`, `/mine/backup`, `/mine/saved/:folder`, `/mine/continue` and the others are reachable from Mine (`test/app_shell_test.dart`, `test/mine/mine_page_test.dart`)
- Tools reachable from the nav button, the rail and Mine (`test/app_shell_test.dart`, `test/mine/mine_page_test.dart`)
- Return restore per channel (`test/handoff/return_*`)
- A new `/mine/settings` route is added, and the preferences stay reachable through it; the old Mine-root preference controls move there (U17)
