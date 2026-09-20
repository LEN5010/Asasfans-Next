import '../../../core/domain/video_summary.dart';
import '../../../core/domain/request_cancellation.dart';

export '../../../core/domain/request_cancellation.dart';

/// Compatibility name for the community source. Metadata is shared with the
/// native creator archive; each repository keeps its own wire contract.
typedef CommunityVideo = VideoSummary;

enum CommunityVideoOrder { newest, score }

/// A named set of tags describing one kind of video.
///
/// Live clips are identified by the tags creators actually use, because the
/// source has no "is a clip" flag. This is a best-effort view of the tag
/// space, not an authoritative classification.
enum CommunityChannel {
  latest('最新视频', []),

  /// Recordings whose value is reproducing part of a broadcast. Deliberately
  /// separate from re-creations such as AMV, handwriting and MMD, which the
  /// fanart archive covers.
  clips('切片', ['直播剪辑', '直播切片', '切片']),
  replays('录播', ['直播回放', '直播录像', '录播']);

  const CommunityChannel(this.label, this.tags);
  final String label;

  /// Alternatives (OR). The feed pager fans these out into supported queries.
  final List<String> tags;
}

class CommunityVideoQuery {
  const CommunityVideoQuery({
    this.tags = const [],
    this.creatorId,
    this.withinDays,
    this.order = CommunityVideoOrder.newest,
    this.asOf,
  });

  /// Conditions required together in a single source request (AND).
  /// Channel alternatives belong to the pager, not this wire expression.
  final List<String> tags;
  final String? creatorId;
  final int? withinDays;
  final CommunityVideoOrder order;

  /// Frozen upper publication bound for one paging run.
  final DateTime? asOf;

  /// The source builds its filter expression from tags, so a tag containing a
  /// separator character would change the meaning of the whole expression.
  static const _reservedTagCharacters = {'.', '+', '~'};

  bool get isServerAcceptable {
    if (tags.any(
      (tag) =>
          tag.isEmpty || tag.split('').any(_reservedTagCharacters.contains),
    )) {
      return false;
    }
    if (creatorId != null &&
        (!RegExp(r'^\d{1,20}$').hasMatch(creatorId!) ||
            (int.tryParse(creatorId!) ?? 0) <= 0)) {
      return false;
    }
    if (withinDays != null && withinDays! <= 0) return false;
    if (asOf != null && asOf!.millisecondsSinceEpoch < 0) return false;
    return true;
  }

  CommunityVideoQuery copyWith({
    List<String>? tags,
    String? creatorId,
    int? withinDays,
    CommunityVideoOrder? order,
    DateTime? asOf,
    bool clearCreator = false,
    bool clearDays = false,
  }) => CommunityVideoQuery(
    tags: tags ?? this.tags,
    creatorId: clearCreator ? null : (creatorId ?? this.creatorId),
    withinDays: clearDays ? null : (withinDays ?? this.withinDays),
    order: order ?? this.order,
    asOf: asOf ?? this.asOf,
  );

  @override
  bool operator ==(Object other) =>
      other is CommunityVideoQuery &&
      other.creatorId == creatorId &&
      other.withinDays == withinDays &&
      other.order == order &&
      other.asOf == asOf &&
      other.tags.toSet().length == tags.toSet().length &&
      other.tags.every(tags.contains);

  @override
  int get hashCode => Object.hash(
    creatorId,
    withinDays,
    order,
    asOf,
    Object.hashAllUnordered(tags.toSet()),
  );
}

class CommunityVideoPage {
  const CommunityVideoPage({
    required this.videos,
    required this.page,
    required this.hasMore,
    this.total,
  });

  final List<CommunityVideo> videos;

  /// This source pages by number rather than by cursor.
  final int page;
  final bool hasMore;
  final int? total;
}

abstract interface class CommunityVideoRepository {
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  });
}
