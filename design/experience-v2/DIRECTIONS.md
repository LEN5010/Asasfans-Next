# U05 · Three directions, one choice

Six prototype screens (Today and 二创 for each of A, B and C) plus dark variants. They were rendered from the same fixture, at the same 390 × 844 size and text scale, with the real theme, image policy and navigation bar: `visual/directions/` (manifest `provenance: prototype`). The sheets `visual/directions-gray.png` and `visual/directions-dark.png` put them side by side. The source is under `test/visual/directions/` and never ships.

**This is an internal choice, not a user decision.** `accepted_by_user` stays `pending`.

## What differs structurally (not colour or radius)

| | A 内容刊 | B 内容工作台 | C 作品展廊 |
|---|---|---|---|
| Today, first screen | A 28 px date title, a compact 3-row agenda with a member bar and text status, the continue row, then two 4:5 artworks | A 20 px title, grouped white lists (日程 4 项, 进行中, 最新二创 8 件, 最新切片) with small thumbnails | A full-bleed lead artwork with the date overlaid, one line of schedule, then a horizontal wall of large tiles |
| Where the schedule sits | Second block, all of the next 3 visible | First group, 4 rows | One line below the artwork |
| 二创 structure | Root title, text tabs, scoped search plus filter, one summary line, a 2-column grid of borderless 4:5 tiles with title and author | Segmented channel, search plus sort, four removable condition tokens, a list of 82 px thumbnails with three text lines | Text tabs, then an edge-to-edge 2-column wall with no captions; search and filters behind one button |
| First fanart item top (390) | **194** | 206 | 62 |
| Baseline for comparison | 224 | | |

## Decision table (internal judgement on the renders)

| Criterion | A | B | C |
|---|---|---|---|
| Content recognition | Artworks are large enough to tell apart; the title and author show without a tap | Thumbnails at 52–82 px are too small for artwork; text dominates | Strongest art presence, but author and title are hidden until a tap |
| Task steps (schedule → open; search; filter) | Schedule is 1 tap; search is inline; filter is 1 tap plus a draft panel | Same steps. Tokens show every condition, even defaults ("成员：全部") | Schedule is 1 tap but shows only one event; search costs one extra tap |
| Hierarchy (grayscale sheet) | Clear: title > section headings > items; the three layers read differently | Flat: every group has the same weight, like the current 我的 settings list | Strong on the hero, then a flat wall; the date competes with the image |
| Brand expression | Pink only as accent (tab underline, member bars, filter); the art carries the page | Little; reads like a tool | Strong, but it is the hero pattern REFERENCES rejects (content pushed below the fold) |
| Accessibility / large text | Rows grow naturally; the grid extent comes from the text scale | Dense rows risk truncation at ×2.0 | Overlaid white text on artwork has uncontrolled contrast; captionless tiles lack text |
| Implementation cost and low-end budget | Reuses the fixed-extent grid and the existing queries; decode widths ~173 × 2 px | Cheapest (lists), but the least visible change | Largest decodes (full-width lead ≈ 780 px, 225 px shelf tiles); new floating control |

**Chosen: A.** It meets the content budget (194 ≤ 220 without shrinking text or targets), keeps every capability visible at the right layer, and changes the page structure rather than its paint. B is the current app made denser, and C gives up the schedule and captions for an image wall.

## What A takes from the others (no averaging)

None of the B or C structure goes into A. Two specific ideas carry over. From B: counts in section headings where they are real data (for example "8 件已加载"). From C: the text work as a quiet reading tile (A already has it). The continue row and the member colour bar stay in A only.

## Known problems in A to fix in U06 (round 1)

1. The Today artworks drop the member tags. Put them back in the author line, as they help people pick.
2. The long image crops to its top. Keep that, but make sure the "长图" badge sits where the detail opens the whole image.
3. The continue row costs about 60 px on the first screen. Show it only with a real snapshot (U19). The fixture shows it on purpose.
4. The filter button is a filled pink circle that competes with the tab underline. Use a tonal square with a count badge instead.
5. The summary line shows the defaults ("全部成员 · 全部分类 · 最新"). Show only non-default conditions plus the sort, and hide the line when nothing is applied.
