import 'dart:convert';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/library/application/content_snapshots.dart';
import 'package:asasfans_next/features/library/data/library_codec.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'common signed CDN parameters and fragment credentials are not durable URLs',
    () {
      for (final key in [
        'X-Amz-Signature',
        'X-Goog-Credential',
        'OSSAccessKeyId',
        'q-sign-time',
        'Policy',
      ]) {
        expect(
          LibraryCodec.publicUri('https://image.example/a?$key=fixture'),
          isNull,
        );
      }
      expect(
        LibraryCodec.publicUri('https://example.com/a#access_token=fixture'),
        isNull,
      );
      expect(
        LibraryCodec.publicUri('https://example.com/watch?v=123#part1'),
        isNotNull,
      );
    },
  );
  test(
    'whitelisted snapshots exclude media URLs, credentials and signed image locations',
    () {
      final item = FanartItem(
        identity: const ContentIdentity(
          source: ContentSource.bilibiliDynamic,
          value: '10000000000000000001',
        ),
        text: '正文',
        authorName: '作者',
        authorUid: '123',
        images: [
          Uri.parse('https://image.example/stable.jpg'),
          Uri.parse('https://image.example/transient?token=fixture-secret'),
        ],
        kind: FanartKind.fanart,
        contentType: FanartContentType.video,
        category: FanartCategory.amv,
        characterTags: const [],
        mediaUrl: Uri.parse(
          'https://media.example/secret?deadline=1&sign=fixture-sign',
        ),
      );
      final encoded = LibraryCodec.encodeContent(ContentSnapshots.fanart(item));
      expect(encoded, isNot(contains('fixture-secret')));
      expect(encoded, isNot(contains('fixture-sign')));
      expect(encoded, isNot(contains('mediaUrl')));
      final restored = LibraryCodec.decodeContent(encoded);
      expect(restored.images, [Uri.parse('https://image.example/stable.jpg')]);
      expect(restored.identity.value, '10000000000000000001');
      expect(
        restored.sourceUrl.toString(),
        'https://t.bilibili.com/10000000000000000001',
      );
    },
  );
  test(
    'unknown versions and oversized encoded bodies fail before storing an unreadable snapshot',
    () {
      expect(
        () => LibraryCodec.decodeContent('{"v":99}'),
        throwsA(isA<StorageFailure>()),
      );
      final item = ContentSnapshot(
        identity: const ContentIdentity(
          source: ContentSource.bilibiliDynamic,
          value: '1',
        ),
        title: '标题',
        body: '\u0001' * 200000,
        authorName: '作者',
      );
      expect(
        () => LibraryCodec.encodeContent(item),
        throwsA(isA<StorageFailure>()),
      );
    },
  );
  test(
    'all-day, occurrence, cancellation and full metadata survive roundtrip',
    () {
      final event = CalendarEvent(
        uid: 'a/b',
        recurrenceId: 'DATE:20261231',
        sequence: 3,
        title: '纪念日',
        start: DateTime.utc(2026, 12, 31),
        end: DateTime.utc(2027, 1, 2),
        allDay: true,
        status: EventStatus.cancelled,
        members: const ['嘉然'],
        description: '详细简介',
        location: '地点',
        categories: const ['纪念'],
        sourceUrl: Uri.parse('https://example.com/event'),
      );
      final encoded = LibraryCodec.encodeEvent(event);
      final restored = LibraryCodec.decodeEvent(encoded);
      expect(restored.start, event.start);
      expect(restored.end, event.end);
      expect(restored.allDay, isTrue);
      expect(restored.isCancelled, isTrue);
      expect(restored.recurrenceId, event.recurrenceId);
      expect(restored.sequence, 3);
      expect(restored.description, '详细简介');
      expect(restored.members, ['嘉然']);
      final raw = jsonDecode(encoded) as Map<String, dynamic>;
      raw['start'] = '2026-12-31T00:00:00.000001Z';
      expect(
        () => LibraryCodec.decodeEvent(jsonEncode(raw)),
        throwsA(isA<StorageFailure>()),
      );
    },
  );
}
