import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_version.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/local_date_provider.dart';
import '../data/operations_repository.dart';
import '../domain/app_operations.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>((ref) {
  final events = Dio(
    BaseOptions(
      baseUrl: ref.watch(appEnvironmentProvider).dynamicApiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json', 'User-Agent': appUserAgent},
      followRedirects: false,
    ),
  );
  ref.onDispose(() => events.close(force: true));
  return OperationsRepository(
    ref.watch(publicApiClientProvider),
    ref.watch(localDatabaseProvider),
    events,
  );
});

/// Whether this window is taller than wide, which picks the poster.
bool get tallWindow {
  final size =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
  return size.height >= size.width;
}

final operationsProvider =
    StateNotifierProvider<OperationsController, OperationsState>((ref) {
      final controller = OperationsController(
        ref.watch(operationsRepositoryProvider),
        ref.watch(currentTimeProvider),
      );
      final lifecycle = AppLifecycleListener(onResume: controller.resume);
      ref.onDispose(lifecycle.dispose);
      return controller;
    });

class OperationsState {
  const OperationsState({
    this.data = const AppOperations(),
    this.ready = false,
    this.fresh = false,
    this.loading = false,
    required this.now,
  });
  final AppOperations data;
  final bool ready, fresh, loading;
  final DateTime now;
  static String get platform => defaultTargetPlatform.name.toLowerCase();
  List<AppOperation> get campaigns => data.campaigns
      .where((item) => item.availableOn(platform) && item.activeAt(now))
      .toList();
  List<AppOperation> get announcements => data.announcements
      .where((item) => item.availableOn(platform) && item.activeAt(now))
      .toList();

  /// Every announcement served for this platform, ended ones included,
  /// newest first; scheduled ones appear once they start.
  List<AppOperation> get announcementHistory =>
      data.announcements
          .where(
            (item) =>
                item.availableOn(platform) && !now.isBefore(item.startsAt),
          )
          .toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
}

class OperationsController extends StateNotifier<OperationsState> {
  OperationsController(this.repository, this.clock)
    : super(OperationsState(now: clock())) {
    initialized = _load();
  }
  final OperationsRepository repository;
  final DateTime Function() clock;
  late final Future<void> initialized;
  final Map<String, String> _local = {};
  Timer? _boundary;
  Future<void>? _fetching;
  bool _preloading = false;
  DateTime? _fetchedAt;
  final _impressions = <String>{};

  Future<void> _load() async {
    AppOperations data = const AppOperations();
    try {
      _local.addAll(await repository.readLocal());
      if (_local['cache'] != null) {
        data = AppOperations.fromJson(
          jsonDecode(_local['cache']!) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Operations are optional; a local read failure must not block the app.
    }
    if (!mounted) return;
    state = OperationsState(
      data: data,
      ready: true,
      loading: true,
      now: clock(),
    );
    _arm();
    unawaited(refresh());
  }

  Future<void> refresh() =>
      _fetching ??= _refresh().whenComplete(() => _fetching = null);

  Future<void> _refresh() async {
    if (mounted) {
      state = OperationsState(
        data: state.data,
        ready: state.ready,
        fresh: state.fresh,
        loading: true,
        now: clock(),
      );
    }
    final Map<String, dynamic> json;
    final AppOperations data;
    try {
      json = await repository.fetch();
      data = AppOperations.fromJson(json);
    } catch (_) {
      if (mounted) {
        state = OperationsState(data: state.data, ready: true, now: clock());
      }
      return;
    }
    if (!mounted) return;
    _fetchedAt = clock();
    state = OperationsState(data: data, ready: true, fresh: true, now: clock());
    _arm();
    try {
      await repository.saveLocal('cache', jsonEncode(json));
    } catch (_) {
      // The fetched content remains usable when its cache cannot be saved.
    }
    if (!mounted) return;
    unawaited(_preloadSplash());
  }

  Future<void> _preloadSplash() async {
    if (_preloading) return;
    final upcoming =
        state.data.campaigns
            .where(
              (item) =>
                  item.availableOn(OperationsState.platform) &&
                  item.endsAt.isAfter(clock()) &&
                  item.splash != null &&
                  !seen('splashOff', item.id),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (upcoming.isEmpty) return;
    _preloading = true;
    try {
      _local['image'] = await repository.cacheSplash(
        upcoming.first.splash!.pick(tall: tallWindow)!.url,
        _local['image'],
      );
    } catch (_) {
      // A failed preload only means there is no poster for the next launch.
    } finally {
      _preloading = false;
    }
  }

  void resume() {
    if (!mounted || !state.ready) return;
    _tick();
    if (_fetchedAt == null ||
        clock().difference(_fetchedAt!) >= const Duration(minutes: 5)) {
      unawaited(refresh());
    }
  }

  void _tick() {
    state = OperationsState(
      data: state.data,
      ready: state.ready,
      fresh: state.fresh,
      loading: state.loading,
      now: clock(),
    );
    _arm();
  }

  void _arm() {
    _boundary?.cancel();
    final now = clock();
    final times = [
      for (final item in [
        ...state.data.campaigns,
        ...state.data.announcements,
      ]) ...[item.startsAt, item.endsAt],
    ].where((time) => time.isAfter(now)).toList()..sort();
    if (times.isNotEmpty) _boundary = Timer(times.first.difference(now), _tick);
  }

  bool seen(String kind, String id) =>
      (_local[kind] ?? '').split('\n').contains(id);

  Future<void> markSeen(String kind, String id) async {
    final ids = {
      if (_local[kind]?.isNotEmpty ?? false) ..._local[kind]!.split('\n'),
      id,
    }.toList();
    final value = ids.skip(ids.length > 100 ? ids.length - 100 : 0).join('\n');
    await repository.saveLocal(kind, value);
    _local[kind] = value;
  }

  bool collapsed(String id) => seen('collapsed', id);

  bool read(String id) => seen('read', id);
  int get unread => state.announcements.where((item) => !read(item.id)).length;

  Future<void> markRead(String id) async {
    if (read(id)) return;
    await markSeen('read', id);
    if (mounted) _tick();
  }

  /// Anonymous counts for the operations page, best effort: a lost report
  /// changes nothing for the reader. Impressions count once per run.
  void report(String surface, String itemId, String event) {
    if (event == 'impression' && !_impressions.add('$surface:$itemId')) return;
    unawaited(
      repository.report(surface, itemId, event).catchError((Object _) {}),
    );
  }

  Future<void> collapse(String id) async {
    await markSeen('collapsed', id);
    if (mounted) _tick();
  }

  String get todayKey {
    final now = clock().toLocal();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get splashSeenToday => _local['splashDay'] == todayKey;
  Future<void> markSplashSeen() async {
    final day = todayKey;
    await repository.saveLocal('splashDay', day);
    _local['splashDay'] = day;
  }

  /// The poster cached for this window's shape, else the other one.
  Future<File?> cachedSplash(
    OperationSplash splash, {
    required bool tall,
  }) async {
    final first = splash.pick(tall: tall)!;
    final other = splash.pick(tall: !tall)!;
    return await repository.cachedSplash(first.url, _local['image']) ??
        (other == first
            ? null
            : await repository.cachedSplash(other.url, _local['image']));
  }

  @override
  void dispose() {
    _boundary?.cancel();
    super.dispose();
  }
}
