import '../../../core/domain/content_identity.dart';

/// Server-accepted facet values. The client mirrors them so an unsupported
/// combination fails before a request is spent against the shared rate limit.
enum FanartKind { fanart, material, all }

enum FanartContentType { image, video, text, other, all }

/// `剪辑·AMV` is a re-creation category, not a synonym for every clipped video.
/// Live replays and live clips are a different source and stay out of this set.
enum FanartCategory {
  normal('普通'),
  material('物料'),
  handwriting('手书·动画'),
  amv('剪辑·AMV'),
  mmd('MMD·3D'),
  otherVideo('其他视频'),
  all('all');

  const FanartCategory(this.wire);
  final String wire;
}

enum FanartCharacter {
  bella('贝拉'),
  diana('嘉然'),
  eileen('乃琳'),
  simuAndSnow('心宜&思诺');

  const FanartCharacter(this.wire);
  final String wire;
}

enum FanartSort { newest, oldest, views, favorites }

enum FanartSource { all, bilibili, douban }

class FanartQuery {
  const FanartQuery({
    this.keyword = '',
    this.characters = const {},
    this.kind = FanartKind.fanart,
    this.contentType = FanartContentType.all,
    this.category = FanartCategory.all,
    this.sort = FanartSort.newest,
    this.source = FanartSource.all,
    this.limit = 24,
  });

  final String keyword;
  final Set<FanartCharacter> characters;
  final FanartKind kind;
  final FanartContentType contentType;
  final FanartCategory category;
  final FanartSort sort;
  final FanartSource source;
  final int limit;

  /// The server rejects metric sorting unless the query is restricted to
  /// videos, and rejects metric sorting on the Douban dataset entirely.
  bool get usesMetricSort =>
      sort == FanartSort.views || sort == FanartSort.favorites;

  bool get isServerAcceptable {
    if (limit < 1 || limit > 48) return false;
    if (keyword.length > 200) return false;
    if (usesMetricSort && contentType != FanartContentType.video) return false;
    if (usesMetricSort && source == FanartSource.douban) return false;
    return true;
  }

  FanartQuery copyWith({
    String? keyword,
    Set<FanartCharacter>? characters,
    FanartKind? kind,
    FanartContentType? contentType,
    FanartCategory? category,
    FanartSort? sort,
    FanartSource? source,
    int? limit,
  }) => FanartQuery(
    keyword: keyword ?? this.keyword,
    characters: characters ?? this.characters,
    kind: kind ?? this.kind,
    contentType: contentType ?? this.contentType,
    category: category ?? this.category,
    sort: sort ?? this.sort,
    source: source ?? this.source,
    limit: limit ?? this.limit,
  );

  @override
  bool operator ==(Object other) =>
      other is FanartQuery &&
      other.keyword == keyword &&
      other.kind == kind &&
      other.contentType == contentType &&
      other.category == category &&
      other.sort == sort &&
      other.source == source &&
      other.limit == limit &&
      other.characters.length == characters.length &&
      other.characters.containsAll(characters);

  @override
  int get hashCode => Object.hash(
    keyword,
    kind,
    contentType,
    category,
    sort,
    source,
    limit,
    Object.hashAllUnordered(characters),
  );
}

class FanartItem {
  const FanartItem({
    required this.identity,
    required this.text,
    required this.authorName,
    required this.authorUid,
    required this.images,
    required this.kind,
    required this.contentType,
    required this.category,
    required this.characterTags,
    this.sourceUrl,
    this.mediaUrl,
    this.authorAvatarUrl,
    this.authorSpaceUrl,
    this.viewCount,
    this.favoriteCount,
  });

  final ContentIdentity identity;
  final String text;
  final String authorName;
  final String authorUid;
  final List<Uri> images;
  final FanartKind kind;
  final FanartContentType contentType;
  final FanartCategory category;
  final List<FanartCharacter> characterTags;
  final Uri? sourceUrl;

  /// Signed or third-party media locations are treated as short-lived. They are
  /// never persisted as a permanent playable address.
  final Uri? mediaUrl;
  final Uri? authorAvatarUrl;
  final Uri? authorSpaceUrl;
  final int? viewCount;
  final int? favoriteCount;
}

class FanartPage {
  const FanartPage({
    required this.items,
    required this.snapshotId,
    this.nextCursor,
    this.prevCursor,
    this.total,
  });

  final List<FanartItem> items;

  /// Identifies the dataset version a cursor belongs to. A changed snapshot
  /// invalidates outstanding cursors instead of silently mixing two datasets.
  final String snapshotId;
  final String? nextCursor;
  final String? prevCursor;
  final int? total;
}

/// Cancellation handle owned by the domain so the contract stays free of any
/// HTTP client type. The data layer binds it to its own transport.
class RequestCancellation {
  final List<void Function()> _listeners = [];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }
}

abstract interface class FanartRepository {
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  });
}
