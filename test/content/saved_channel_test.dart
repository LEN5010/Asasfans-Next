import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/content/data/sqlite_channel_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/saved_channel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

void main() {
  late MemoryLocalDatabase db;
  late SqliteChannelRepository repository;
  setUp(() {
    db = MemoryLocalDatabase();
    repository = SqliteChannelRepository(
      db,
      clock: () => DateTime.utc(2026, 9, 21),
    );
  });
  tearDown(() async {
    await repository.close();
    await db.close();
  });

  test('a fanart query survives a save and load round trip', () async {
    const query = FanartQuery(
      keyword: '生日',
      characters: {FanartCharacter.diana},
      contentType: FanartContentType.video,
      category: FanartCategory.all,
      sort: FanartSort.oldest,
      source: FanartSource.bilibili,
    );
    await repository.save(
      '嘉然生日',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(query),
    );

    final restored = (await repository.channels()).single.spec.toFanart();
    expect(restored.keyword, '生日');
    expect(restored.characters, {FanartCharacter.diana});
    expect(restored.contentType, FanartContentType.video);
    expect(restored.sort, FanartSort.oldest);
    expect(restored.source, FanartSource.bilibili);
  });

  test('a dynamics query keeps its member and absolute time range', () async {
    final query = DynamicQuery(
      keyword: '演唱会',
      memberId: 'uid:123',
      type: DynamicType.video,
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 2, 1),
    );
    await repository.save(
      '跨年',
      ChannelFeed.dynamic,
      ChannelSpec.ofDynamic(query),
    );

    final restored = (await repository.channels()).single.spec.toDynamic();
    expect(restored.memberId, 'uid:123');
    expect(restored.type, DynamicType.video);
    // The same instants, now in local time (whose calendar fields the
    // picker and the request read).
    expect(restored.from!.isAtSameMomentAs(DateTime.utc(2026, 1, 1)), isTrue);
    expect(restored.to!.isAtSameMomentAs(DateTime.utc(2026, 2, 1)), isTrue);
    expect(restored.from!.isUtc, isFalse);
    expect(
      restored.isServerAcceptable,
      isTrue,
      reason: 'a restored range must still be ordered',
    );
  });

  test('picked days come back as the same days in local time', () {
    // What the date picker produces: local midnights, `to` exclusive.
    final query = DynamicQuery(
      from: DateTime(2026, 9, 20),
      to: DateTime(2026, 9, 23),
    );
    final restored = ChannelSpec(
      version: ChannelSpec.currentVersion,
      values: ChannelSpec.ofDynamic(query).values,
    ).toDynamic();
    expect(restored.from, DateTime(2026, 9, 20));
    expect(restored.to, DateTime(2026, 9, 23));
  });

  test('an empty query round trips without inventing filters', () async {
    await repository.save(
      '全部',
      ChannelFeed.dynamic,
      ChannelSpec.ofDynamic(const DynamicQuery()),
    );
    final restored = (await repository.channels()).single.spec.toDynamic();
    expect(restored.memberId, isNull);
    expect(restored.type, isNull);
    expect(restored.from, isNull);
    expect(restored.to, isNull);
  });

  test(
    'saving the same name in one feed updates it and keeps one row',
    () async {
      final first = await repository.save(
        '我的频道',
        ChannelFeed.fanart,
        ChannelSpec.ofFanart(const FanartQuery(keyword: '旧')),
      );
      final second = await repository.save(
        '我的频道',
        ChannelFeed.fanart,
        ChannelSpec.ofFanart(const FanartQuery(keyword: '新')),
      );
      final channels = await repository.channels();
      expect(channels, hasLength(1));
      expect(channels.single.spec.toFanart().keyword, '新');
      expect(
        second,
        first,
        reason: 'the surviving row keeps its id, so save must report that id',
      );
    },
  );

  test('the same name in a different feed is a separate channel', () async {
    await repository.save(
      '同名',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery()),
    );
    await repository.save(
      '同名',
      ChannelFeed.dynamic,
      ChannelSpec.ofDynamic(const DynamicQuery()),
    );
    expect(await repository.channels(), hasLength(2));
    expect(await repository.channels(feed: ChannelFeed.fanart), hasLength(1));
  });

  test(
    'a spec from a newer version is skipped, not partially applied',
    () async {
      await repository.save(
        '未来',
        ChannelFeed.fanart,
        ChannelSpec.ofFanart(const FanartQuery()),
      );
      db.database.execute('UPDATE saved_channels SET spec_version=99');
      expect(
        await repository.channels(),
        isEmpty,
        reason:
            'running a half-understood spec would query more than was saved',
      );
    },
  );

  test('a blank or over-long name is rejected', () async {
    for (final name in ['', '   ', 'x' * 65]) {
      expect(
        () => repository.save(
          name,
          ChannelFeed.fanart,
          ChannelSpec.ofFanart(const FanartQuery()),
        ),
        throwsA(isA<StorageFailure>()),
      );
    }
  });

  test('rename and remove affect only the target channel', () async {
    final id = await repository.save(
      '甲',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery()),
    );
    await repository.save(
      '乙',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery()),
    );
    await repository.rename(id, '甲改');
    expect(
      (await repository.channels()).map((c) => c.name),
      containsAll(['甲改', '乙']),
    );
    await repository.remove(id);
    expect((await repository.channels()).single.name, '乙');
  });

  test('an unknown enum value falls back instead of failing to open', () async {
    await repository.save(
      '容错',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery()),
    );
    db.database.execute(
      '''UPDATE saved_channels SET spec='{"keyword":"x","category":"gone"}' ''',
    );
    final restored = (await repository.channels()).single.spec.toFanart();
    expect(restored.keyword, 'x');
    expect(restored.category, FanartCategory.all);
  });

  test('changes notify after a write', () async {
    final seen = <int>[];
    final subscription = repository.changes.listen(seen.add);
    addTearDown(subscription.cancel);
    await repository.save(
      '频道',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, isNotEmpty);
  });
}
