import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/storage/storage_failure.dart';
import '../../creator/domain/creator_repository.dart';
import '../domain/subscription_updates.dart';
import 'subscription_pager.dart';

class SubscriptionFeedController extends ChangeNotifier {
  SubscriptionFeedController(
    this._source,
    this._store,
    Stream<int> subscriptionChanges,
  ) {
    _listeners = [
      subscriptionChanges.listen((_) {
        if (!_closed) unawaited(refresh());
      }),
      _store.changes.listen((_) {
        if (!_closed) unawaited(reloadReads());
      }),
    ];
  }
  final CreatorRepository _source;
  final SubscriptionUpdateStore _store;
  late final List<StreamSubscription<int>> _listeners;
  SubscriptionRoster? _roster;
  SubscriptionPager? _pager;
  SubscriptionSlice? _pending;
  RequestCancellation? _request;
  int _generation = 0;
  int get generation => _generation;
  int _readVersion = 0;
  int _readReloadGeneration = 0;
  bool _closed = false;
  List<VideoSummary> items = const [];
  Map<String, bool> readStates = const {};
  List<SubscriptionIssue> issues = const [];
  bool initialized = false;
  bool loading = false;
  bool end = false;
  bool needsRefresh = false;
  bool savingReads = false;
  bool readsReady = false;
  int checkedCreators = 0;
  int totalCreators = 0;
  ApiFailure? failure;
  StorageFailure? storageFailure;
  StorageFailure? readFailure;
  bool get canLoadMore =>
      initialized &&
      !loading &&
      !end &&
      !needsRefresh &&
      failure == null &&
      storageFailure == null;

  Future<void> refresh() async {
    if (_closed) return;
    _request?.cancel();
    _generation++;
    _readReloadGeneration++;
    _roster = null;
    _pager = null;
    _pending = null;
    items = const [];
    issues = const [];
    readStates = const {};
    readsReady = false;
    readFailure = null;
    initialized = false;
    end = false;
    needsRefresh = false;
    loading = false;
    failure = null;
    storageFailure = null;
    checkedCreators = 0;
    totalCreators = 0;
    await _load();
  }

  Future<void> loadMore({bool automatic = false}) async {
    if (_closed ||
        loading ||
        (automatic && !canLoadMore) ||
        (end && _pending == null) ||
        needsRefresh) {
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    final generation = _generation;
    final cancellation = _request = RequestCancellation();
    loading = true;
    failure = null;
    storageFailure = null;
    notifyListeners();
    try {
      if (_roster == null) {
        final roster = await _store.roster();
        if (!_active(generation)) return;
        _roster = roster;
        totalCreators = roster.creators.length;
        _pager = SubscriptionPager(_source, roster);
      }
      final roster = _roster!;
      await _store.checkRoster(roster);
      if (!_active(generation)) return;
      if (_pending == null) {
        final slice = await _pager!.next(cancellation: cancellation);
        if (!_active(generation)) return;
        _pending = slice;
      }
      final slice = _pending!;
      final combined = [...items, ...slice.items];
      final reads = await _currentReads(combined.map((v) => v.identity.value));
      await _store.checkRoster(roster);
      if (!_active(generation)) return;
      items = List.unmodifiable(combined);
      readStates = Map.unmodifiable(reads);
      readsReady = true;
      readFailure = null;
      issues = slice.issues;
      checkedCreators = slice.checkedCreators;
      end = !slice.hasMore;
      failure = slice.pause;
      initialized = true;
      _pending = null;
    } catch (error) {
      if (!_active(generation)) return;
      if (error is StorageFailure) {
        storageFailure = error;
        if (error.kind == StorageFailureKind.changed) {
          needsRefresh = true;
          items = const [];
          readStates = const {};
          readsReady = false;
          _pending = null;
        }
      } else {
        failure = error is ApiFailure
            ? error
            : const ApiFailure(ApiFailureKind.invalidResponse);
      }
    } finally {
      if (_active(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryFailedCreators() async {
    if (_closed || loading) return;
    if (issues.any(
      (issue) => issue.failure.kind == ApiFailureKind.datasetChanged,
    )) {
      await refresh();
      return;
    }
    if (_pager == null || needsRefresh) {
      await refresh();
      return;
    }
    _request?.cancel();
    _generation++;
    _readReloadGeneration++;
    _pager!.rewindForRetry();
    _pending = null;
    items = const [];
    issues = const [];
    readStates = const {};
    readsReady = false;
    end = false;
    await _load();
  }

  Future<Map<String, bool>> _currentReads(Iterable<String> bvids) async {
    final ids = bvids.toList();
    for (var attempt = 0; attempt < 3; attempt++) {
      final version = _readVersion;
      final values = await _store.readStates(ids);
      if (version == _readVersion) return values;
    }
    throw const StorageFailure(StorageFailureKind.unavailable);
  }

  Future<void> reloadReads() async {
    if (_closed) return;
    final generation = _generation;
    final reload = ++_readReloadGeneration;
    final current = items;
    try {
      final values = await _currentReads(
        current.map((item) => item.identity.value),
      );
      if (!_active(generation) ||
          reload != _readReloadGeneration ||
          !identical(current, items)) {
        return;
      }
      readStates = Map.unmodifiable(values);
      readsReady = true;
      readFailure = null;
    } catch (error) {
      if (!_active(generation) || reload != _readReloadGeneration) return;
      readsReady = false;
      readFailure = error is StorageFailure
          ? error
          : const StorageFailure(StorageFailureKind.unavailable);
    }
    if (_active(generation)) notifyListeners();
  }

  Future<void> mark(Iterable<String> bvids, {required bool read}) async {
    if (_closed || savingReads) return;
    final ids = Set<String>.unmodifiable(bvids);
    savingReads = true;
    _readVersion++;
    notifyListeners();
    try {
      await _store.mark(ids, read: read);
      if (_closed) return;
      _readVersion++;
      readStates = Map.unmodifiable({
        ...readStates,
        for (final id in ids) id: read,
      });
    } finally {
      if (!_closed) {
        savingReads = false;
        notifyListeners();
      }
    }
  }

  bool _active(int generation) => !_closed && generation == _generation;
  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _request?.cancel();
    for (final listener in _listeners) {
      unawaited(listener.cancel());
    }
    super.dispose();
  }
}
