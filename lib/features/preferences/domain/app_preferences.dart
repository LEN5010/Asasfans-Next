enum AppAppearance { system, light, dark }

enum AppMaterial { liquid, clear }

enum HomeSection { calendar, fanart, clips, history }

class AppPreferences {
  const AppPreferences({
    this.appearance = AppAppearance.system,
    this.material = AppMaterial.liquid,
    this.hiddenHomeSections = const {},
  });
  final AppAppearance appearance;
  final AppMaterial material;
  final Set<HomeSection> hiddenHomeSections;
  bool shows(HomeSection section) => !hiddenHomeSections.contains(section);

  AppPreferences withAppearance(AppAppearance value) => AppPreferences(
    appearance: value,
    material: material,
    hiddenHomeSections: hiddenHomeSections,
  );
  AppPreferences withMaterial(AppMaterial value) => AppPreferences(
    appearance: appearance,
    material: value,
    hiddenHomeSections: hiddenHomeSections,
  );
  AppPreferences withSection(HomeSection section, bool visible) =>
      AppPreferences(
        appearance: appearance,
        material: material,
        hiddenHomeSections: Set.unmodifiable(
          visible
              ? ({...hiddenHomeSections}..remove(section))
              : {...hiddenHomeSections, section},
        ),
      );
}

abstract interface class PreferencesRepository {
  Future<AppPreferences> load();

  /// Returns the committed snapshot, not an optimistic echo of the input.
  Future<AppPreferences> setMaterial(AppMaterial material);
  Future<AppPreferences> setAppearance(AppAppearance appearance);
  Future<AppPreferences> setHomeSection(HomeSection section, bool visible);
}
