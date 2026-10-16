/// A version as the app and its release tags write it — 3.0.0,
/// v3.0.0-beta.1, 3.0.0+202 — ordered as a semantic version: a
/// pre-release comes before its release, and the build number is ignored.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.label, this._core, this._pre);

  /// Without a leading v or the build number.
  final String label;
  final List<int> _core;
  final List<String> _pre;

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static AppVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final pre = match[4];
    return AppVersion._(
      [match[1], match[2], match[3]].join('.') + (pre == null ? '' : '-$pre'),
      [for (var i = 1; i <= 3; i++) int.parse(match[i]!)],
      pre?.split('.') ?? const [],
    );
  }

  bool get isPreRelease => _pre.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final order = _core[i].compareTo(other._core[i]);
      if (order != 0) return order;
    }
    if (_pre.isEmpty || other._pre.isEmpty) {
      return (other._pre.isEmpty ? 0 : 1) - (_pre.isEmpty ? 0 : 1);
    }
    for (var i = 0; i < _pre.length && i < other._pre.length; i++) {
      final a = int.tryParse(_pre[i]);
      final b = int.tryParse(other._pre[i]);
      final order = a != null && b != null
          ? a.compareTo(b)
          // Numbers sort before words.
          : a != null
          ? -1
          : b != null
          ? 1
          : _pre[i].compareTo(other._pre[i]);
      if (order != 0) return order;
    }
    return _pre.length.compareTo(other._pre.length);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(Object.hashAll(_core), Object.hashAll(_pre));

  @override
  String toString() => label;
}

/// One published release of the app.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.title,
    required this.page,
    required this.notes,
    required this.preRelease,
    this.publishedAt,
  });

  final AppVersion version;
  final String title;

  /// The release's page, where its downloads are.
  final Uri page;
  final String notes;
  final bool preRelease;
  final DateTime? publishedAt;

  /// Matches the asset name produced by Flutter Release. The cached feed only
  /// carries the release page, so this uses the same tag without another API call.
  Uri? get windowsInstaller {
    final parts = page.pathSegments;
    if (page.host != 'github.com' ||
        parts.length != 5 ||
        parts.take(4).join('/') != 'LEN5010/Asasfans-Next/releases/tag') {
      return null;
    }
    final tag = parts.last;
    return page.replace(
      pathSegments: [
        ...parts.take(3),
        'download',
        tag,
        'Asasfans-Next-$tag-windows-x64-setup.exe',
      ],
    );
  }
}

/// The newest release above [current] that this build should be offered,
/// or null when it is up to date. A pre-release build is offered newer
/// pre-releases as well; a stable build only stable releases.
AppRelease? newerRelease(Iterable<AppRelease> releases, AppVersion current) {
  AppRelease? newest;
  for (final release in releases) {
    if (release.preRelease && !current.isPreRelease) continue;
    if (release.version.compareTo(current) <= 0) continue;
    if (newest == null || release.version.compareTo(newest.version) > 0) {
      newest = release;
    }
  }
  return newest;
}
