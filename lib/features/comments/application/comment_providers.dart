import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bilibili_providers.dart';
import '../domain/comments.dart';
import '../data/bili_comment_repository.dart';
import 'comment_controller.dart';

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => BiliCommentRepository(ref.watch(biliReadGatewayProvider)),
);
final commentControllerProvider = ChangeNotifierProvider.autoDispose
    .family<CommentController, CommentQuery>((ref, query) {
      final controller = CommentController(
        ref.watch(commentRepositoryProvider),
        query,
      );
      unawaited(controller.refresh());
      return controller;
    });
