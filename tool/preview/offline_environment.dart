import 'dart:async';
import 'dart:io';

import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/config/app_environment.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/platform/return_entry_service.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Reuse the same real-schema in-memory fixtures as the offline test suite.
// None of these helpers imports flutter_test or reads application data.
import '../../test/helpers/account_fixture.dart';
import '../../test/helpers/sqlite_fixture.dart';

class OfflinePreviewHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Network is disabled in the offline preview.');
}

/// All mutable personal state is disposable, including rules, preferences,
/// return sessions, updates and credentials. Production repositories/controllers
/// still exercise their normal database and widget paths against this store.
List<Override> offlinePreviewOverrides() => [
  currentTimeProvider.overrideWithValue(() => DateTime.utc(2026, 9, 23, 4)),
  appEnvironmentProvider.overrideWithValue(
    AppEnvironment(
      dynamicApiBaseUrl: Uri.parse('https://preview.invalid/api/'),
      calendarUrl: Uri.parse('https://preview.invalid/calendar.ics'),
    ),
  ),
  localDatabaseProvider.overrideWith((ref) {
    final database = MemoryLocalDatabase();
    ref.onDispose(() => unawaited(database.close()));
    return database;
  }),
  biliVaultProvider.overrideWith((_) => MemoryAccountVault()),
  biliLoginCookiesProvider.overrideWith((_) => MemoryLoginCookies()),
  externalLinkServiceProvider.overrideWithValue(const _NoExternalLinks()),
  returnEntryServiceProvider.overrideWithValue(
    const UnsupportedReturnEntryService(),
  ),
  fanartRepositoryProvider.overrideWithValue(const _EmptyFanart()),
  dynamicRepositoryProvider.overrideWithValue(const _EmptyDynamics()),
  communityVideoRepositoryProvider.overrideWithValue(const _EmptyVideos()),
  calendarRepositoryProvider.overrideWithValue(const _PreviewCalendar()),
];

class _NoExternalLinks implements ExternalLinkService {
  const _NoExternalLinks();
  @override
  Future<bool> open(Uri uri) async => false;
}

class _EmptyFanart implements FanartRepository {
  const _EmptyFanart();
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => const FanartPage(items: [], snapshotId: 'offline', total: 0);
  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

class _EmptyDynamics implements DynamicRepository {
  const _EmptyDynamics();
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => const DynamicPage(items: [], total: 0);
  @override
  Future<List<DynamicMember>> members() async => const [];
  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => const [];
}

class _EmptyVideos implements CommunityVideoRepository {
  const _EmptyVideos();
  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async => CommunityVideoPage(videos: const [], page: page, hasMore: false);
}

class _PreviewCalendar implements CalendarRepository {
  const _PreviewCalendar();
  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async => CalendarSnapshot(
    fetchedAt: DateTime.utc(2026, 9, 23, 4),
    events:
        [
              CalendarEvent(
                uid: 'preview-live',
                title: '一起度过秋日午后',
                start: DateTime.utc(2026, 9, 23, 12),
                end: DateTime.utc(2026, 9, 23, 13, 30),
                allDay: false,
                members: const ['嘉然'],
                categories: const ['直播'],
              ),
            ]
            .where(
              (event) => event.start.isBefore(until) && event.end.isAfter(from),
            )
            .toList(),
  );
}
