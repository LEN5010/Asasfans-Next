# U06 · Three-screen sample (direction A), internal review

Code: `03c47db`. Renders: `visual/sample/` (42 files: all pages at this commit plus the flow steps). Before/after, grayscale: `visual/before-after-gray.png` (baseline vs sample for Today, 二创 and 我的).

**Status:** internal review only. `accepted_by_user: pending`. Nothing here has been seen or approved by the user.

## What changed structurally

| Screen | Before (baseline) | Sample |
|---|---|---|
| Today | A 16 px bar title; three equal modules; the schedule as two saturated pills; two identical horizontal shelves of bordered cards, cut off at the edge | A 28 px date title that is the page's identity; the agenda as quiet lines (time, member bar, state in words); two portrait artworks; clips as list lines; the archive last. Wide windows: time on the left, content on the right |
| 二创 | A segmented channel control, a search row, two pill rows (members, categories); letterboxed art in bordered 4:3 boxes; first item at 224 px | Text channel tabs as the title; search plus a filter with a count; one member row; applied conditions named and removable; borderless 4:5 tiles in a fixed-extent grid; first item at **175 px** |
| 我的 | A settings list: 5 content rows, then subscriptions, management, the whole preferences form, and app rows | The title, the library as 6 tiles, 最近浏览 (from the first history page, absent when empty), 管理, 应用 → 设置 / 工具 / 致谢 / 关于. Preferences moved to `/mine/settings` |

Other channels moved slightly because the tab row is 48 px: videos 126 → 135, dynamics 130 → 139, novels 158 → 167. All are still within the ~220 budget.

## Interactions (flow tests, real app, `test/visual/sample_flows_test.dart`)

1. **Filter.** Open the panel, pick 手书·动画 and apply. The summary shows "手书·动画 ×" and the button shows a count of 1. A second draft (物料) closed without applying changes nothing. Removing the one condition clears the summary. Steps: `flow-filter-1-draft`, `flow-filter-2-applied`.
2. **Detail and back.** Scroll 420 px, open an image work, then 返回. The grid offset is identical before and after (asserted). The visit appears in 我的 → 最近浏览. Steps: `flow-detail-1-open`, `flow-detail-2-back`, `flow-detail-3-mine-recent`.
3. **Save.** Long-press a tile and turn on 稍后看. The switch shows the result in the sheet where it happened (asserted persisted). Step: `flow-save-1-later-on`.

External B站 return in the new grid is covered by the existing handoff tests, which pass unchanged: identity anchor, fixed extent. Real system return is left to device testing (U23).

## Round 1 findings and what was done

| # | Finding (from the renders) | Action |
|---|---|---|
| 1 | Today tiles lacked member tags (DIRECTIONS problem 1) | The tile byline has an author line plus a member line |
| 2 | The summary showed defaults (problem 5) | Only non-default conditions show; the line is absent otherwise |
| 3 | The continue row costs space (problem 3) | Not shown until U19 provides a real snapshot |
| 4 | The member bar in agenda lines rendered 0 px wide | Fixed (the column stretches). Found in the render, not by a test |
| 5 | A history item with no image or body showed its title twice in 最近浏览 | Fixed (type icon); found by the new Mine test |
| 6 | Recent row overflowed by 2 px after a visit | Height now derived from the text scale |
| 7 | Text tile cut its last line in half | Line count fitted to the box |
| 8 | The content page still uses a 16 px inset while Today and Mine use 20 | Open, for U07 (one gutter token) |
| 9 | Long images show only their top in the tile, with no "长图" hint (no dimensions in the model) | Accepted. The detail shows the full image |

## Gate

Without the colour and glass, the new hierarchy is visible (grayscale sheet): the title, the section headings, then the content. The main actions are labelled (查看二创, 日历, 清空, 设置) or conventional icons with tooltips. No new backend or data was needed. **The internal gate passes for U07 onward.** User acceptance is still open.
