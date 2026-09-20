import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_failure.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/sqlite_preferences_repository.dart';
import '../domain/app_preferences.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => SqlitePreferencesRepository(ref.watch(localDatabaseProvider)),
);
final preferencesControllerProvider =
    StateNotifierProvider<PreferencesController, PreferencesState>(
      (ref) => PreferencesController(ref.watch(preferencesRepositoryProvider)),
    );

class PreferencesState {
  const PreferencesState({
    this.values = const AppPreferences(),
    this.ready = false,
    this.loading = false,
    this.saving = false,
    this.failure,
  });
  final AppPreferences values;
  final bool ready;
  final bool loading;
  final bool saving;
  final StorageFailure? failure;
  bool get canEdit => ready && !loading && !saving;
}

class PreferencesController extends StateNotifier<PreferencesState> {
  PreferencesController(this._repository)
    : super(const PreferencesState(loading: true)) {
    unawaited(reload());
  }
  final PreferencesRepository _repository;
  Future<void> _writes = Future.value();
  int _generation = 0;
  int _pendingWrites = 0;

  Future<void> reloadAfterExternalWrite() async {
    // A previously queued preference write must not later publish its old
    // snapshot over the imported preferences.
    while (mounted && _pendingWrites > 0) {
      await _writes;
    }
    if (mounted) await reload();
  }

  Future<void> reload() async {
    if (!mounted || _pendingWrites > 0) return;
    final generation = ++_generation;
    state = PreferencesState(
      values: state.values,
      ready: state.ready,
      loading: true,
    );
    try {
      final values = await _repository.load();
      if (mounted && generation == _generation) {
        state = PreferencesState(values: values, ready: true);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        state = PreferencesState(
          values: state.values,
          ready: state.ready,
          failure: _failure(error),
        );
      }
    }
  }

  Future<bool> setAppearance(AppAppearance value) =>
      _write(() => _repository.setAppearance(value));
  Future<bool> setHomeSection(HomeSection section, bool visible) =>
      _write(() => _repository.setHomeSection(section, visible));

  Future<bool> _write(Future<AppPreferences> Function() action) {
    if (!mounted || !state.ready || state.loading) return Future.value(false);
    _pendingWrites++;
    state = PreferencesState(values: state.values, ready: true, saving: true);
    final result = _writes.then((_) async {
      // Disposed controllers do not initiate queued writes. An already accepted
      // database transaction may finish, but cannot publish into a dead page.
      if (!mounted) {
        _pendingWrites--;
        return false;
      }
      try {
        final values = await action();
        if (mounted) {
          state = PreferencesState(
            values: values,
            ready: true,
            saving: _pendingWrites > 1,
          );
        }
        return true;
      } catch (error) {
        if (mounted) {
          state = PreferencesState(
            values: state.values,
            ready: true,
            saving: _pendingWrites > 1,
            failure: _failure(error),
          );
        }
        return false;
      } finally {
        _pendingWrites--;
      }
    });
    _writes = result.then<void>((_) {});
    return result;
  }

  static StorageFailure _failure(Object error) => error is StorageFailure
      ? error
      : const StorageFailure(StorageFailureKind.unavailable);
  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
