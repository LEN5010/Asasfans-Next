import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bilibili/bili_metadata_client.dart';
import '../core/bilibili/bili_media_transport.dart';
import '../core/time/shanghai_date_provider.dart';
import '../features/account/application/account_providers.dart';

/// Composition boundary shared by creator, video and comment repositories.
final biliReadGatewayProvider = Provider<BiliReadGateway>((ref) {
  ref.watch(accountSessionRevisionProvider);
  final account = ref.read(accountControllerProvider);
  final client = BiliMetadataClient(
    clock: ref.watch(currentTimeProvider),
    credentials: () => account.credentials,
  );
  ref.onDispose(client.close);
  return client;
});

final biliMediaTransportProvider = Provider<BiliMediaTransport>((ref) {
  ref.watch(accountSessionRevisionProvider);
  final account = ref.read(accountControllerProvider);
  final transport = BiliMediaTransport(
    clock: ref.watch(currentTimeProvider),
    credentials: () => account.credentials,
  );
  ref.onDispose(transport.close);
  return transport;
});
