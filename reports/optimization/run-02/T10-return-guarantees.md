# T10 · Return guarantees per channel (after this change)

| Channel | Recorded on leaving | Rebuilt on a cold return | Position |
|---|---|---|---|
| Videos (latest / clips / replays) | kind (route), order, time window, anchor (identity + offset) | kind via route; order and window re-applied | identity first; up to 3 extra pages; offset + notice when the item is gone |
| Fanart | full committed query (ChannelSpec), anchor | query re-applied | same |
| Dynamics | full committed query (ChannelSpec), anchor | query re-applied | same |
| Novels | nothing: reading is in-app, the source link does not start a return session | n/a | a warm return keeps the mounted list |

Common rules:
- A session is applied by at most one feed mount per process (`HandoffCoordinator.listRestoreFor`).
- A session consumed by an earlier launch is not replayed (previously every fresh launch that opened 二创 re-applied the last trip's query).
- "Visible" in tests means the card's painted rect overlaps the viewport below the floating bar, not `findsOneWidget`.
- Warm returns are untouched: the mounted feed keeps its controller, pages and offset.

Tests: `test/handoff/return_query_restore_test.dart` (+4: off-screen anchor, later page within budget, missing anchor → offset + notice, stale session not replayed), `test/handoff/return_channel_restore_test.dart` (video order/window/anchor, other-kind isolation, dynamics query/anchor restore, dynamics capture).

Commands: `tool/flutterw analyze --no-pub` → 0; `dart format --output=none --set-exit-if-changed lib test tool` → 0; `tool/flutterw test --no-pub` → 0 (682 passed).
