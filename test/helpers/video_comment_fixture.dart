import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/features/video/data/bili_video_repository.dart';
import 'package:asasfans_next/features/video/domain/video_detail.dart';
import 'package:asasfans_next/features/comments/data/bili_comment_repository.dart';
import 'package:asasfans_next/features/comments/domain/comments.dart';

const fixtureBvid = 'BV1xx411c7mD';
const fixtureAid = '9007199254740993';
Map<String, Object?> videoPayload({String bvid = fixtureBvid}) => {
  'bvid': bvid,
  'aid': fixtureAid,
  'cid': '801',
  'videos': 2,
  'title': '测试视频标题',
  'desc': '视频完整简介',
  'owner': {'mid': '123', 'name': '视频作者'},
  'pubdate': 1789920000,
  'stat': {'view': 123, 'like': 8, 'reply': 21},
  'rights': {'is_stein_gate': 0},
  'pages': [
    {'cid': '801', 'page': 1, 'part': '第一部分', 'duration': 90},
    {'cid': '802', 'page': 2, 'part': '第二部分', 'duration': 130},
  ],
};
VideoDetail videoDetailFixture() =>
    BiliVideoRepository.decode(videoPayload(), fixtureBvid);

Map<String, Object?> commentPayload(
  int id, {
  String root = '0',
  String? parent,
  String oid = fixtureAid,
  int replies = 0,
}) => {
  'rpid_str': '$id',
  'rpid': id,
  'oid': oid,
  'type': 1,
  'root_str': root,
  'parent_str': parent ?? root,
  'mid': 123,
  'member': {'mid': '123', 'uname': '评论作者 $id'},
  'content': {'message': '评论内容 $id'},
  'ctime': 1789920000,
  'like': 0,
  'rcount': replies,
};
Map<String, Object?> commentPagePayload({
  int page = 1,
  int total = 21,
  int? length,
  String? root,
}) => {
  'page': {'num': page, 'size': 20, 'count': total},
  'replies': List.generate(
    length ?? (total - (page - 1) * 20).clamp(0, 20),
    (index) => commentPayload(
      page * (root == null ? 100 : 1000) + index,
      root: root ?? '0',
    ),
  ),
  if (root != null) 'root': commentPayload(int.parse(root), replies: total),
};
BiliComment commentFixture(int id, {int replies = 0}) =>
    BiliCommentRepository.decode(
      {
        'page': {'num': 1, 'size': 20, 'count': 1},
        'replies': [commentPayload(id, replies: replies)],
      },
      const CommentQuery(oid: fixtureAid),
      1,
    ).items.single;

class FixtureReadGateway implements BiliReadGateway {
  Future<Map<String, Object?>> Function(
    BiliReadEndpoint,
    Map<String, String>,
    RequestCancellation?,
  )?
  respond;
  final calls =
      <
        ({
          BiliReadEndpoint endpoint,
          Map<String, String> parameters,
          RequestCancellation? cancellation,
        })
      >[];
  @override
  Future<Map<String, Object?>> get(
    BiliReadEndpoint endpoint, {
    Map<String, String> parameters = const {},
    RequestCancellation? cancellation,
  }) async {
    calls.add((
      endpoint: endpoint,
      parameters: parameters,
      cancellation: cancellation,
    ));
    if (respond != null) return respond!(endpoint, parameters, cancellation);
    return endpoint == BiliReadEndpoint.video
        ? videoPayload()
        : commentPagePayload(
            page: int.parse(parameters['pn'] ?? '1'),
            root: parameters['root'],
          );
  }
}

class OfflineVideoRepository implements VideoRepository {
  Future<VideoDetail> Function(RequestCancellation?)? respond;
  int calls = 0;
  @override
  Future<VideoDetail> detail(
    String bvid, {
    RequestCancellation? cancellation,
  }) async {
    calls++;
    return respond == null
        ? videoDetailFixture()
        : await respond!(cancellation);
  }
}

class OfflineCommentRepository implements CommentRepository {
  Future<CommentPage> Function(CommentQuery, int, RequestCancellation?)?
  respond;
  final calls =
      <({CommentQuery query, int page, RequestCancellation? cancellation})>[];
  @override
  Future<CommentPage> page(
    CommentQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    calls.add((query: query, page: page, cancellation: cancellation));
    return respond == null
        ? BiliCommentRepository.decode(
            commentPagePayload(page: page, root: query.root),
            query,
            page,
          )
        : await respond!(query, page, cancellation);
  }
}
