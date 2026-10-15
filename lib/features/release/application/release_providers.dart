import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_version.dart';
import '../data/github_release_source.dart';
import '../domain/app_release.dart';

final currentVersion = AppVersion.tryParse(appVersion)!;

final releaseSourceProvider = Provider<GithubReleaseSource>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/vnd.github+json'},
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return GithubReleaseSource(dio);
});

/// The last update check: null until one is asked for, then its progress
/// and result — the newer release, or null when this build is the newest.
final releaseCheckProvider =
    StateNotifierProvider<ReleaseCheck, AsyncValue<AppRelease?>?>(
      (ref) => ReleaseCheck(ref.watch(releaseSourceProvider)),
    );

class ReleaseCheck extends StateNotifier<AsyncValue<AppRelease?>?> {
  ReleaseCheck(this._source) : super(null);
  final GithubReleaseSource _source;
  Future<AppRelease?>? _running;

  /// A check already under way is joined, not repeated.
  Future<AppRelease?> check() =>
      _running ??= _check().whenComplete(() => _running = null);

  Future<AppRelease?> _check() async {
    state = const AsyncLoading();
    try {
      final newer = newerRelease(await _source.releases(), currentVersion);
      if (mounted) state = AsyncData(newer);
      return newer;
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
      rethrow;
    }
  }
}
