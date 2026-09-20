import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryPreferencesRepository implements PreferencesRepository {
  MemoryPreferencesRepository([this.values = const AppPreferences()]);
  AppPreferences values;
  Object? failure;
  int writes = 0;
  @override
  Future<AppPreferences> load() async {
    if (failure != null) throw failure!;
    return values;
  }

  @override
  Future<AppPreferences> setAppearance(AppAppearance value) async {
    if (failure != null) throw failure!;
    writes++;
    return values = values.withAppearance(value);
  }

  @override
  Future<AppPreferences> setHomeSection(
    HomeSection section,
    bool visible,
  ) async {
    if (failure != null) throw failure!;
    writes++;
    return values = values.withSection(section, visible);
  }
}

Override offlinePreferences([AppPreferences values = const AppPreferences()]) =>
    preferencesRepositoryProvider.overrideWithValue(
      MemoryPreferencesRepository(values),
    );
