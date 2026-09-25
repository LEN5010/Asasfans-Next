# Baseline test failures at 98e52c2 (before any change)

Command: `tool/flutterw test --no-pub` → exit 1, 641 passed / 33 failed.

All 33 were classified as test drift, not environment errors and not product regressions, except where noted:

| File | Test | Cause |
|---|---|---|
| library/library_pages_test.dart | actions save to folders, later and local subscriptions with live committed state | SwitchListTile/ChoiceChip/FilledButton replaced by ListTile+AppSwitch / AppChoice / AppButton (bffee70) |
| library/library_pages_test.dart | history filtering and removal do not affect favorites or other actions | SwitchListTile/ChoiceChip/FilledButton replaced by ListTile+AppSwitch / AppChoice / AppButton (bffee70) |
| library/library_pages_test.dart | manual local subscription validates MID and only opens the explicit profile link | SwitchListTile/ChoiceChip/FilledButton replaced by ListTile+AppSwitch / AppChoice / AppButton (bffee70) |
| content/fanart_detail_test.dart | returning from a detail keeps the scroll position and loaded pages | ContentPage() now defaults to videos (61aba18); also exposed a real bug: text-only fanart cards wrapped text in SelectionArea, which swallowed the card tap |
| content/dynamic_feed_view_test.dart | searching applies the keyword on submit | search is an inline field now (de5111d), no 搜索 tooltip button |
| content/immersive_navigation_test.dart | detail and artwork cover a nested shell, then return to the same loaded feed | ContentPage() defaults to videos; pageBack() needs Material BackButton, app uses AppPageBar |
| content/community_feed_view_test.dart | clips uses its own indexed-video definition | clips/replays are video kinds (videoKind), not channel slugs |
| content/community_feed_view_test.dart | replays uses its own indexed-video definition | clips/replays are video kinds (videoKind), not channel slugs |
| content/content_page_test.dart | toolbar and quick filters keep the first content row near the top at width 320.0 | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| app_shell_test.dart | Mine opens real rules management with source ordering as the default | mine links are AppButtons; built-in 视频默认过滤 removed (c77045c); multiple offstage scrollables |
| content/content_page_test.dart | toolbar and quick filters keep the first content row near the top at width 1200.0 | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| rules/rule_feed_integration_test.dart | blocked first page auto-refills; undo reprojects raw rows without another network request | ContentPage() defaults to videos |
| rules/rule_feed_integration_test.dart | all-hidden upstream pages stay ready and stop at viewport scan budget, not false end | ContentPage() defaults to videos |
| content/content_page_test.dart | a failed refresh keeps cards and shows a retry instead of silently failing | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| rules/rule_feed_integration_test.dart | quick block and snackbar undo use committed rules without reloading the source | ContentPage() defaults to videos |
| rules/rule_feed_integration_test.dart | backup merge refreshes live rule projection without replacing the source controller | ContentPage() defaults to videos |
| content/content_page_test.dart | a first page failure offers a retry that recovers | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| content/content_page_test.dart | applying a filter reloads with the new query from the top | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| content/content_page_test.dart | submitting a search applies the keyword | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| content/content_page_test.dart | random uses the current applied query rather than an unfiltered draw | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| content/content_page_test.dart | a narrow window drops to one readable column | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| content/content_page_test.dart | wide windows use more columns than a phone | quick-filter strips added (1183547), inline search, FilterChip/OutlinedButton/FilledButton → AppChoice/AppButton, fanart grid → masonry |
| tool/flutter_sdk_test.dart | manifest, editor hint, pubspec and both CI SDK pins agree | flutter-checks.yml now has one job pinning the SDK (722a379) |
| preferences/preferences_controls_test.dart | hidden home modules do not load before settings arrive, on display or on refresh | 二创档案 entry removed (8aafbe6) leaving an all-hidden Today page blank (UX gap, now fixed with an explanatory empty state); test also hit the real DB via the updates bell |
| today/today_page_test.dart | calendar retry invalidates the owning month, not just the dependent future | OutlinedButton/IconButton → AppButton |
| today/today_page_test.dart | failed fanart stays local and retry leaves clips and schedule intact | OutlinedButton/IconButton → AppButton |
| today/on_this_day_section_test.dart | a failed module can be retried in place | OutlinedButton → AppButton |
| today/today_page_test.dart | refresh waits for modules and disables duplicate manual refresh | OutlinedButton/IconButton → AppButton |
| backup/backup_page_test.dart | accepted import is single-flight and route stays until transaction finishes | ListTile import action → AppButton |
| calendar/calendar_page_test.dart | the live filter hides non-broadcast entries | ChoiceChip/FilledButton → AppChoice/AppButton |
| calendar/calendar_page_test.dart | a load failure offers a retry | ChoiceChip/FilledButton → AppChoice/AppButton |
| calendar/calendar_agenda_layout_test.dart | member filter uses structured members and reset restores events | FilterChip → AppChoice |
| calendar/calendar_agenda_layout_test.dart | loading errors do not remove date and filter controls | FilterChip → AppChoice |
