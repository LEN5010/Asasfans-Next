# Pattern cards (U03)

Twelve cards for the "今日 → 发现 → B站 → 返回 → 收藏" journeys. Sources were read on 2026-09-26 from this environment.

**Read:** Apple WWDC25 219, WWDC26 251 and 292, Meet with Apple 255 (Slack) and 257 (Tide Guide), all via developer.apple.com; the liquid_glass_widgets changelog on pub.dev.
**Blocked by the egress proxy:** blog.pocketcasts.com, flexibits.com, culturedcode.com. The cards drawing on those sources (A4, A7, A8) rely on the REFERENCES.md summary and are marked *not re-verified*.
**Not read:** the PiliPlus and LoveIwara sources. They are outside this session's repository scope, so A9/A10 are named from REFERENCES.md only and no code was taken from them.

No app here was run or tested. These are document and video studies.

Every card records the problem it solves, the source, the enter → change → exit sequence, what to take, what not to take, where it lands in Asasfans (with real fields from CAPABILITIES.md), and the acceptance check.

---

**R01 · Editorial root title**
Source: A2 (WWDC26 251: brand lives in the content layer; custom type for headers and key displays; keep navigation familiar).
Task: open the app and know what day it is and what is on.
Enter → change → exit: the root page shows the date and a short line as a large title. The title scrolls away with the content; the compact bar returns on scroll up.
Take: a root-only display title (28–30), the date as identity, a quiet greeting line.
Don't take: logos in the bar, custom navigation components, a hero banner.
Asasfans: Today (`shanghaiDateProvider`), plus the Content/Calendar/Mine roots with a smaller variant. Child pages keep the compact 16/600 bar with a back button.
Check: at 390 × 844 the date and first real item fit in the first ~300 px. At 2.0 text scale the title wraps and is not clipped.

**R02 · Image-led work presentation**
Source: A2 (full-bleed imagery in the content layer); PLAN §5 family "作品单元".
Task: tell artworks apart quickly and see who made them.
Enter → change → exit: artwork fills its tile with no card frame. The author line sits under it; tapping opens the detail on the same identity.
Take: a borderless image tile on a subtle surface, a stable portrait box (4:5), `cover` for single images with a fixed ratio, and text works as a quote-like tile.
Don't take: natural-ratio masonry (no dimensions in `FanartItem`), overlaying all metadata on the image, 16:9 video framing for artworks.
Asasfans: `FanartCard` (images, contentType, authorName, characterTags, images.length).
Check: no letterboxing on portrait or landscape in the grid. The long strip shows its top part cropped plus a "长图" badge. The text work reads as text.

**R03 · Secondary actions near the content, never on the title**
Source: A9 (PiliPlus VideoCardV layering; not re-read), A2 (utilitarian functions stay standard).
Task: save or hide an item without opening it.
Enter → change → exit: long-press, right-click or the trailing "更多" opens the standard content action sheet. Its result shows in place (R10).
Take: one trailing 48 dp more button aligned with the meta line, not the title. Long-press and secondary-tap equivalents.
Don't take: PiliPlus's 29 px button, per-card action rows, per-card glass.
Asasfans: `showContentActions` on every card family.
Check: the hit rectangle is ≥ 48 dp and does not overlap the card's main tap target in semantics.

**R04 · Date strip linked to an agenda**
Source: A8 (Fantastical DayTicker; *not re-verified*, flexibits.com blocked), A7 (Things date headings; *not re-verified*).
Task: find the next event and what is on a given day.
Enter → change → exit: a horizontal week strip shows today selected. Tapping a day scrolls or filters the agenda below. The month grid opens on demand.
Take: a compact 7-day strip with event dots and text status for cancellations and reschedules. The agenda is grouped by day heading.
Don't take: third-party accounts, weather, event creation.
Asasfans: Calendar (`CalendarEvent` status/sequence, `selectedCalendarDayProvider`). Today reuses the "next event" row.
Check: the selected day survives switching between agenda and month. Cancelled items read "已取消" without relying on colour.

**R05 · One accessory for an ongoing task above navigation**
Source: A4 (Pocket Casts tab-bar accessory; *not re-verified*, blog blocked), A1 (glass only in the navigation layer).
Task: pick up browsing where it stopped.
Enter → change → exit: after a hand-off, a slim "继续挑选 · 二创 / 嘉然 / 绘画" row appears once, on Today. Tapping it restores the channel, query and anchor; it can be dismissed.
Take: a single optional row, placed in the Today slot and never floating over content.
Don't take: a mini player, a queue, or several stacked bottom bars.
Asasfans: U19 snapshot (channel, query, identity, time), kept separate from the one-shot `ReturnContext`.
Check: no row without a snapshot. A dismissed row stays gone for that snapshot. A consumed return is never replayed.

**R06 · Search scope matches placement**
Source: A3 (WWDC26 292: scoped search sits inline under the title, and the placeholder states the scope; no global search tab unless it searches everything).
Task: search the channel the user is in.
Enter → change → exit: the channel's own search field has a scoped placeholder ("搜索二创正文或作者"). Results replace the list, and the summary shows the query.
Take: inline scoped fields only where the repository accepts `keyword` (fanart, dynamics, novels). The empty state echoes the search text.
Don't take: a search tab, or a search field for videos.
Asasfans: `FanartQuery.keyword`, `DynamicQuery.keyword`, `NovelQuery.keyword` + scope.
Check: the video page has no text field. Each placeholder names its channel.

**R07 · Draft filter panel for continuous adjustment**
Source: A5 (Tide Guide: a popover stays open while options are adjusted, can go deeper, and collapses back to its origin).
Task: combine members, category and type in one go.
Enter → change → exit: the filter button opens a panel holding a draft copy of the query. Several changes happen without closing it. "应用" commits once; closing without applying changes nothing.
Take: the existing draft/apply panel (already present for fanart, dynamics and novels) with a count on the button. On close, focus returns to the button.
Don't take: permanent full chip walls, or menus that close on every tap.
Asasfans: `_FilterPanel` (fanart), dynamic and novel panels.
Check: the cancel/apply test (already exists for fanart) holds for each channel.

**R08 · Navigation, channel and conditions look different**
Source: A1 (small navigation elements vs content), A3 (scope bars reinforce where the user is).
Task: always know which of "where am I", "what kind", "which subset" is being changed.
Enter → change → exit: the main nav is the bottom glass bar or rail. The channel is a text tab row (underline or weight, no filled pills). Conditions are one quiet summary line with removable items, and the panel holds the rest.
Take: three distinct visual grammars.
Don't take: three stacked rows of identical pink pills.
Asasfans: `_ChannelStrip`, `FanartQuickFilters`, `FanartFilterBar`.
Check: in a grayscale sheet the three layers are still distinguishable.

**R09 · Identity-driven return**
Source: session-01 T10 implementation; A6 (prototype the real path).
Task: come back from B站 to the same item.
Enter → change → exit: tapping an item records the channel, query and identity. On return the list scrolls until that identity is visible, within a bounded page budget; otherwise a notice appears.
Take: the existing `restoreAnchor` with the new layout's real item extents, and the anchor kept clear of the top bar and bottom nav.
Asasfans: `ReturnAnchor`, `restoreAnchor`.
Check: existing handoff tests still pass after the card changes. The anchor ends up inside the unobstructed viewport.

**R10 · In-place feedback after save**
Source: A2 (interactions as brand; feedback where it happens).
Task: save to favourites or watch-later and know it worked.
Enter → change → exit: the action sheet closes, and a short snackbar names the result with an undo or "查看" where the repository supports it. On failure it says why and offers a retry.
Take: result-specific text ("已加入稍后看").
Don't take: long celebratory animations.
Asasfans: `showContentActions` (library repository).
Check: a success and a failure path are each visible in a screenshot or test.

**R11 · Wide master–detail, not stretched phone cards**
Source: A8 (*not re-verified*), A6.
Task: use the extra width on desktop and tablet.
Enter → change → exit: at ≥ 840 wide, Calendar shows dates on the left and the agenda on the right. Mine shows sections on the left and content on the right. Today uses two columns: time on the left, content on the right. Reading columns stay at ≤ 720.
Take: capped grid columns, a capped reading width, and the rail.
Don't take: three columns at 840.
Check: the 840 and 1280 screenshots contain no card wider than ~420 in the grids and no line longer than ~40 CJK characters.

**R12 · Same geometry in every material and appearance**
Source: A1 (Regular vs Clear; accessibility settings applied automatically), ACCEPTANCE §4 material.
Task: switch glass, dark mode or large text and keep the same page.
Enter → change → exit: changing the preference swaps the fills only; layout, focus and scroll position stay.
Take: geometry independent of the material, and Solid samples no backdrop.
Asasfans: `AppGlassScope`, `GlassTier`.
Check: Solid vs glass geometry equality is covered by an existing test (`app_shell_material_test`). The light/dark/×2.0 renders keep the same structure.

## Rejected patterns

| Pattern | Why rejected |
|---|---|
| Decorative hero that pushes content below the fold | Today would show one banner instead of what is on |
| Whole-page pill chips as the main control language | The baseline's main problem (see visual/README) |
| Global or video keyword search | No `keyword` in `CommunityVideoQuery`; A3 says scope must match results |
| Glass on every card or list row | A1: glass belongs in the navigation layer; it costs GPU on old phones |
| Mini player or queue to imitate A4 | The app hands playback to B站; no player dependency |
| "精选 / 推荐" badges | No editorial or recommendation data exists |
| Natural-ratio masonry | No image dimensions in the model; loading originals to measure them costs memory |
| Upgrading to liquid_glass_widgets 1.x for the redesign | The 1.x changelog removes `GlassBottomBar` and `LiquidGlassScope.stack`, and changes initialization and accessibility handling. C01 only runs after the sample, if a concrete gap needs it |
