import '../../../core/domain/content_identity.dart';
import '../../../core/domain/request_cancellation.dart';

export '../../../core/domain/request_cancellation.dart';

/// A historical post from a member's own publishing record. A dynamic is not a
/// video: a video dynamic merely references one, and its identity stays the
/// dynamic id rather than any temporary media URL.
enum DynamicType { text, image, video, forward, article, live, other }

class DynamicMember {
  const DynamicMember({
    required this.id,
    required this.name,
    this.bilibiliUid = '',
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String bilibiliUid;
  final Uri? avatarUrl;
}

class DynamicPost {
  const DynamicPost({
    required this.identity,
    required this.member,
    required this.type,
    required this.text,
    required this.images,
    this.publishedAt,
    this.sourceUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.forwardCount = 0,
    this.forwardedFrom,
  });

  final ContentIdentity identity;
  final DynamicMember member;
  final DynamicType type;
  final String text;
  final List<Uri> images;

  /// Server timestamps are UTC; the display layer decides the zone.
  final DateTime? publishedAt;
  final Uri? sourceUrl;
  final int likeCount;
  final int commentCount;
  final int forwardCount;

  /// Present for forwards. Kept separate so a repost never masquerades as an
  /// original post by the forwarding member.
  final ForwardedPost? forwardedFrom;
}

class ForwardedPost {
  const ForwardedPost({
    required this.authorName,
    required this.text,
    required this.images,
    this.sourceUrl,
  });

  final String authorName;
  final String text;
  final List<Uri> images;
  final Uri? sourceUrl;
}

enum OnThisDaySort { hot, likes, comments }

enum DynamicSort { newest, oldest, likes, comments }

class DynamicQuery {
  const DynamicQuery({
    this.keyword = '',
    this.memberId,
    this.type,
    this.from,
    this.to,
    this.sort = DynamicSort.newest,
    this.limit = 20,
  });

  final String keyword;

  /// Server member ids are `uid:<digits>`; a bare number is not accepted.
  final String? memberId;
  final DynamicType? type;
  final DateTime? from;
  final DateTime? to;
  final DynamicSort sort;
  final int limit;

  bool get isServerAcceptable {
    if (limit < 1 || limit > 50) return false;
    if (keyword.length > 200) return false;
    if (memberId != null && !_memberId.hasMatch(memberId!)) return false;
    // The server rejects an inverted or empty range outright.
    if (from != null && to != null && !from!.isBefore(to!)) return false;
    return true;
  }

  static final _memberId = RegExp(r'^uid:\d{1,20}$');

  DynamicQuery copyWith({
    String? keyword,
    String? memberId,
    DynamicType? type,
    DateTime? from,
    DateTime? to,
    DynamicSort? sort,
    int? limit,
    bool clearMember = false,
    bool clearType = false,
    bool clearRange = false,
  }) => DynamicQuery(
    keyword: keyword ?? this.keyword,
    memberId: clearMember ? null : (memberId ?? this.memberId),
    type: clearType ? null : (type ?? this.type),
    from: clearRange ? null : (from ?? this.from),
    to: clearRange ? null : (to ?? this.to),
    sort: sort ?? this.sort,
    limit: limit ?? this.limit,
  );

  @override
  bool operator ==(Object other) =>
      other is DynamicQuery &&
      other.keyword == keyword &&
      other.memberId == memberId &&
      other.type == type &&
      other.from == from &&
      other.to == to &&
      other.sort == sort &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(keyword, memberId, type, from, to, sort, limit);
}

class DynamicPage {
  const DynamicPage({
    required this.items,
    this.nextCursor,
    this.prevCursor,
    this.total,
  });

  final List<DynamicPost> items;
  final String? nextCursor;
  final String? prevCursor;
  final int? total;
}

abstract interface class DynamicRepository {
  /// Searches the historical publishing record.
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  });

  /// Members available as a search filter. Cacheable for several minutes.
  Future<List<DynamicMember>> members();

  /// Posts published on the same month and day in earlier years.
  ///
  /// The month and day default to the source's Shanghai date and the current
  /// year is excluded; both rules belong to the server, so the client does not
  /// recompute them from the device clock.
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  });
}
