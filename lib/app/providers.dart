import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_environment.dart';
import '../core/network/public_api_client.dart';
import '../core/platform/external_link_service.dart';

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => AppEnvironment.fromDefines(),
);

final publicApiClientProvider = Provider<PublicApiClient>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: environment.dynamicApiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
      followRedirects: false,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return PublicApiClient(dio);
});

final externalLinkServiceProvider = Provider<ExternalLinkService>(
  (ref) => const SystemExternalLinkService(),
);
