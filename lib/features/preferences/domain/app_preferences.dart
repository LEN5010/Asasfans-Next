enum AppAppearance { system, light, dark }

enum AppMaterial { liquid, clear }

/// What the user asks of the interface material. The effective tier also
/// depends on the platform, system accessibility settings and whether the
/// renderer can run glass at all (see GlassPolicy).
///
/// - [smooth]: solid surfaces, no backdrop sampling at all.
/// - [auto]: glass at a tier chosen per platform (conservative on Android).
/// - [visual]: the most detailed glass the renderer supports.
enum GlassChoice { smooth, auto, visual }

enum HomeSection { calendar, fanart, clips, history }

class AppPreferences {
  const AppPreferences({
    this.appearance = AppAppearance.system,
    this.material = AppMaterial.liquid,
    this.visualGlass = false,
    this.hiddenHomeSections = const {},
  });
  final AppAppearance appearance;
  final AppMaterial material;

  /// Stored apart from [material] so an older build that only knows
  /// liquid/clear still reads this database.
  final bool visualGlass;
  final Set<HomeSection> hiddenHomeSections;

  GlassChoice get glass => material == AppMaterial.clear
      ? GlassChoice.smooth
      : visualGlass
      ? GlassChoice.visual
      : GlassChoice.auto;

  AppPreferences withGlass(GlassChoice value) => AppPreferences(
    appearance: appearance,
    material: value == GlassChoice.smooth
        ? AppMaterial.clear
        : AppMaterial.liquid,
    visualGlass: value == GlassChoice.visual,
    hiddenHomeSections: hiddenHomeSections,
  );
  bool shows(HomeSection section) => !hiddenHomeSections.contains(section);

  AppPreferences withAppearance(AppAppearance value) => AppPreferences(
    appearance: value,
    material: material,
    visualGlass: visualGlass,
    hiddenHomeSections: hiddenHomeSections,
  );
  AppPreferences withMaterial(AppMaterial value) => AppPreferences(
    appearance: appearance,
    material: value,
    visualGlass: visualGlass,
    hiddenHomeSections: hiddenHomeSections,
  );
  AppPreferences withSection(HomeSection section, bool visible) =>
      AppPreferences(
        appearance: appearance,
        material: material,
        visualGlass: visualGlass,
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

  /// Writes both stored keys behind [GlassChoice] in one transaction.
  Future<AppPreferences> setGlass(GlassChoice glass);
  Future<AppPreferences> setAppearance(AppAppearance appearance);
  Future<AppPreferences> setHomeSection(HomeSection section, bool visible);
}
