import '../../../core/domain/content_identity.dart';

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

abstract interface class DynamicRepository {
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
