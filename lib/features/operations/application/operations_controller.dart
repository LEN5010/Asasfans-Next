import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/local_date_provider.dart';
import '../data/operations_repository.dart';
import '../domain/app_operations.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => OperationsRepository(
    ref.watch(publicApiClientProvider),
    ref.watch(localDatabaseProvider),
  ),
);

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
  List<AppOperation> get campaigns =>
      data.campaigns.where((item) => item.activeAt(now)).toList();
  List<AppOperation> get announcements =>
      data.announcements.where((item) => item.activeAt(now)).toList();
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
                  item.enabled &&
                  item.endsAt.isAfter(clock()) &&
                  item.splashEnabled &&
                  item.splashImage != null &&
                  !seen('splashOff', item.id),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (upcoming.isEmpty) return;
    _preloading = true;
    try {
      _local['image'] = await repository.cacheSplash(
        upcoming.first,
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

  Future<File?> cachedSplash(AppOperation item) =>
      repository.cachedSplash(item, _local['image']);

  @override
  void dispose() {
    _boundary?.cancel();
    super.dispose();
  }
}
