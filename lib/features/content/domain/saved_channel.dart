import 'dart:convert';

import 'dynamic_repository.dart';
import 'fanart_repository.dart';

/// Which source a saved query belongs to. A stored spec is only ever replayed
/// against its own feed: the endpoints take different parameters, so a fanart
/// spec is meaningless to the dynamics search.
enum ChannelFeed { fanart, dynamic, community }

/// A named query the user saved, stored as a versioned semantic spec rather
/// than a request URL.
///
/// A URL would freeze today's endpoint shape and break silently when the source
/// changes; a spec can be migrated or rejected on read. Time ranges stay
/// absolute here — a channel means exactly the range the user chose, not a
/// window that drifts with the current date.
class SavedChannel {
  const SavedChannel({
    required this.id,
    required this.name,
    required this.feed,
    required this.spec,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final ChannelFeed feed;
  final ChannelSpec spec;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// The stored query itself. [version] guards the JSON shape, not the app
/// version: bump it only when a field's meaning changes.
class ChannelSpec {
  const ChannelSpec({required this.version, required this.values});
  final int version;
  final Map<String, Object?> values;

  static const currentVersion = 1;

  /// A future spec is refused rather than partially understood: silently
  /// dropping an unknown filter would run a broader query than the user saved.
  static ChannelSpec? decode(int version, String json) {
    if (version > currentVersion) return null;
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return null;
    return ChannelSpec(version: version, values: Map.unmodifiable(decoded));
  }

  String encode() => jsonEncode(values);

  static ChannelSpec ofFanart(FanartQuery query) => ChannelSpec(
    version: currentVersion,
    values: {
      'keyword': query.keyword,
      'characters': [for (final c in query.characters) c.name],
      'kind': query.kind.name,
      'contentType': query.contentType.name,
      'category': query.category.name,
      'sort': query.sort.name,
      'source': query.source.name,
    },
  );

  static ChannelSpec ofDynamic(DynamicQuery query) => ChannelSpec(
    version: currentVersion,
    values: {
      'keyword': query.keyword,
      if (query.memberId != null) 'memberId': query.memberId,
      if (query.type != null) 'type': query.type!.name,
      if (query.from != null) 'from': query.from!.toUtc().toIso8601String(),
      if (query.to != null) 'to': query.to!.toUtc().toIso8601String(),
      'sort': query.sort.name,
    },
  );

  /// Unknown enum values fall back to the default rather than throwing: a
  /// source that renames a category should not make a saved channel unopenable.
  static T _enumOf<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((value) => value.name == name).firstOrNull ?? fallback;

  FanartQuery toFanart() => FanartQuery(
    keyword: values['keyword'] as String? ?? '',
    characters: {
      for (final name in (values['characters'] as List? ?? const []))
        ...FanartCharacter.values.where((c) => c.name == name),
    },
    kind: _enumOf(FanartKind.values, values['kind'], FanartKind.fanart),
    contentType: _enumOf(
      FanartContentType.values,
      values['contentType'],
      FanartContentType.all,
    ),
    category: _enumOf(
      FanartCategory.values,
      values['category'],
      FanartCategory.all,
    ),
    sort: _enumOf(FanartSort.values, values['sort'], FanartSort.newest),
    source: _enumOf(FanartSource.values, values['source'], FanartSource.all),
  );

  DynamicQuery toDynamic() => DynamicQuery(
    keyword: values['keyword'] as String? ?? '',
    memberId: values['memberId'] as String?,
    type: values['type'] == null
        ? null
        : _enumOf(DynamicType.values, values['type'], DynamicType.text),
    from: DateTime.tryParse(values['from'] as String? ?? ''),
    to: DateTime.tryParse(values['to'] as String? ?? ''),
    sort: _enumOf(DynamicSort.values, values['sort'], DynamicSort.newest),
  );
}

abstract interface class SavedChannelRepository {
  Stream<int> get changes;
  Future<List<SavedChannel>> channels({ChannelFeed? feed});

  /// Saving an existing name within the same feed replaces that channel, so a
  /// user updating a query does not accumulate near-duplicates.
  Future<String> save(String name, ChannelFeed feed, ChannelSpec spec);
  Future<void> rename(String id, String name);
  Future<void> remove(String id);
  Future<void> close();
}
