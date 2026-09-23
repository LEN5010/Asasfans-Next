import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';
import '../domain/app_preferences.dart';

class SqlitePreferencesRepository implements PreferencesRepository {
  SqlitePreferencesRepository(this._database);
  final LocalDatabase _database;
  static const _read = SqlStatement(
    'SELECT key, value FROM preferences',
    [],
    true,
  );

  @override
  Future<AppPreferences> load() async =>
      _decode((await _database.batch([_read])).single);
  @override
  Future<AppPreferences> setMaterial(AppMaterial material) =>
      _set('ui.material', material.name);
  @override
  Future<AppPreferences> setAppearance(AppAppearance appearance) =>
      _set('appearance', appearance.name);
  @override
  Future<AppPreferences> setHomeSection(HomeSection section, bool visible) =>
      _set('home.${section.name}.visible', '$visible');

  Future<AppPreferences> _set(String key, String value) async {
    final results = await _database.batch([
      SqlStatement(
        'INSERT INTO preferences(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [key, value],
      ),
      _read,
    ], write: true);
    return _decode(results.last);
  }

  static AppPreferences _decode(List<SqlRow> rows) {
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final appearance = values['appearance'];
    final matched = AppAppearance.values
        .where((value) => value.name == appearance)
        .firstOrNull;
    if (appearance != null && matched == null) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final material = values['ui.material'];
    final matchedMaterial = AppMaterial.values
        .where((value) => value.name == material)
        .firstOrNull;
    if (material != null && matchedMaterial == null) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final hidden = <HomeSection>{};
    for (final section in HomeSection.values) {
      final visible = values['home.${section.name}.visible'];
      if (visible != null && visible != 'true' && visible != 'false') {
        throw const StorageFailure(StorageFailureKind.invalidData);
      }
      if (visible == 'false') hidden.add(section);
    }
    return AppPreferences(
      appearance: matched ?? AppAppearance.system,
      material: matchedMaterial ?? AppMaterial.liquid,
      hiddenHomeSections: Set.unmodifiable(hidden),
    );
  }
}
