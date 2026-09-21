import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/handoff/application/handoff_coordinator.dart';
import 'package:asasfans_next/features/handoff/data/sqlite_return_store.dart';
import 'package:asasfans_next/features/handoff/domain/return_context.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

class _Links implements ExternalLinkService {
  bool accept = true;
  Object? error;
  final opened = <Uri>[];
  Completer<void>? gate;
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return accept;
  }
}

/// Fails writes so the "storage is down" path can be exercised.
class _BrokenStore implements ReturnStore {
  final saved = <ReturnContext>[];
  @override
  Future<void> save(ReturnContext context) {
    saved.add(context);
    return Future.error(const StorageFailure(StorageFailureKind.unavailable));
  }

  @override
  Future<ReturnContext?> read() =>
      Future.error(const StorageFailure(StorageFailureKind.unavailable));
  @override
  Future<ReturnContext?> consume(String sessionId) =>
      Future.error(const StorageFailure(StorageFailureKind.unavailable));
  @override
  Future<void> clear() =>
      Future.error(const StorageFailure(StorageFailureKind.unavailable));
}

const _video = ContentIdentity(
  source: ContentSource.bilibiliVideo,
  value: 'BV1xx411c7mD',
);

void main() {
  late MemoryLocalDatabase db;
  late SqliteReturnStore store;
  late _Links links;
  late HandoffCoordinator coordinator;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteReturnStore(db);
    links = _Links();
    coordinator = HandoffCoordinator(
      links,
      store,
      clock: () => DateTime.utc(2026, 9, 22),
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  Future<HandoffResult> handoff({Uri? url}) => coordinator.open(
    url: url ?? BilibiliTargets.video('BV1xx411c7mD'),
    target: ReturnTarget.contentChannel,
    channel: 'fanart',
    query: const {'keyword': '生日'},
    anchor: const ReturnAnchor(identity: _video, offset: 1200),
    openedContent: _video,
  );

  group('targets are built from verified ids', () {
    test('a valid BVID becomes the standard page, with an optional part', () {
      expect(
        BilibiliTargets.video('BV1xx411c7mD').toString(),
        'https://www.bilibili.com/video/BV1xx411c7mD',
      );
      expect(
        BilibiliTargets.video('BV1xx411c7mD', part: 2).toString(),
        'https://www.bilibili.com/video/BV1xx411c7mD?p=2',
      );
    });

    test('a malformed id yields no target rather than a guessed URL', () {
      for (final id in [
        '',
        'BV1xx',
        'av12345',
        'BV1xx411c7mD/../evil',
        'BV1xx411c7m!',
      ]) {
        expect(BilibiliTargets.video(id), isNull, reason: id);
      }
      expect(BilibiliTargets.dynamicPost('not-digits'), isNull);
      expect(
        BilibiliTargets.dynamicPost('123').toString(),
        'https://t.bilibili.com/123',
      );
    });

    test('a part number below the first page is dropped, not sent', () {
      expect(
        BilibiliTargets.video('BV1xx411c7mD', part: 0).toString(),
        'https://www.bilibili.com/video/BV1xx411c7mD',
      );
    });
  });

  test('an accepted open saves the picking context before leaving', () async {
    final result = await handoff();
    expect(result.accepted, isTrue);
    expect(result.contextSaved, isTrue);
    expect(links.opened.single.host, 'www.bilibili.com');

    final saved = (await coordinator.pending())!;
    expect(saved.sessionId, result.sessionId);
    expect(saved.target, ReturnTarget.contentChannel);
    expect(saved.channel, 'fanart');
    expect(saved.query, {'keyword': '生日'});
    expect(saved.anchor!.identity, _video);
    expect(saved.anchor!.offset, 1200);
    expect(saved.openedContent, _video);
    expect(saved.consumed, isFalse);
  });

  test('a second tap while one is in flight does not open twice', () async {
    links.gate = Completer<void>();
    final first = handoff();
    await Future<void>.delayed(Duration.zero);
    final second = await handoff();
    expect(second.outcome, HandoffOutcome.duplicate);
    links.gate!.complete();
    expect((await first).accepted, isTrue);
    expect(links.opened, hasLength(1));
  });

  test('a target this app will not build is refused before dispatch', () async {
    final result = await coordinator.open(
      url: BilibiliTargets.video('not-a-bvid'),
      target: ReturnTarget.contentChannel,
      channel: 'fanart',
    );
    expect(result.outcome, HandoffOutcome.rejected);
    expect(links.opened, isEmpty);
    expect(await coordinator.pending(), isNull);
  });

  test('a refused launch leaves no session and no false success', () async {
    links.accept = false;
    final result = await handoff();
    expect(result.outcome, HandoffOutcome.failed);
    expect(result.accepted, isFalse);
    expect(
      await coordinator.pending(),
      isNull,
      reason: 'nothing was handed over, so there is nothing to return from',
    );
  });

  test('a throwing launcher is a failure, not a crash', () async {
    links.error = Exception('platform channel died');
    await expectLater(handoff(), throwsA(isA<Exception>()));
    // The busy flag must not be left stuck, or every later handoff is refused.
    expect(coordinator.busy, isFalse);
    links.error = null;
    expect((await handoff()).accepted, isTrue);
  });

  test('a failed context write still lets the user watch', () async {
    final broken = _BrokenStore();
    final degraded = HandoffCoordinator(links, broken);
    addTearDown(degraded.dispose);
    final result = await degraded.open(
      url: BilibiliTargets.video('BV1xx411c7mD'),
      target: ReturnTarget.contentChannel,
      channel: 'fanart',
    );
    expect(result.accepted, isTrue);
    expect(
      result.contextSaved,
      isFalse,
      reason: 'the caller can say the cold return is not guaranteed',
    );
    expect(links.opened, hasLength(1));
  });

  test('one session is consumed exactly once', () async {
    final result = await handoff();
    final first = await coordinator.consume(result.sessionId!);
    expect(first, isNotNull);
    expect(first!.channel, 'fanart');
    expect(
      await coordinator.consume(result.sessionId!),
      isNull,
      reason: 'a repeated callback must not restore twice',
    );
    expect(await coordinator.pending(), isNull);
  });

  test('a stale session id cannot consume the current session', () async {
    final stale = await handoff();
    await coordinator.consume(stale.sessionId!);
    final current = await handoff();
    expect(
      await coordinator.consume(stale.sessionId!),
      isNull,
      reason: 'an old callback must not claim the new trip',
    );
    final consumed = await coordinator.consume(current.sessionId!);
    expect(consumed!.sessionId, current.sessionId);
  });

  test('starting a new handoff replaces the previous session', () async {
    final first = await handoff();
    final second = await handoff();
    expect(second.sessionId, isNot(first.sessionId));
    expect((await coordinator.pending())!.sessionId, second.sessionId);
    expect(await coordinator.consume(first.sessionId!), isNull);
  });

  test('ending a session leaves nothing for a later resume', () async {
    await handoff();
    await coordinator.end();
    expect(await coordinator.pending(), isNull);
  });

  test('a session survives a new store over the same database', () async {
    final result = await handoff();
    // Stands in for a cold start: same file, new objects.
    final reopened = HandoffCoordinator(links, SqliteReturnStore(db));
    addTearDown(reopened.dispose);
    final restored = await reopened.consume(result.sessionId!);
    expect(restored, isNotNull);
    expect(restored!.query, {'keyword': '生日'});
    expect(restored.anchor!.identity, _video);
  });

  test(
    'an unreadable stored position costs the anchor, not the return',
    () async {
      await handoff();
      db.database.execute(
        "UPDATE return_sessions SET anchor='{oops', query='['",
      );
      final context = (await coordinator.pending())!;
      expect(context.target, ReturnTarget.contentChannel);
      expect(context.channel, 'fanart');
      expect(context.anchor?.identity, isNull);
      expect(context.query, isNull);
    },
  );

  test('a broken store never throws out of the coordinator', () async {
    final degraded = HandoffCoordinator(links, _BrokenStore());
    addTearDown(degraded.dispose);
    expect(await degraded.pending(), isNull);
    expect(await degraded.consume('whatever'), isNull);
    await degraded.end();
  });
}
