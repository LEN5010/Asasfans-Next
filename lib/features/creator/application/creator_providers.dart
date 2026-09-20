import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bilibili_providers.dart';
import '../data/bili_creator_repository.dart';
import '../domain/creator_repository.dart';
import 'creator_controller.dart';

export '../../../app/bilibili_providers.dart' show biliReadGatewayProvider;

final creatorRepositoryProvider = Provider<CreatorRepository>(
  (ref) => BiliCreatorRepository(ref.watch(biliReadGatewayProvider)),
);
final creatorControllerProvider = ChangeNotifierProvider.autoDispose
    .family<CreatorController, String>((ref, mid) {
      final controller = CreatorController(
        ref.watch(creatorRepositoryProvider),
        mid,
      );
      unawaited(controller.refresh());
      return controller;
    });
