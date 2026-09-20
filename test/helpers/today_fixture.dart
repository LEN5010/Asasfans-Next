import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/today/application/today_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'preferences_fixture.dart';
import 'library_fixture.dart';
import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';

/// Shell/layout tests must never resolve the production sources by accident.
/// Repository behavior is covered separately; these are stable display inputs.
List<Override> offlineTodayOverrides({
  List<CalendarEvent> events = const [],
  List<FanartItem> fanart = const [],
  List<CommunityVideo> clips = const [],
  PreferencesRepository? preferences,
}) => [
  ...offlineLibrary(),
  if (preferences == null)
    offlinePreferences()
  else
    preferencesRepositoryProvider.overrideWithValue(preferences),
  currentTimeProvider.overrideWithValue(() => DateTime.utc(2026, 9, 21, 4)),
  todayScheduleProvider.overrideWith(
    (ref) async => CalendarSnapshot(
      events: events,
      fetchedAt: DateTime.utc(2026, 9, 21, 4),
    ),
  ),
  todayFanartProvider.overrideWith((ref) async => fanart),
  todayClipsProvider.overrideWith((ref) async => clips),
  onThisDayProvider.overrideWith((ref) async => const []),
];
