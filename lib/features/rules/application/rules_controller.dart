import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_failure.dart';
import '../domain/content_rules.dart';
import '../domain/rules_repository.dart';

class RulesState {
  const RulesState({
    this.snapshot,
    this.loading = true,
    this.failure,
    this.epoch = 0,
    required this.now,
  });
  final RulesSnapshot? snapshot;
  final bool loading;
  final Object? failure;
  final DateTime now;
  final int epoch;
  bool get ready => snapshot != null && !loading && failure == null;
}

class RulesController extends StateNotifier<RulesState> {
  RulesController(
    this._repository,
    Stream<int> subscriptionChanges, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(RulesState(now: (clock ?? DateTime.now)())) {
    _listeners = [
      _repository.changes.listen((_) => unawaited(reload())),
      subscriptionChanges.listen((_) => unawaited(reload())),
    ];
    unawaited(reload());
  }
  final RulesRepository _repository;
  final DateTime Function() _clock;
  late final List<StreamSubscription<int>> _listeners;
  Timer? _expiry;
  Future<void>? _running;
  bool _queued = false;
  String? _fingerprint;

  Future<void> reload() {
    if (!mounted) return Future.value();
    if (_running != null) {
      _queued = true;
      return _running!;
    }
    final completer = Completer<void>();
    _running = completer.future;
    unawaited(
      _read().whenComplete(() {
        _running = null;
        completer.complete();
      }),
    );
    return completer.future;
  }

  Future<void> _read() async {
    _expiry?.cancel();
    state = RulesState(
      snapshot: state.snapshot,
      now: _clock(),
      epoch: state.epoch,
    );
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        _queued = false;
        final snapshot = await _repository.load();
        if (!mounted) return;
        if (!_queued) {
          _publish(snapshot);
          return;
        }
      }
      throw const StorageFailure(StorageFailureKind.changed);
    } catch (error) {
      if (mounted) {
        state = RulesState(
          snapshot: state.snapshot,
          loading: false,
          failure: error,
          now: _clock(),
          epoch: state.epoch,
        );
      }
    }
  }

  Future<RulesState> ready() async {
    if (!mounted) throw const StorageFailure(StorageFailureKind.closed);
    if (!state.ready) {
      await (_running ?? reload());
      if (!mounted) throw const StorageFailure(StorageFailureKind.closed);
      if (!state.ready) {
        throw state.failure ??
            const StorageFailure(StorageFailureKind.unavailable);
      }
    }
    final now = _clock();
    if (state.snapshot!.rules.any(
      (rule) => rule.activeAt(now) != rule.activeAt(state.now),
    )) {
      _publish(state.snapshot!);
    }
    return state;
  }

  void reconsiderExpiry() {
    if (mounted && state.ready) _publish(state.snapshot!);
  }

  void _publish(RulesSnapshot snapshot) {
    final now = _clock();
    final fingerprint = jsonEncode([
      snapshot.prioritizeSubscribed,
      snapshot.subscriptions.toList()..sort(),
      for (final rule in snapshot.rules)
        [rule.id, rule.changeToken, rule.activeAt(now)],
    ]);
    final epoch = state.epoch + (_fingerprint == fingerprint ? 0 : 1);
    _fingerprint = fingerprint;
    state = RulesState(
      snapshot: snapshot,
      loading: false,
      now: now,
      epoch: epoch,
    );
    _expiry?.cancel();
    final expiries =
        snapshot.rules
            .where(
              (r) =>
                  r.draft.enabled &&
                  r.draft.expiresAt != null &&
                  r.draft.expiresAt!.isAfter(now),
            )
            .map((r) => r.draft.expiresAt!)
            .toList()
          ..sort();
    if (expiries.isNotEmpty) {
      final delay = expiries.first.difference(now);
      _expiry = Timer(
        delay > const Duration(days: 1) ? const Duration(days: 1) : delay,
        reconsiderExpiry,
      );
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    for (final listener in _listeners) {
      unawaited(listener.cancel());
    }
    super.dispose();
  }
}
