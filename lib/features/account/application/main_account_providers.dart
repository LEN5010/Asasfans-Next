import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/config/app_version.dart';
import '../../../core/storage/storage_providers.dart';
import '../../library/application/library_providers.dart';
import '../domain/main_account.dart';
import '../data/main_account_api.dart';
import '../data/main_account_vault.dart';
import '../data/tappo_api.dart';
import 'main_account_controller.dart';
import 'collection_sync_controller.dart';

final mainAccountApiProvider = Provider<MainAccountApi>((ref) {
  final base = ref.watch(appEnvironmentProvider).dynamicApiBaseUrl;
  final dio = Dio(
    BaseOptions(
      baseUrl: base.toString(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json', 'User-Agent': appUserAgent},
      followRedirects: false,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return HttpMainAccountApi(dio, base);
});
final mainCredentialVaultProvider = Provider<MainCredentialVault>(
  (ref) => MainAccountVault(),
);
final mainAccountControllerProvider =
    ChangeNotifierProvider<MainAccountController>((ref) {
      final api = ref.watch(mainAccountApiProvider);
      final controller = MainAccountController(
        api,
        ref.watch(mainCredentialVaultProvider),
        ref.watch(localDatabaseProvider),
      );
      unawaited(controller.restore());
      return controller;
    });
final collectionOwnerProvider = Provider<String>(
  (ref) => ref.watch(
    mainAccountControllerProvider.select(
      (state) =>
          state.session?.user.email == null ? 'local' : state.session!.user.id,
    ),
  ),
);
final collectionSyncProvider =
    ChangeNotifierProvider<CollectionSyncController?>((ref) {
      final owner = ref.watch(collectionOwnerProvider);
      if (owner == 'local') return null;
      final controller = CollectionSyncController(
        ref.read(mainAccountControllerProvider),
        ref.watch(localDatabaseProvider),
        ref.watch(libraryRepositoryProvider),
      );
      final lifecycle = AppLifecycleListener(
        onResume: () => controller.schedule(delay: Duration.zero),
      );
      ref.onDispose(lifecycle.dispose);
      controller.schedule(delay: Duration.zero);
      return controller;
    });

final tappoApiProvider = Provider<TappoApi>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json', 'User-Agent': appUserAgent},
      followRedirects: false,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return TappoApi(dio);
});

/// The signed-in account's AsoulTappo save; null when it has none.
final tappoProgressProvider = FutureProvider.autoDispose<TappoProgress?>((ref) {
  final token = ref.watch(
    mainAccountControllerProvider.select((state) => state.session?.token),
  );
  if (token == null) return null;
  return ref.watch(tappoApiProvider).progress(token);
});
