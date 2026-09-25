# Feature-preservation matrix (T01)

Baseline 98e52c2. "Guard" names the automated tests that must stay green; a blank guard means the journey is only covered by manual/device acceptance.

| Journey | Entry points (routes) | Local data touched | Guard (tests) |
|---|---|---|---|
| Today | `/today` | preferences (`home.*.visible`), calendar cache | `test/today/*`, `test/preferences/preferences_controls_test.dart` |
| Videos (all / clips / replays) | `/content/videos?kind=`, legacy `/content/{latest,clips,replays,subscriptions}` | history, handoff session | `test/content/community_*`, `test/handoff/*` |
| Fanart | `/content/fanart`, detail + image viewer (root routes) | saved_channels, history, handoff session | `test/content/content_page_test.dart`, `fanart_*`, `immersive_navigation_test.dart`, `test/handoff/return_query_restore_test.dart` |
| Dynamics | `/content/dynamics` | saved_channels | `test/content/dynamic_*` |
| Novels | `/content/novels`, reader | — | `test/novels/*` |
| Calendar | `/calendar` | calendar_follows, ICS cache (ETag/304) | `test/calendar/*` |
| Library | `/mine/{saved,saved/:folder,later,history,continue,bookmarks,subscriptions,calendar-follows}` | collection_*, watch_later, content_history, local_subscriptions, playback_* | `test/library/*` |
| Updates | `/mine/updates`, bell | update_events, update_cursors | `test/updates/*` |
| Rules | `/mine/rules` | content_rules, rule_settings | `test/rules/*` |
| Backup / restore | `/mine/backup` | all user tables (transactional merge) | `test/backup/*` |
| Preferences | `/mine` (偏好) | preferences (`appearance`, `ui.material`, `home.*`) | `test/preferences/*`, `test/glass/*` |
| Credits / licences | `/mine/credits`, licence page | — | `test/mine/*` |
| Leave for Bilibili and return | watch buttons; Android return overlay (`ReturnEntryBridge`, `ReturnOverlayService`) | return_sessions | `test/handoff/*`; overlay behaviour is device-only |
| Tools | tools sheet (floating button) | — | `test/tools/*` |
| Local login cleanup (retired login) | Mine → 账号 when residue exists | secure storage, WebView cookies | `test/account/*` |

Out of scope and must stay out: in-app player/FFmpeg/downloader, cloud login/sync, the cancelled legacy Android data migration, a second glass library, removing armv7, raising targetSdk.
