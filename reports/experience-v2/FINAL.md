# Experience V2: final report

```text
Status: PARTIAL_BLOCKED
Baseline → candidate: 7134a40 → 227aa75 (branch claude/zen-babbage-ll6g3y)
  V2 at aa04831; V2.1 follow-up (review package 546dbd0) at 2d057dc…227aa75
User acceptance: pending (nothing here has been reviewed by the user)
```

## V2.1: acting on the review of 546dbd0

The review package is copied to `design/experience-v2/review-546dbd0/`. Direction A stays. For each work package, the failure it names was tested first; the before-runs are in `reports/experience-v2/v2.1/`.

| Package | Result | Evidence |
|---|---|---|
| R01 detail origin | An image or text work opened into its detail now carries the list's channel, query and anchor to 打开原动态. Before, the stored return was Today, and a cold start landed on `/today` | `fanart_detail_origin_test`; before-run in `r01-r02-before.txt` |
| R02 summary line | Chips are bounded and ellipsised, with the full value in the tooltip. More than three conditions fold to two plus "另 N 项". The clear buttons name their scope: 清除条件 keeps the members, while the empty state's 清除全部条件 clears them too. The overflow before was up to 3122 px | `query_summary_test` at 320/390 × 1x/2x |
| R03 media | Video works keep their whole 16:9 cover, and every type still fills one extent. Cover boxes decode to fill their height (`CoverDecodeImage`, within the pixel budget, no probing downloads). The detail caps only long art (≥ 1.4× a 55% viewport cap) and offers 看完整长图 | `media_geometry_test` samples the edge bands in rendered pixels; before-run in `r03-before.txt` |
| R04 继续挑选 | Each resume is one request id, cancelled only by its own id. Each feed's restore stops once a newer restore starts, or once the user applies a query or refreshes. The race was reproduced only in a gated test (the list jumped to 2870 px after the user chose a member), never in ordinary use | `restore_request_test`; before-run in `r04-before.txt` |
| R05 pages | Creator targets are 48 dp bands as wide as the name. Video dates are compact, with the full date read out. VideoRow stacks when narrow. The calendar's type and member chips fold behind 筛选. 我的 leads with 收藏/稍后看, with 设置 by the title. The selected tab is a header. AppSegments has a 48 dp hit band | `touch_polish_test`; the 320 day cells stay 44 dp (declared exception; 周议程 is the large-target path) |
| R06 (U18) | Filtered-empty and source-empty differ, each with a next step. A failed refresh says so at the top, over the old results. 更新 states its scope. Library lists say how things get there | `states_test`, `content_page_test` |
| R07 (U20) | Tile ↔ detail Hero (off with reduced motion). A new condition arrives tinted, and focus goes back to the filter entry. Save success shows only after storage, and a refused write shows its error | `motion_test` (the reduced-motion check fails if the guard is removed) |
| R08 evidence | Diagnostic art, a pixel sampler, system bars and keyboard in the harness, and geometry contracts for Today, 二创 and 我的 | A deliberate break fails (`r08-mutation.txt`). There are no pixel goldens: the CJK face is a system font, so goldens would be machine-dependent |
| R09 delivery | Local checks at `227aa75`: all five 0, 904 passed (`v2.1/final-checks.txt`) | No CI, APK or device (below) |

**Review.** A read-only reviewer covered `546dbd0..cdaae50` and reported four should-fix findings:
- the detail listener's setState during build, and the image handle it never released;
- the video tile's middle, and the blank byline space, opening the creator's page;
- two 清除条件 buttons with different scopes;
- the tint being cut short by feed rebuilds.

All four are fixed in `9473f4a`, with tests. Of the eight minor findings, five are fixed: the 2 px video slack, the trivially passing keyboard test, the 设置 list-entry test, the updates text duplicated when empty, and the 320 calendar path. Three are noted, not changed:
- the 继续挑选 fallback is a 1 s timer, not a navigation lifecycle (it can only withdraw its own request);
- a 409 dataset restart during a restore ends that restore silently;
- the selected channel tab is read as "heading, button".

**Also found in this round:**
- the first long-image cap trimmed ordinary portraits;
- the visual harness shared a failed image load between tests;
- `tool/flutterw format` is not a command, so earlier format runs had done nothing.

All three are fixed.

**Still device-only:**
- real Liquid Glass (the glass segmented control keeps its own 40 dp height);
- GPU cost and frame time;
- TalkBack, OS input and system fonts;
- real images, and the decode cost of `CoverDecodeImage`.

**Remote steps, not run (no authorization):**
- *Flutter Checks* on `claude/zen-babbage-ll6g3y` with `run_tests: true`;
- *Flutter Development Validation* on the same branch;
- *Flutter Performance Validation* at `7134a40` and at the final commit, with the isolated perf identity and `perf_signing=sdk-debug-key`, for arm64 and armv7, Release and Profile.

Then the ACCEPTANCE §5 tasks and the §6 device protocol.

**Why still PARTIAL_BLOCKED.** Every code, page and local-layout item is done. But no build of this candidate exists (U22: no Android SDK here), so this cannot be called "device only", and there is no device run (U23).

**Rollback by stage.** Revert in reverse dependency order, never a single mid-stack commit alone:

```text
docs:  git revert 227aa75 c3e7e3c
fixes: git revert 9473f4a cdaae50        (review fixes, then cap/harness)
R08:   git revert e54c139                (contracts: tests only)
R07:   git revert 9597ab4
R06:   git revert 999829a
R05:   git revert 56efedc
R04:   git revert 6e5ccb1
R03:   git revert 9881055
R08a:  git revert a53ea3e                (harness; media_geometry_test depends on it)
R02:   git revert aed99e0
R01:   git revert 2d057dc
```

Checked in a scratch worktree: applied in this order, every stage reverted without conflict and analyzed clean. Stopped after the R07 line, the full suite passed (891). With all lines applied, `lib`, `test` and `tool` match `546dbd0` byte for byte. Revert the docs commit that records this (the one after `227aa75`) together with the docs line. To drop all of V2.1: `git revert --no-commit 2d057dc^..227aa75 && git commit`. The same applies to V2: revert `aa04831` first, then back to `909b4c1`. There are no schema, data or dependency changes in either round.

---

## V2 (as reported at aa04831)

**Why PARTIAL_BLOCKED and not "only the device is missing".** The planned page and layout work is done, and the headless renders prove it. Two mainline tasks are not finished in code:
- **U20:** the four motion relationships were not built. Only the summary line's fold was added.
- **U18:** tools, updates and async states got no redesign beyond what the new pages brought.

Two tasks are blocked by this environment:
- **U22:** no Android SDK, because `dl.google.com` is denied, so no APK was built.
- **U23:** no device.

## What the user will see (same fixture, before → after)

The side-by-side sheets are `design/experience-v2/visual/final-vs-baseline-gray.png` (grayscale) and `final-overview.png`. Every image is an actual widget render (`flutter_tester`, Solid material, WenQuanYi Zen Hei from the system). None is a device screenshot or a mock-up.

| Page | Before (`visual/baseline`) | After (`visual/final`) |
|---|---|---|
| 今日 | A small bar title; saturated schedule pills; two identical, cut-off shelves | A date title; quiet agenda lines; 继续挑选 when there is a snapshot; two portrait works; clips as lines; the archive last. Time gets its own column when wide |
| 内容 · 二创 | A segmented control plus two pill rows; letterboxed art in framed 4:3 boxes; first item at 224 px | Text channel tabs as the title; one member row; applied conditions named and removable; borderless 4:5 tiles in a fixed grid; first item at 175 px |
| 内容 · 视频 | Framed cards | Frameless 16:9 units, order and window in the summary line; no search field, because none exists |
| 内容 · 动态 | A wall of framed cards (masonry) | One reading column ≤ 720 px, with a rule between entries and forwards as quote blocks |
| 内容 · 小说 | Framed cards with a letter avatar | A ruled bibliography: title, author · date · length, members, three serif lines |
| 日历 | A small bar; the agenda as saturated pills | A root title; agenda lines with state in words; 之后 (the next three events); a day/week switch |
| 我的 | A settings list with the whole preferences form | The library as tiles, 最近浏览, 管理, 应用; preferences moved to `/mine/settings` |
| 作品详情 | Text first, a chip for each fact | The first image first, then author and words, facts on one line, then the rest of the set |

## Commits (each can be reverted on its own; no schema, data or dependency change)

`909b4c1` harness · `17afaa8` `48c9b6a` docs · `eeaa3c0` directions · `03c47db` sample · `71b4d26` summaries and video · `e1690b7` gallery, tabs, titles · `68fc475` calendar · `e08eed3` dynamics · `6023406` novels · `4b27a8b` 继续挑选 · `b8c72b9` detail · `686be5d` stress fixes · `7f1f4c8` input test · `760c27f` summary fold · `aa04831` review fixes. The rest are docs and renders.

There are no new packages and no Flutter, Riverpod, router or glass version change (C01 did not start). Routes: `/mine/settings` was added, and every old path still resolves. 继续挑选 is held in memory only and nothing new is persisted.

## Tasks (four kinds of evidence kept apart; `design/experience-v2/tasks.json`)

| Task | Status | Code | Layout | Design (internal) | Device |
|---|---|---|---|---|---|
| U01 | verified | CI facts corrected, capability matrix | — | CAPABILITIES.md | — |
| U02 | verified | Harness, 35 scenes | `visual/baseline` | observations | n/a |
| U03/U04 | verified | — | — | PATTERNS.md, IA.md | — |
| U05 | verified | 12 prototype scenes | `visual/directions` | DIRECTIONS.md: A chosen internally | — |
| U06 | verified | Flows: filter, detail/back, save | `visual/sample` | SAMPLE.md, round 1 | pending |
| U07–U10 | verified | Tokens, header contract, QuerySummary ×4, families | `visual/components`, `final` | SYSTEM.md | pending |
| U11–U17, U19 | verified | Per page (see commits) | `visual/final` | this table | pending |
| U18 | in_progress | Nothing new beyond the pages | tools and states renders | gap stated | — |
| U20 | in_progress | Summary fold only; glass unchanged | — | 4 relationships not built | none |
| U21 | verified (headless) | 61 stress scenes, keyboard/48 dp test | `*_stress-*` | fixes in `686be5d` | OS input and TalkBack pending |
| U22 | blocked_external | Local suite green | — | — | no SDK, no APK |
| U23 | blocked_external | — | — | — | no device |
| U24 | this report | Independent read-only review: 2 should-fix and 12 minor findings. 11 fixed in `aa04831`, 3 noted below | — | — | — |
| C01 | not_applicable | Start conditions not met | — | — | — |

## Continuation of the old 32-task plan

- T15 → U07/U21. T16 → U08. T17 → U09. T19 → U11/U19. T20 → U12. T21 → U13. T22 → U14. T23 → U15. T24 → U16. T25 → U17. T26 → U18. T30 → U02/U21 (headless done; real renderer pending).
- T27, T31 → U23 (pending). T28, T29 → U22 (CI builds observed at `7134a40`, none for this branch). T32 → U24.
- T04–T06 remain blocked on an Android host (hand-off in LEDGER.md).

## Checks (actual commands and exit codes, `reports/experience-v2/final-checks.txt`)

`--verify-sdk` 0 · `pub get --enforce-lockfile` 0 · `analyze` 0 (no issues) · `format --set-exit-if-changed` 0 (306 files, 0 changed) · `test` 0 (**856 passed**, at `aa04831`). The date fix was also checked under `TZ=Asia/Shanghai` and `America/Los_Angeles`, and its test fails without the fix.

This is a local run. CI's check workflow still skips tests unless `run_tests` is set; nothing was dispatched from here.

## Tests that changed because the layout changed (each re-targeted to the new invariant; none deleted without replacement)

- `media_cards_test`: work covers are 4:5 (were 16:9).
- `content_page_test`: two columns at 320 and one at 2×, in a fixed grid (was one masonry column at 320).
- `mine_page_test`: rewritten for the content-first root, the settings page, the wide centred column and recent history.
- `today_page_test`: the wide layout has a time column; the phone order is works → clips → archive; the date title is split into parts; the 最近更新 guard is kept.
- `calendar_page_test`: only the title names today's month after moving.
- `calendar_agenda_layout_test`: 之后 is separate from the selected day; at 3× the folded switch reaches the week agenda.
- `novel_feed_view_test`: one centred column at every width.
- `preferences_controls_test`, `app_shell_material_test`: preferences are reached through 我的 → 设置.
- `saved_channel_test`: the stored range is the same instant, now local.

The reviewer judged two changes weaker than before. Both were corrected in `aa04831`:
- the Today "最近更新" guard is restored;
- the 3× calendar test now opens the week agenda.

## Known and not done

- **U20:** no source-to-panel continuity, detail transition or save animation. Glass is unchanged (bottom bar and rail only; Solid samples nothing).
- **U18:** the updates page and the state messages are as before; the tools sheet was already grouped by purpose.
- **Review notes left open:**
  - creator-name links in tile bylines are a small (~16 px) target, the same pattern as before;
  - the channel tabs have no `header` semantics;
  - `VideoCard`'s extent formula matches its padding by constant, not by construction;
  - video-type fanart covers are cropped to 4:5 (a deliberate, stable box).
- **Headless limits:** the screenshots use one CJK face for Latin text too. They show no Impeller glass, GPU cost, frame time or memory.

## Rollback

Superseded by the staged rollback in the V2.1 section above: the V2 commits depend on one another (tokens → components → pages → tests), so revert them newest first.

## Next concrete actions

1. The user reviews `visual/final-overview.png` and `final-vs-baseline-gray.png`, and records acceptance or changes in `tasks.json` (`accepted_by_user`).
2. On a machine with the Android SDK (or with `dl.google.com` allowed): dispatch *Flutter Checks* with `run_tests: true` and *Flutter Performance Validation* at `7134a40` and at this branch. Then run the ACCEPTANCE §5 tasks and the §6 device protocol on the target phones.
3. Then U20's four relationships and U18, if still wanted after the review.
