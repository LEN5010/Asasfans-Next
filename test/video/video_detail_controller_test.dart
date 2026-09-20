import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/video/application/video_detail_controller.dart';
import 'package:asasfans_next/features/video/domain/video_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  test(
    'part selection is keyed by CID across refresh and independent of responsive widgets',
    () async {
      final repository = OfflineVideoRepository();
      final controller = VideoDetailController(repository, fixtureBvid);
      addTearDown(controller.dispose);
      await controller.refresh();
      controller.selectPart('802');
      expect(controller.selectedPart?.number, 2);
      final value = videoDetailFixture();
      repository.respond = (_) async => VideoDetail(
        video: value.video,
        aid: value.aid,
        parts: [
          const VideoPart(cid: '802', number: 1, title: 'reordered'),
          const VideoPart(cid: '801', number: 2, title: 'other'),
        ],
      );
      await controller.refresh();
      expect(controller.selectedPart?.cid, '802');
      expect(controller.selectedPart?.number, 1);
      controller.selectPart('nonexistent');
      expect(controller.selectedPart?.cid, '802');
      repository.respond = (_) async => VideoDetail(
        video: value.video,
        aid: value.aid,
        parts: [const VideoPart(cid: '801', number: 1, title: 'remaining')],
      );
      await controller.refresh();
      expect(controller.selectedPart?.cid, '801');
    },
  );
  test(
    'refresh cancellation and late completion cannot replace a newer view',
    () async {
      final repository = OfflineVideoRepository();
      final controller = VideoDetailController(repository, fixtureBvid);
      addTearDown(controller.dispose);
      final pending = Completer<VideoDetail>();
      RequestCancellation? request;
      repository.respond = (cancel) {
        request = cancel;
        return pending.future;
      };
      final first = controller.refresh();
      repository.respond = null;
      await controller.refresh();
      expect(request!.isCancelled, isTrue);
      final accepted = controller.detail;
      pending.completeError(const ApiFailure(ApiFailureKind.offline));
      await first;
      expect(controller.detail, same(accepted));
      expect(controller.failure, isNull);
      expect(controller.loading, isFalse);
    },
  );
  test(
    'offline retains metadata, explicit visibility revocation removes it',
    () async {
      final repository = OfflineVideoRepository();
      final controller = VideoDetailController(repository, fixtureBvid);
      addTearDown(controller.dispose);
      await controller.refresh();
      repository.respond = (_) async =>
          throw const ApiFailure(ApiFailureKind.offline);
      await controller.refresh();
      expect(controller.detail, isNotNull);
      repository.respond = (_) async =>
          throw const ApiFailure(ApiFailureKind.forbidden);
      await controller.refresh();
      expect(controller.detail, isNull);
      expect(controller.failure?.kind, ApiFailureKind.forbidden);
    },
  );
  test('disposed detail cancels and ignores its response', () async {
    final pending = Completer<VideoDetail>();
    RequestCancellation? request;
    final repository = OfflineVideoRepository()
      ..respond = (cancel) {
        request = cancel;
        return pending.future;
      };
    final controller = VideoDetailController(repository, fixtureBvid);
    final load = controller.refresh();
    controller.dispose();
    expect(request!.isCancelled, isTrue);
    pending.complete(videoDetailFixture());
    await load;
    expect(controller.detail, isNull);
  });
}
