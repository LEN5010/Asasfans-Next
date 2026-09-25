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

## Current

- HEAD before work: 98e52c2 (clean tree, branch `claude/zen-babbage-ll6g3y`).
- Task status: `tasks-status.json`.

## Decisions

- D1: stale tests are repaired by retargeting finders to the widgets that replaced them; no assertion is dropped except the one about the deliberately removed built-in `视频默认过滤` (c77045c), which is replaced by an assertion that the rules page opened.
- D2: perf build identity is an app-module Gradle property (`-Pasasfans.perf=true`), not product flavors: flavors would change every existing Android command and a `default-flavor` would break iOS/macOS builds that have no matching scheme.

## Failed / blocked commands

- `curl https://dl.google.com/android/repository/repository2-3.xml` → 403 from the environment proxy (network policy).

## Next action

See the bottom of `tasks-status.json`.
