import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/request_cancellation.dart';
import '../../../core/domain/video_summary.dart';

export '../../../core/domain/request_cancellation.dart';
export '../../../core/domain/video_summary.dart';

class CreatorProfile {
  const CreatorProfile({
    required this.mid,
    required this.name,
    this.signature = '',
    this.avatar,
    this.banner,
    this.official = '',
    this.followers,
    this.following,
    this.archiveCount,
    this.likes,
  });
  final String mid;
  final String name;
  final String signature;
  final Uri? avatar;
  final Uri? banner;
  final String official;
  final int? followers;
  final int? following;
  final int? archiveCount;
  final int? likes;
  Uri get sourceUrl => Uri.https('space.bilibili.com', '/$mid');
}

enum CreatorArchiveOrder {
  newest('pubdate', '最新'),
  mostViewed('click', '播放'),
  mostFavorited('stow', '收藏');

  const CreatorArchiveOrder(this.wire, this.label);
  final String wire;
  final String label;
}

class CreatorArchiveQuery {
  const CreatorArchiveQuery({
    required this.mid,
    this.keyword = '',
    this.order = CreatorArchiveOrder.newest,
    this.pageSize = 30,
  });
  final String mid;
  final String keyword;
  final CreatorArchiveOrder order;
  final int pageSize;
  bool get valid =>
      validBilibiliMid(mid) &&
      keyword.length <= 200 &&
      !keyword.contains(RegExp(r'[\x00-\x1f]')) &&
      pageSize >= 1 &&
      pageSize <= 50;
  CreatorArchiveQuery copyWith({String? keyword, CreatorArchiveOrder? order}) =>
      CreatorArchiveQuery(
        mid: mid,
        keyword: keyword ?? this.keyword,
        order: order ?? this.order,
        pageSize: pageSize,
      );
  @override
  bool operator ==(Object other) =>
      other is CreatorArchiveQuery &&
      other.mid == mid &&
      other.keyword == keyword &&
      other.order == order &&
      other.pageSize == pageSize;
  @override
  int get hashCode => Object.hash(mid, keyword, order, pageSize);
}

class CreatorArchivePage {
  CreatorArchivePage({
    required List<VideoSummary> items,
    required this.page,
    required this.total,
    required this.hasMore,
  }) : items = List.unmodifiable(items);
  final List<VideoSummary> items;
  final int page;
  final int total;
  final bool hasMore;
}

abstract interface class CreatorRepository {
  Future<CreatorProfile> profile(
    String mid, {
    RequestCancellation? cancellation,
  });
  Future<CreatorArchivePage> archives(
    CreatorArchiveQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  });
}
