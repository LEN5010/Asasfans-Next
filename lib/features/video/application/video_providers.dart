import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bilibili_providers.dart';
import '../data/bili_video_repository.dart';
import '../domain/video_detail.dart';
import 'video_detail_controller.dart';

final videoRepositoryProvider = Provider<VideoRepository>(
  (ref) => BiliVideoRepository(ref.watch(biliReadGatewayProvider)),
);
final videoDetailProvider = ChangeNotifierProvider.autoDispose
    .family<VideoDetailController, String>((ref, bvid) {
      final controller = VideoDetailController(
        ref.watch(videoRepositoryProvider),
        bvid,
      );
      unawaited(controller.refresh());
      return controller;
    });
