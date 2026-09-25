# T13 · SQL round-trip measurement (host)

Script: `run-02/sql_lifecycle_bench.dart` (`dart run reports/optimization/run-02/sql_lifecycle_bench.dart`), output `run-02/sql_lifecycle_host.txt`.
Host: Linux x64 container, 4 CPUs, Dart 3.13.3, on-disk database in a temp dir. **Host numbers are not device numbers.**

| Path | p50 | p90 |
|---|---:|---:|
| `IsolateLocalDatabase.batch` read | 2.08 ms | 2.49 ms |
| `IsolateLocalDatabase.batch` write+read | 1.97 ms | 2.68 ms |
| `Isolate.run` no-op | 0.26 ms | 0.44 ms |
| open + initialize + read + dispose, same isolate | 1.26 ms | 1.45 ms |
| read on an already-open connection | 0.02 ms | 0.03 ms |
| write+read on an already-open connection | 0.04 ms | 0.06 ms |

So per batch the lifecycle (isolate hop + open + identity validation + WAL/synchronous pragmas + dispose) is ~98 % of the cost; the SQL itself is negligible.

Batch counts (widget test with a counting `LocalDatabase` wrapper around the in-memory store, Today data sources stubbed; the test was a throwaway and is not committed):

| Flow | Batches |
|---|---:|
| Cold start to settled Today | 4 (preferences; return session; updates counts; rules + subscriptions + rule settings already merged into one batch) |
| Switch to 内容 | 1 (return session read by the feed restore check) |
| Switch to 日历 | 1 (calendar cache) |
| Switch to 我的 | 0 |

Decision:
- No merging change: the startup reads belong to different repositories that load independently, and the one place with several related reads (rules) is already a single batch.
- **T34 (long-lived SQL worker): not_applicable.** Activation needs lifecycle cost that stays significant after merging. Lifecycle does dominate each batch, but there are only 4 batches at cold start and ≤ 1 per tab switch, all off the UI isolate (≈ 8 ms serialized background latency on this host). A long-lived connection would reintroduce native handles across hot restart and provider teardown, which the current design avoids on purpose. Re-evaluate only if device traces show startup waiting on this queue.
- Durability and identity checks untouched (`synchronous = FULL`, application_id/user_version validation on every open).
