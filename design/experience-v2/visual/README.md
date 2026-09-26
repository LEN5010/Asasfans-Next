# Visual evidence

Every PNG here is an **actual widget render**: the real app, rendered headlessly by `flutter_tester` from the offline fixture (`test/visual/visual_fixture.dart`). The glass material is Solid in all of them, because the tester has no shader filters. None of them is a device screenshot, a mock-up or a generated image. The `manifest.json` in each folder records the commit, fixture revision, viewport, pixel ratio, text scale, brightness, renderer and fonts for every file.

| Folder | What | Command |
|---|---|---|
| `baseline/` | The pages as of `7134a40` (the commit column reads `909b4c1`, which adds only the harness and the label-font fix) | `tool/visual_capture.sh design/experience-v2/visual/baseline` |

Rerun: `ASASFANS_FLUTTER_SDK=… tool/visual_capture.sh <dir> [test files]`. This needs a CJK font on the machine, or `ASASFANS_CJK_FONT=<path>`. Without one the tests still run but write nothing. `python3 tool/visual_sheet.py out.png a.png b.png [--gray]` makes a side-by-side review sheet (needs Pillow).

## Baseline observations (internal review, not user research)

Measured first-item top on a 390 × 844 phone (logical px from the window top, `first_item_top` in the manifest): videos 126, dynamics 130, novels 158, **fanart 224**. Fanart spends its first 224 px on the channel strip, a search row and two chip rows. The ~220 px budget in ACCEPTANCE §4 is therefore already met by every channel except fanart, and only just missed there. The real problem is how that space is used, not the amount.

- **Today**: a 16 px page-bar title ("今日 · 9 月 26 日"), then three stacked modules of equal weight. The schedule is two saturated full-width member-colour pills. Clips and fanart are two identical horizontal shelves of bordered cards, each labelled "最新…/更多". The shelves are cut off at the right edge on a phone. Nothing tells the user what matters today. The archive module sits below the fold.
- **Content**: the channel strip, a search field, and two rows of same-shaped pills (members, categories) are all rounded, pink-selected and of equal visual weight. Navigation, query and filter are hard to tell apart.
- **Fanart cards**: artwork sits letterboxed (`contain`) in a white bordered card at a fixed 4:3 cover. A portrait piece fills about half the box width. The text work is a card with no image, just a block of text. The long strip image shows as a thin sliver. The cards read like video thumbnails.
- **Videos**: dense and orderly (fixed extent, 16:9). The grid is the strongest existing page; its caption rows are loose.
- **Mine**: a settings list. Personal content ("我的内容") has the same visual weight as management rows, and on a phone the whole preferences form follows on the same page.
- **Calendar**: a month grid first, then the agenda. On a phone the day's agenda starts about 300 px down.
- **Dynamics / reader**: already read well. The reader's typography is the best in the app, and dynamics are a reasonable reading column in cards.
- **Wide (1280)**: pages stretch cards in fixed columns. Mine has a three-level rail (app rail → section list → content), and Today pairs schedule and archive side by side.
- **Dark**: a straight inversion of the light theme. The member-colour schedule pills stay saturated.

## Later folders

| Folder | What |
|---|---|
| `directions/` | U05 prototypes (provenance `prototype`), plus `directions-gray.png` and `directions-dark.png` |
| `sample/` | U06 at `03c47db`: every page after the direction-A sample, plus the flow steps (`flow-*`) and the settings page |
| `before-after-gray.png` | Baseline vs sample in grayscale: Today, 二创, 我的 |
| `final/` | U07–U24 at `aa04831` (90 renders); kept as the record of that commit |
| `v2.1/` | V2.1 follow-up at `9473f4a` (111 renders): every page, the flows, the stress matrix, and the new `diag-*` (edge-banded art), `state-*` (U18), `motion-*` (U20), `*-end`/`*-keyboard` (system bars and keyboard) scenes. PNGs are losslessly re-compressed |
| `v2.1-overview.png` | Six pages at `9473f4a` |
| `v2.1-vs-aa04831.png` | 二创, 日历 and 我的: `aa04831` then `9473f4a`, in pairs |
| `v2.1-diagnostics.png` | Edge-banded art in the grid and the detail (long strip capped, portrait whole), the stale and filtered-empty states, and the arrival tint |

Diagnostic art is drawn by the harness (`Visual._diagnostic`): red left, blue right, green top and yellow bottom bands, plus edge labels. `media_geometry_test` samples those bands in the rendered pixels in ordinary test runs, so a crop that loses an edge fails a test. A written PNG on its own proves nothing about regressions. The geometry and pixel checks are `media_geometry_test`, `touch_polish_test`, `layout_contract_test` and `motion_test`. No PNG is compared against an approved golden: the CJK face is a system font loaded at test time, so pixel goldens would depend on the machine.

