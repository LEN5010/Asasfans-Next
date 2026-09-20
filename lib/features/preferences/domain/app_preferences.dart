enum AppAppearance { system, light, dark }

enum HomeSection { calendar, fanart, clips, history }

class AppPreferences {
  const AppPreferences({
    this.appearance = AppAppearance.system,
    this.hiddenHomeSections = const {},
  });
  final AppAppearance appearance;
  final Set<HomeSection> hiddenHomeSections;
  bool shows(HomeSection section) => !hiddenHomeSections.contains(section);

  AppPreferences withAppearance(AppAppearance value) =>
      AppPreferences(appearance: value, hiddenHomeSections: hiddenHomeSections);
  AppPreferences withSection(HomeSection section, bool visible) =>
      AppPreferences(
        appearance: appearance,
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
  Future<AppPreferences> setAppearance(AppAppearance appearance);
  Future<AppPreferences> setHomeSection(HomeSection section, bool visible);
}
