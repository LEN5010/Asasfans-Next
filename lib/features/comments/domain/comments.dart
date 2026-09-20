import '../../../core/domain/request_cancellation.dart';
export '../../../core/domain/request_cancellation.dart';

enum CommentOrder {
  latest(0, '最新'),
  likes(1, '最赞');

  const CommentOrder(this.wire, this.label);
  final int wire;
  final String label;
}

class CommentQuery {
  const CommentQuery({
    required this.oid,
    this.root,
    this.order = CommentOrder.likes,
  });
  final String oid;
  final String? root;
  final CommentOrder order;
  static const pageSize = 20;
  bool get valid =>
      RegExp(r'^[1-9]\d{0,19}$').hasMatch(oid) &&
      (root == null || RegExp(r'^[1-9]\d{0,19}$').hasMatch(root!));
  CommentQuery sorted(CommentOrder order) =>
      CommentQuery(oid: oid, root: root, order: order);
  @override
  bool operator ==(Object other) =>
      other is CommentQuery &&
      oid == other.oid &&
      root == other.root &&
      order == other.order;
  @override
  int get hashCode => Object.hash(oid, root, order);
}

class BiliComment {
  BiliComment({
    required this.id,
    required this.oid,
    required this.root,
    required this.parent,
    required this.authorName,
    required this.message,
    this.authorId,
    this.avatar,
    this.createdAt,
    this.likeCount,
    this.replyCount,
    List<Uri> pictures = const [],
    List<BiliComment> previews = const [],
    this.likedByCreator = false,
  }) : pictures = List.unmodifiable(pictures),
       previews = List.unmodifiable(previews);
  final String id, oid, root, parent, authorName, message;
  final String? authorId;
  final Uri? avatar;
  final DateTime? createdAt;
  final int? likeCount, replyCount;
  final bool likedByCreator;
  final List<Uri> pictures;
  final List<BiliComment> previews;
}

class CommentPage {
  CommentPage({
    required this.page,
    required this.total,
    required List<BiliComment> items,
    List<BiliComment> pinned = const [],
    this.root,
    this.closed = false,
  }) : items = List.unmodifiable(items),
       pinned = List.unmodifiable(pinned);
  final int page, total;
  final List<BiliComment> items, pinned;
  final BiliComment? root;
  final bool closed;
  bool get hasMore => !closed && page * CommentQuery.pageSize < total;
}

abstract interface class CommentRepository {
  Future<CommentPage> page(
    CommentQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  });
}
