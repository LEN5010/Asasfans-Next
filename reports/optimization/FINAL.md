# Optimization session 01 — final report

```text
Status: PARTIAL_BLOCKED
Baseline / Candidate: 98e52c291f7aa94d8344f43ec6df0a9fd52cff27 → branch claude/zen-babbage-ll6g3y (see git log; last code commit 2370072)
```

**Why PARTIAL_BLOCKED:** the network policy of this cloud environment denies `dl.google.com`, so no Android SDK can be installed. Nothing Android could be built: no B0/B1 APK, no APK or ABI evidence, no perf-variant build check. There are no devices or desktop hosts either, so there are no frame, memory or visual measurements. All code-level work was tested (analyze, format and the full test suite pass). None of it was measured on a phone.

## Verified changes (each is its own revertible commit)

| Commit | Change | Evidence |
|---|---|---|
| 7eb7493 | 33 stale tests re-targeted to the current widgets. Two real bugs found along the way: text-only fanart cards could not be tapped open, and an all-hidden Today page was blank. | `run-01/baseline-failures.md` |
| f89abb5 | `-Pasasfans.perf=true` builds a separate `asasfans.next.perf` app with an explicitly chosen test signature. Adds a manual perf CI workflow and `tool/audit_apk.py`. The production gate is unchanged. | Reviewed by reading only; **not built** |
| ebddc9c | Return restore scrolls the card the user left from back into view (identity first, at most 3 extra pages, a notice when the card is gone). Videos and dynamics now keep their query and anchor too. A session consumed by an earlier launch is no longer replayed. | `run-02/T10-return-guarantees.md`, handoff tests |
| ca8f41f | Glass setting is now 流畅优先 / 自动 / 视觉优先. Android defaults to the standard tier, not premium. Every fallback renders solid. Settings show the tier in effect and why. Older builds can still read the database. | Glass/preference tests |
| 9fd2626 | Images are decoded for the drawn size × DPR, snapped to buckets, with a 16 MP cap. Preview and original URIs stay separate. | `media_image_policy_test` |
| b46463d | Video grid uses a single fixed extent (geometry proven identical). Rules are projected once per data or rule change. | Grid equivalence test, memo test |
| f6f2abd | Resume refreshes only the page on screen. The root app no longer rebuilds on unrelated preference saves. | `resume_when_visible_test` |
| 52aedf0 | SQL batch lifecycle measured; a long-lived worker is not warranted. | `run-02/T13-sql.md` |
| f6d4bda | Only 2 content channels stay mounted. Coming back to one keeps its pages and exact scroll offset. | `content_page_test` |
| de37b9d | 48 dp touch areas on Android/iOS around the 40 dp look. Fixed a pre-existing unreachable search-field button in the accessibility tree. | `touch_target_test`, `search_field_semantics_test` |
| 2067013, 2735c33 | "Everything is hidden by your rules" is now its own feed state. Today puts content before the archive on phones. A named tools entry was added to 我的. | Rules, Today and Mine tests |
| 2370072 | Fixes from the independent review: no warm-return replay, no extra page fetch, offset settling yields to the restore, non-perf Android profile builds are refused, no selectable text in the history preview. | handoff tests |

## Preserved functionality

`FEATURE_MATRIX.md` lists every journey with its guard tests. No feature, dependency, ABI, data table or licence was removed. There is no new player, no new glass library, and no SDK upgrade. `targetSdk`, `minSdk` and `compileSdk` are unchanged.

## APK and ABI evidence

None produced; blocked (no Android SDK). The D0 figures in `docs/optimization/evidence` (166,921,660-byte debug APK) remain the only APK numbers. B0 must be built from `f89abb5` (build config only), and B1 from the latest commit, using the *Flutter Performance Validation* workflow.

## Performance evidence

Host measurements only (Linux x64, JIT for the scripts):
- SQL: about 2 ms p50 per batch, almost all of it lifecycle. 4 batches at cold start, at most 1 per tab switch.
- ICS parse on the UI isolate: 10.7 ms for 200 events, 30 ms for 1000.

No device frame timing, startup timing or PSS. No improvement percentage is claimed.

## Visual evidence

None. No screenshots were produced, and no mock-ups were substituted.

## Tests and actual exit codes (latest checkpoint)

- `tool/flutterw --verify-sdk` → 0
- `tool/flutterw pub get --enforce-lockfile` → 0
- `tool/flutterw analyze --no-pub` → 0
- `dart format --output=none --set-exit-if-changed lib test tool reports` → 0
- `tool/flutterw test --no-pub` → 0 (709 passed, 0 failed)
- Baseline at 98e52c2: `test` → 1 (641 passed, 33 failed; all classified)

## Blocked / Not run

- Android/iOS/macOS/Windows builds (T28), B0/B1 (T05, T31), dependency cost (T06), screenshots (T30), native return overlay (T27): need an Android SDK, devices or hosts.
- T35 background ICS parsing: the real feed size is unknown (host denied by network policy) and per-isolate timezone setup cost is unmeasured.
- Not done this session: T16 shell polish, T23/T24 page redesigns, a "continue picking" card on Today, an applied-conditions summary row, the package's experimental `adaptiveQuality` (toggling it would insert a parent above the whole app, so it needs a stable scope first).
- Known low item from review: `BoxFit.cover` covers decode at box width, so an image wider than its box can look slightly soft. Same flaw as the old fixed 800 px decode.

## Rollback

Every change is a separate commit on top of 98e52c2; `git revert <commit>` undoes any one. There are no schema changes. The one new preference key (`ui.glassTier`) is ignored by older builds. Reverting f89abb5 removes the perf identity with no data effect.

## Next concrete action

Allow `dl.google.com` in the environment's network settings (or run on a machine with the Android SDK). Then dispatch *Flutter Performance Validation* twice, at `f89abb5` (B0) and at the latest commit (B1), with `sdk-debug-key`. Install `asasfans.next.perf` on the target old phone and run VALIDATION.md scenarios S1–S8.
