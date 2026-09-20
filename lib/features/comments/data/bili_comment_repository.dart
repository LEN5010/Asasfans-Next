import '../../../core/bilibili/bili_metadata_client.dart';
import '../../../core/bilibili/bili_value.dart';
import '../../../core/network/api_failure.dart';
import '../domain/comments.dart';

/// Video comment reads only. No csrf, write endpoints, HTML or link execution.
class BiliCommentRepository implements CommentRepository {
  BiliCommentRepository(this._gateway);
  final BiliReadGateway _gateway;
  @override
  Future<CommentPage> page(
    CommentQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    if (!query.valid || page < 1 || page > 100000) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    try {
      final data = await _gateway.get(
        query.root == null
            ? BiliReadEndpoint.comments
            : BiliReadEndpoint.commentReplies,
        parameters: {
          'type': '1',
          'oid': query.oid,
          'pn': '$page',
          'ps': '${CommentQuery.pageSize}',
          if (query.root != null)
            'root': query.root!
          else ...{
            'sort': '${query.order.wire}',
            'nohot': '1',
          },
        },
        cancellation: cancellation,
      );
      return decode(data, query, page);
    } on ApiFailure catch (error) {
      if (error.code == '12002') {
        return CommentPage(page: page, total: 0, items: const [], closed: true);
      }
      rethrow;
    }
  }

  static CommentPage decode(
    Map<String, Object?> data,
    CommentQuery query,
    int requestedPage,
  ) {
    final info = BiliValue.map(data['page']);
    final total = BiliValue.integer(info['count']);
    if (BiliValue.integer(info['num']) != requestedPage ||
        BiliValue.integer(info['size']) != CommentQuery.pageSize) {
      BiliValue.invalid();
    }
    final rows = data['replies'];
    if (rows != null && rows is! List) BiliValue.invalid();
    final rawItems = rows as List? ?? const [];
    if (rawItems.length > CommentQuery.pageSize ||
        rawItems.length > total ||
        (rawItems.isNotEmpty &&
            (requestedPage - 1) * CommentQuery.pageSize + rawItems.length >
                total)) {
      BiliValue.invalid();
    }
    final seen = <String>{};
    final items = <BiliComment>[];
    for (final value in rawItems) {
      final item = _comment(
        BiliValue.map(value),
        query.oid,
        query.root ?? '0',
        preview: true,
      );
      if (!seen.add(item.id)) BiliValue.invalid();
      items.add(item);
    }
    final pinned = <BiliComment>[];
    BiliComment? root;
    if (query.root != null) {
      root = _comment(
        BiliValue.map(data['root']),
        query.oid,
        '0',
        preview: false,
      );
      if (root.id != query.root) BiliValue.invalid();
    } else if (requestedPage == 1 && data['upper'] != null) {
      final upper = BiliValue.map(data['upper']);
      if (upper['top'] != null) {
        pinned.add(
          _comment(BiliValue.map(upper['top']), query.oid, '0', preview: true),
        );
      }
    }
    // Pins may be excluded from the normal rows. Do not reject a pin-only
    // terminal first page, but never skip an empty intermediate page.
    if (rawItems.isEmpty &&
        (requestedPage * CommentQuery.pageSize < total ||
            (requestedPage == 1 && total > 0 && pinned.isEmpty) ||
            (query.root != null &&
                (requestedPage - 1) * CommentQuery.pageSize < total))) {
      throw const ApiFailure(ApiFailureKind.paginationStalled);
    }
    return CommentPage(
      page: requestedPage,
      total: total,
      items: items,
      pinned: pinned,
      root: root,
    );
  }

  static BiliComment _comment(
    Map<String, Object?> row,
    String oid,
    String expectedRoot, {
    required bool preview,
  }) {
    final id = BiliValue.pairedId(row, 'rpid');
    final root = BiliValue.pairedId(row, 'root', zero: true);
    final parent = BiliValue.pairedId(row, 'parent', zero: true);
    if (BiliValue.id(row['oid']) != oid ||
        row['type'] != 1 ||
        root != expectedRoot ||
        (root == '0' && parent != '0') ||
        (root != '0' && (parent == '0' || id == root || id == parent))) {
      BiliValue.invalid();
    }
    final member = BiliValue.map(row['member']);
    final author = BiliValue.id(member['mid'], zero: true);
    if (author != '0' &&
        row['mid'] != null &&
        BiliValue.id(row['mid'], zero: true) != author) {
      BiliValue.invalid();
    }
    final content = BiliValue.map(row['content']);
    final rawPictures = content['pictures'];
    if (rawPictures != null &&
        (rawPictures is! List || rawPictures.length > 20)) {
      BiliValue.invalid();
    }
    final pictures = <Uri>[];
    for (final value in rawPictures as List? ?? const []) {
      final image = BiliValue.image(BiliValue.map(value)['img_src']);
      if (image != null) pictures.add(image);
    }
    final children = <BiliComment>[];
    if (preview && root == '0' && row['replies'] != null) {
      final values = row['replies'];
      if (values is! List || values.length > 20) BiliValue.invalid();
      final seen = <String>{};
      for (final value in values) {
        final child = _comment(BiliValue.map(value), oid, id, preview: false);
        if (!seen.add(child.id)) BiliValue.invalid();
        children.add(child);
      }
    }
    final action = row['up_action'];
    return BiliComment(
      id: id,
      oid: oid,
      root: root,
      parent: parent,
      authorId: author == '0' ? null : author,
      authorName: BiliValue.text(member['uname'], limit: 1000),
      avatar: BiliValue.image(member['avatar']),
      message: BiliValue.text(content['message']),
      createdAt: BiliValue.date(row['ctime']),
      likeCount: BiliValue.count(row['like']),
      replyCount:
          BiliValue.count(row['rcount']) ?? BiliValue.count(row['count']),
      likedByCreator: action is Map && action['like'] == true,
      pictures: pictures,
      previews: children,
    );
  }
}
