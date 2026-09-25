# Optimization ledger

Plan package: `docs/optimization/` (local only — `/docs/` is gitignored by this repo). Plan baseline: `98e52c291f7aa94d8344f43ec6df0a9fd52cff27`.

## Environment (session 01, 2026-09-25)

- Host: Linux x64 cloud container, 4 CPU, 15 GiB RAM. No Android device, no emulator.
- Flutter 3.47.3 stable (`e8113bf456`), Dart 3.13.3 — downloaded from the pinned URL, SHA256 matched `tool/flutter-sdk.json`; `tool/flutterw --verify-sdk` exit 0.
- Java: OpenJDK 21.0.10.
- **Android SDK: unavailable.** The environment's network policy denies `dl.google.com` (HTTP 403), so platforms/build-tools/NDK cannot be installed. Every APK build, APK audit, B0/B1 comparison and device measurement is `blocked_external` in this session.
- No iOS/macOS/Windows hosts.

## Checkpoints

| Commit | Scope | Evidence |
|---|---|---|
| (baseline) 98e52c2 | — | analyze exit 0; test exit 1 (641 pass / 33 fail) — see `run-01/baseline-failures.md` |
| 7eb7493 | T01/T02 stale tests, card tap, empty home | test 0 (674) |
| f89abb5 | T04 perf identity (not built) | read-only review |
| ebddc9c | T10 return restore | test 0 (682) |
| ca8f41f | T07 glass tier | test 0 (689) |
| 9fd2626 | T08/T09 images | test 0 (693) |
| b46463d | T12 grid extent, rule memo | test 0 (695) |
| f6f2abd | T14 visible-only resume | test 0 (696) |
| 52aedf0 | T13 SQL measurement | host bench |
| f6d4bda | T11 two mounted channels | test 0 (697) |
| de37b9d | T15 touch targets, semantics fix | test 0 (704) |
| 2067013 / 2735c33 | T17/T19/T26 increments | test 0 (706/707) |
| ca06428 | T35 host ICS timing, statuses | analyze 0 |
| 2370072 | independent review fixes | test 0 (709) |

## Current

- HEAD before work: 98e52c2 (clean tree, branch `claude/zen-babbage-ll6g3y`).
- Task status: `tasks-status.json`. Final report: `FINAL.md` (status PARTIAL_BLOCKED).

## Decisions

- D1: stale tests are repaired by retargeting finders to the widgets that replaced them; no assertion is dropped except the one about the deliberately removed built-in `视频默认过滤` (c77045c), which is replaced by an assertion that the rules page opened.
- D2: perf build identity is an app-module Gradle property (`-Pasasfans.perf=true`), not product flavors: flavors would change every existing Android command and a `default-flavor` would break iOS/macOS builds that have no matching scheme.

## Failed / blocked commands

- `curl https://dl.google.com/android/repository/repository2-3.xml` → 403 from the environment proxy (network policy).
- `curl https://asoul.love/calendar.ics` → 403 (network policy); real calendar size unknown.
- Gradle configuration check could not resolve AGP (Google Maven host blocked); routing around the block was refused and not pursued.

## Next action

Allow dl.google.com (or use a machine with the Android SDK), then run the Flutter Performance Validation workflow at f89abb5 (B0) and HEAD (B1) and the VALIDATION.md device scenarios.
