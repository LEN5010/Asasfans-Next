import 'dart:async';

import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences_fixture.dart';

class _Delayed extends MemoryPreferencesRepository {
  final loads = <Completer<AppPreferences>>[];
  final write = Completer<AppPreferences>();
  int calls = 0;
  @override
  Future<AppPreferences> load() {
    final result = Completer<AppPreferences>();
    loads.add(result);
    return result.future;
  }

  @override
  Future<AppPreferences> setAppearance(AppAppearance value) {
    calls++;
    return write.future;
  }
}

void main() {
  test(
    'failed writes retain the last committed values and are retryable',
    () async {
      final repository = MemoryPreferencesRepository();
      final controller = PreferencesController(repository);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      repository.failure = const StorageFailure(StorageFailureKind.unavailable);
      expect(await controller.setAppearance(AppAppearance.dark), isFalse);
      expect(controller.state.values.appearance, AppAppearance.system);
      expect(controller.state.failure, isNotNull);
      expect(controller.state.canEdit, isTrue);
      repository.failure = null;
      expect(await controller.setAppearance(AppAppearance.dark), isTrue);
      expect(controller.state.values.appearance, AppAppearance.dark);
      expect(controller.state.failure, isNull);
    },
  );

  test(
    'queued mutations preserve both keys and load failures never overwrite storage',
    () async {
      final repository = MemoryPreferencesRepository()
        ..failure = const StorageFailure(StorageFailureKind.unavailable);
      final controller = PreferencesController(repository);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.ready, isFalse);
      expect(await controller.setAppearance(AppAppearance.dark), isFalse);
      expect(repository.writes, 0);
      repository.failure = null;
      await controller.reload();
      await Future.wait([
        controller.setAppearance(AppAppearance.dark),
        controller.setHomeSection(HomeSection.clips, false),
      ]);
      expect(controller.state.values.appearance, AppAppearance.dark);
      expect(controller.state.values.shows(HomeSection.clips), isFalse);
      expect(controller.state.saving, isFalse);
    },
  );

  test(
    'late reload responses and disposed writes cannot publish stale state',
    () async {
      final repository = _Delayed();
      final controller = PreferencesController(repository);
      final reload = controller.reload();
      repository.loads.last.complete(
        const AppPreferences(appearance: AppAppearance.light),
      );
      await reload;
      repository.loads.first.complete(
        const AppPreferences(appearance: AppAppearance.dark),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.values.appearance, AppAppearance.light);
      final pending = controller.setAppearance(AppAppearance.dark);
      final queued = controller.setAppearance(AppAppearance.system);
      await Future<void>.delayed(Duration.zero);
      expect(repository.calls, 1);
      controller.dispose();
      repository.write.complete(
        const AppPreferences(appearance: AppAppearance.dark),
      );
      expect(await pending, isTrue);
      expect(await queued, isFalse);
      expect(repository.calls, 1);
    },
  );
  test(
    'backup reload waits for accepted preference writes before reading merged values',
    () async {
      final repository = _Delayed();
      final controller = PreferencesController(repository);
      addTearDown(controller.dispose);
      repository.loads.first.complete(const AppPreferences());
      await Future<void>.delayed(Duration.zero);
      final write = controller.setAppearance(AppAppearance.dark);
      final reloaded = controller.reloadAfterExternalWrite();
      await Future<void>.delayed(Duration.zero);
      expect(repository.loads, hasLength(1));
      repository.write.complete(
        const AppPreferences(appearance: AppAppearance.dark),
      );
      await write;
      await Future<void>.delayed(Duration.zero);
      expect(repository.loads, hasLength(2));
      repository.loads.last.complete(
        const AppPreferences(
          appearance: AppAppearance.dark,
          hiddenHomeSections: {HomeSection.clips},
        ),
      );
      await reloaded;
      expect(controller.state.values.hiddenHomeSections, {HomeSection.clips});
      expect(controller.state.values.appearance, AppAppearance.dark);
    },
  );
}
