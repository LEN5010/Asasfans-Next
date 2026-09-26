# Experience V2: final report

```text
Status: PARTIAL_BLOCKED
Baseline → candidate: 7134a40 → aa04831 (branch claude/zen-babbage-ll6g3y), plus docs after it
User acceptance: pending (nothing here has been reviewed by the user)
```

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

`git revert <commit>` for any feature commit above. Order does not matter, except that `aa04831` depends on the commits before it. No stored data changes, and the `/mine/settings` route is additive.

## Next concrete actions

1. The user reviews `visual/final-overview.png` and `final-vs-baseline-gray.png`, and records acceptance or changes in `tasks.json` (`accepted_by_user`).
2. On a machine with the Android SDK (or with `dl.google.com` allowed): dispatch *Flutter Checks* with `run_tests: true` and *Flutter Performance Validation* at `7134a40` and at this branch. Then run the ACCEPTANCE §5 tasks and the §6 device protocol on the target phones.
3. Then U20's four relationships and U18, if still wanted after the review.
