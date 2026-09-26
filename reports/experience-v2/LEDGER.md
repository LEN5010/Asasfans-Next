# Experience V2 — execution ledger

Plan package: `design/experience-v2/` (copied verbatim from `Asasfans-Experience-V2-Plan.zip`; `tasks.json` is the live task ledger, updated with `set_task.py`). The package's `MANIFEST.json` hashes describe the files as received; `tasks.json` has changed since, by design.

## Environment

| Item | Value |
|---|---|
| Review baseline | `7134a40cb6579d9d5831f76a9859a6c2196855ef` (origin/main; the merged session-01 work) |
| Branch | `claude/zen-babbage-ll6g3y`, reset onto origin/main at the start of this session because its earlier PR history was already merged |
| Flutter / Dart | 3.47.3 / 3.13.3, via `tool/flutterw` with `ASASFANS_FLUTTER_SDK=/home/user/sdk/flutter` (SHA-verified download) |
| Android SDK | **unavailable**: `dl.google.com` is denied by this environment's network policy. No APK, AOT or device work is possible here |
| Devices / desktop hosts | none |
| Screenshot renderer | `flutter_tester` software raster, Solid material only (shader filters unsupported there) |
| Fonts for screenshots | `/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc` (system font, loaded at test time as Roboto/serif/monospace; not copied into the repo or app), MaterialIcons from the SDK |
| Review aid | Pillow 12.3.0 (pip, scratch use only) for contact sheets; not a project dependency |

## Corrections to the session-01 record (U01)

The original `reports/optimization/` files are kept as written. What they got wrong or left stale:

1. **Builds did happen.** [Flutter Development Validation run 36226439271](https://github.com/LEN5010/Asasfans-Next/actions/runs/36226439271) (workflow_dispatch, 2026-09-26 07:19–07:24 UTC, head `7134a40`) concluded `success`. It covers Android Debug, iOS Debug (unsigned), macOS Profile and Windows Profile. "No build evidence" in FINAL.md is out of date. These are development builds, not perf AOT, release or device evidence.
2. **CI did not run the tests.** [Flutter Checks run 36226437173](https://github.com/LEN5010/Asasfans-Next/actions/runs/36226437173) passed format and analyze. Its test step is gated on the `run_tests` input (default `false`, `.github/workflows/flutter-checks.yml:7`) and was skipped. The "709 passed" figure is a local session report, not an independent CI result.
3. **B0 is not pristine 98e52c2.** The perf identity commit (`f89abb5` on the old branch, `bc0b7bd` on main) comes after the test re-alignment and two small fixes (text-only fanart tap, empty Today). A B0 built there measures 98e52c2 plus those fixes. A clean B0 would need a separate worktree at 98e52c2 with only the Gradle perf change applied. Neither was built. For V2 the plan compares `7134a40` AOT with the new-UI AOT (PLAN §2A). That comparison is also still unbuilt.
4. **The APK size did not change.** The two debug APKs in the review evidence differ by +44,312 bytes (166,921,660 → 166,965,972). No size improvement was claimed, and none should be.
5. **T15 is partial, not verified.** Only touch-target helpers were delivered, without the typography, density and hierarchy work the task asked for. T16, T23 and T24 were not started. The old `FINAL.md` status, PARTIAL_BLOCKED, stands.

## Hand-off for the performance validation (unchanged, still pending)

Allow `dl.google.com`, or use a machine with the Android SDK. Then dispatch *Flutter Performance Validation* at `7134a40` and at the final V2 commit with `perf_signing=sdk-debug-key`. Install `asasfans.next.perf` on the target phones and run the device scenarios from `design/experience-v2/ACCEPTANCE.md` §6. Nothing in this ledger triggers CI, signs or publishes anything.

## Checkpoints

| # | Commit | Tasks | Commands and exit codes | Notes |
|---|---|---|---|---|
| 1 | `909b4c1` | U02 harness | `analyze` 0; `format --set-exit-if-changed` 0; `test test/content test/shared test/calendar` 0 (278 passed); `test test/visual/current_pages_test.dart` 0 (35 passed) | Harness, fixture, capture script. The button and quick-chip label styles now derive from the theme. Before this, the tester rendered those labels as tofu because they had no font family |
| 2 | `17afaa8`, `48c9b6a` | U01–U04 | docs only | Plan tracked; CAPABILITIES, PATTERNS, IA; 35 baseline renders |
| 3 | `eeaa3c0` | U05 | `test test/visual/directions_test.dart` 0 (12) | Three directions; internal choice A |
| 4 | `03c47db`, `1496e1f` | U06 | `analyze` 0; `test` 0 (763 passed) | Today/二创/我的 sample; 16 old-layout tests re-targeted (listed in FINAL.md); flows filter/detail/save |
| 5 | `71b4d26`, `e1690b7`, `5ccbea0` | U07–U10 | `test` 0 (771) | QuerySummary ×4 channels, frameless video, gallery |
| 6 | `68fc475`…`b8c72b9` | U13–U16, U19 | `test` 0 (790) | Calendar, dynamics, novels, detail, 继续挑选 |
| 7 | `686be5d`, `7f1f4c8`, `bb6dd00` | U21 | `analyze` 0; `format` 0; `test` 0 (853) | Stress matrix, input test, 90 final renders |
| 8 | `760c27f`, `aa04831` | U20 (fold), U24 | all five checks 0 (`final-checks.txt`, 856 passed) | Review fixes; FINAL.md written; renders recaptured at `aa04831` |
| 9 | `2d057dc`…`e54c139` | V2.1 R01–R08 (review package `design/experience-v2/review-546dbd0/`) | per package: failing test first, then affected suites; full `test` 0 (896) at `9597ab4` | Before-runs are in `v2.1/r01-r02-before.txt`, `r03-before.txt` and `r04-before.txt`. R04's race was reproduced only in a gated test |
| 10 | `cdaae50`, `9473f4a` | V2.1 review fixes | read-only review: 4 should-fix and 8 minor findings; `analyze` 0; `dart format` 0; `test` 0 (904) | This session's earlier "format" runs called `tool/flutterw format`, which is not a command, so 15 files were unformatted until `9473f4a`, which ran `dart format` (whitespace only) |
| 11 | `c3e7e3c`, `227aa75` | R09 | five checks 0 (`v2.1/final-checks.txt`, 904 passed) | 111 renders in `visual/v2.1` from `9473f4a`. No CI dispatched, no APK, no device |
