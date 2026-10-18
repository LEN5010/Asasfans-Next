import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../core/time/local_date_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_models.dart';
import '../data/calendar_event_store.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';

final calendarEventStoreProvider = Provider<SqliteCalendarEventStore>(
  (ref) => SqliteCalendarEventStore(ref.watch(localDatabaseProvider)),
);

final calendarLibraryChangesProvider = StreamProvider<int>(
  (ref) => ref.watch(libraryRepositoryProvider).changes,
);

class CalendarFollowSelection {
  const CalendarFollowSelection({required this.members, required this.stars});
  final Set<String> members;
  final List<CalendarFollow> stars;

  bool contains(CalendarEvent event, Uri source) =>
      stars.any(
        (star) =>
            star.key.source == source && star.event.identity == event.identity,
      ) ||
      EventClassifier.members(event).any(members.contains);
}

final calendarFollowSelectionProvider = FutureProvider<CalendarFollowSelection>(
  (ref) async {
    ref.watch(calendarLibraryChangesProvider);
    ref.watch(localDateProvider);
    Timer? expiry;
    var disposed = false;
    final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
    ref.onDispose(() {
      disposed = true;
      expiry?.cancel();
      lifecycle.dispose();
    });
    final library = ref.watch(libraryRepositoryProvider);
    final clock = ref.watch(currentTimeProvider);
    final store = ref.watch(calendarEventStoreProvider);
    await library.expireCalendarFollows(clock());
    final members = await store.readMemberFollows();
    final stars = await library.calendarFollows();
    final ends = [for (final star in stars) star.event.endsAt]..sort();
    if (!disposed && ends.isNotEmpty) {
      final delay = ends.first.difference(clock());
      expiry = Timer(
        delay.isNegative ? Duration.zero : delay,
        ref.invalidateSelf,
      );
    }
    return CalendarFollowSelection(members: members, stars: stars);
  },
);

final isCalendarSelectedProvider = Provider.autoDispose
    .family<bool, CalendarEvent>((ref, event) {
      final source = ref.watch(appEnvironmentProvider).calendarUrl;
      return ref
              .watch(calendarFollowSelectionProvider)
              .valueOrNull
              ?.contains(event, source) ??
          false;
    });

Future<void> setCalendarMemberFollow(
  WidgetRef ref,
  String member,
  bool followed,
) async {
  await ref.read(calendarEventStoreProvider).setMemberFollow(member, followed);
  ref.read(libraryRepositoryProvider).notifyExternalCommit();
}
