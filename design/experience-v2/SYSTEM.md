# U07–U10 · The system taken from the sample

Everything here comes from the U06 sample: first the pages were drawn, then the shared parts were extracted. Gallery renders: `visual/components/` (light, dark, ×1.3, ×2.0, dark ×2.0). Source: `test/visual/components_test.dart`.

## Tokens (U07)

| Role | Where | Value |
|---|---|---|
| Root title | `textTheme.headlineSmall` | 28 / w700 / 1.2; `RootHeading` wraps between space-separated parts only |
| Section title | `textTheme.titleLarge` | 19 / w700 / 1.3; `SectionHeading` (min 44 high, optional "see all" link) |
| Item / bar title | `titleMedium` / `titleSmall` | 15 / 14, w600 (unchanged) |
| Body / meta | `bodyMedium` / `bodySmall` | 14 / 12 (unchanged) |
| Page gutter | `AppTokens.gutter(width)` | 16 on phones, 24 from 600 |
| Gaps | `AppTokens.sectionGap` / `itemGap` | 28 / 12 |
| Artwork box | `AppTokens.artworkRatio` / `artworkRadius` | 4:5 / 12 (no image dimensions exist in the model, so one stable box) |
| Touch | `AppTokens.touchTarget` (session 01) | 48 on touch platforms, independent of the visual size |

Colours are unchanged. Diana pink stays the accent (the tab underline, selection, links, member bars) and never fills content. Button and quick-chip labels now inherit the theme's text style.

## Headers and insets (U08)

- **Root pages** (Today, 我的) have no floating bar. `RootHeading` is the first item of the scroll content, at the top safe inset + 16.
- **内容** keeps the floating `AppPageBar`. Its control is the channel `ChannelTabs`, which hides on scroll down and returns on scroll up, as before. The tabs are the page's title.
- **Child pages** keep the compact `AppPageBar` (16 / w600 + back).
- **Bottom:** only the shell adds the navigation's obstruction to `MediaQuery.padding.bottom`. Pages add their own 24 on top and never measure the bar themselves. There is still one authority for the bottom inset (unchanged, verified by `app_shell_material_test`).
- **Breakpoints (unchanged):** a bottom glass bar below 840 and the rail at 840 and above, with branch state kept. Today pairs columns once its content area is at least 840 × text scale. Renders at 320 / 390 / 600 / 840 / 1280 are in `visual/sample*`. The shell itself was not redesigned: the floating bar and rail already met the IA, and nothing about them is claimed as new.

## Query (U09)

`QuerySummary` is one line per channel, built from that channel's real fields (CAPABILITIES.md):

| Channel | Always visible | Named in the summary once set |
|---|---|---|
| 视频 | kind segments (全部/切片/录播), order/window menu | 最热; 一周内/一月内 |
| 二创 | search field, member strip, filter button with count | keyword, category, type, source, kind, sort |
| 动态 | search field, filter button | keyword, member, type, date range, sort |
| 小说 | search field, filter button; result count | keyword, scope, rating, each member, sort |

Each condition has a "移除" button, and 清空 clears all of them. The summary is absent at defaults, except for the novel count. The draft/apply/cancel panels are unchanged (tests: `fanart_filter_bar_test`, `sample_flows_test`, `query_summary_test`). There is no search field for videos.

## Presentation families (U10)

| Family | Widget | Shape |
|---|---|---|
| Work tile | `FanartCard` | Borderless 4:5 art (cover, top-anchored), 2 title lines, byline with author and members, more button; text works get a reading tile in the same box |
| Video unit | `VideoCard` | Borderless 16:9 cover (radius 10), 2 title lines, creator, views and date, more button; same fixed extent as before |
| Video line | `VideoRow` | 136 px cover and three text lines, for places where videos accompany other content (Today) |
| Agenda line | `CalendarAgendaRow` | Time (with day when needed), member bar, title and subtitle, state in words (直播/已取消/待定) |
| Library tile | Mine `_LibraryGrid` | Icon and label on a quiet surface |
| Reading item | `DynamicCard`, `_NovelCard` | Unchanged so far; U14 and U15 |

`MediaActionRegion` carries the shared interaction (tap, long-press, right-click, press-in, focus ring) without drawing a frame. `MediaCardSurface` stays for the families that still use it.
