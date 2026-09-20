import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/calendar/data/calendar_cache_store.dart';
import 'package:asasfans_next/features/preferences/data/sqlite_preferences_repository.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

void main() {
  test(
    'defaults are not written during a read; per-key changes preserve others',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final repository = SqlitePreferencesRepository(db);
      final defaults = await repository.load();
      expect(defaults.appearance, AppAppearance.system);
      expect(defaults.hiddenHomeSections, isEmpty);
      expect(db.database.select('SELECT * FROM preferences'), isEmpty);
      await repository.setAppearance(AppAppearance.dark);
      await repository.setHomeSection(HomeSection.fanart, false);
      final result = await repository.setHomeSection(HomeSection.clips, false);
      expect(result.appearance, AppAppearance.dark);
      expect(result.hiddenHomeSections, {
        HomeSection.fanart,
        HomeSection.clips,
      });
      expect(
        (await repository.setHomeSection(
          HomeSection.fanart,
          true,
        )).hiddenHomeSections,
        {HomeSection.clips},
      );
    },
  );

  test(
    'invalid known settings surface an error rather than silently resetting them',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      await db.batch(const [
        SqlStatement('INSERT INTO preferences VALUES (?, ?)', [
          'appearance',
          'unexpected',
        ]),
      ], write: true);
      await expectLater(
        SqlitePreferencesRepository(db).load(),
        throwsA(isA<StorageFailure>()),
      );
      expect(
        db.database.select('SELECT value FROM preferences').single['value'],
        'unexpected',
      );
    },
  );

  test(
    'cache removal does not delete preferences and validators remain per source',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final prefs = SqlitePreferencesRepository(db);
      await prefs.setAppearance(AppAppearance.light);
      final cache = SqliteCalendarCacheStore(db);
      final first = Uri.parse('https://first.example/calendar.ics');
      final second = Uri.parse('https://second.example/calendar.ics');
      final time = DateTime.utc(2026, 9, 21);
      await cache.write(
        first,
        CalendarCacheEntry(body: 'one', fetchedAt: time, etag: 'first'),
      );
      await cache.write(
        second,
        CalendarCacheEntry(
          body: 'two',
          fetchedAt: time,
          etag: 'second',
          stale: true,
        ),
      );
      expect((await cache.read(first))!.etag, 'first');
      await cache.remove(first);
      expect(await cache.read(first), isNull);
      expect((await cache.read(second))!.stale, isTrue);
      expect((await prefs.load()).appearance, AppAppearance.light);
    },
  );

  test(
    'cache count and size are bounded; malformed header values are never replayed',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final cache = SqliteCalendarCacheStore(db);
      for (var index = 0; index < 10; index++) {
        await cache.write(
          Uri.parse('https://example.com/$index.ics'),
          CalendarCacheEntry(
            body: 'calendar',
            fetchedAt: DateTime.utc(2026, 9, 1 + index),
            etag: 'bad\r\nheader',
          ),
        );
      }
      expect(
        db.database.select('SELECT * FROM calendar_cache'),
        hasLength(SqliteCalendarCacheStore.maxSources),
      );
      expect(await cache.read(Uri.parse('https://example.com/0.ics')), isNull);
      expect(
        (await cache.read(Uri.parse('https://example.com/9.ics')))!.etag,
        isNull,
      );
      await expectLater(
        cache.write(
          Uri.parse('https://example.com/large.ics'),
          CalendarCacheEntry(
            body: 'x' * (SqliteCalendarCacheStore.maxBodyCharacters + 1),
            fetchedAt: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<StorageFailure>()),
      );
    },
  );
}
