import '../../../core/bilibili/bili_metadata_client.dart';
import '../../../core/bilibili/bili_value.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/content_identity.dart';
import '../../../core/domain/video_summary.dart';
import '../../../core/network/api_failure.dart';
import '../domain/video_detail.dart';

class BiliVideoRepository implements VideoRepository {
  BiliVideoRepository(this._gateway);
  final BiliReadGateway _gateway;
  @override
  Future<VideoDetail> detail(
    String bvid, {
    RequestCancellation? cancellation,
  }) async {
    if (!validBvid(bvid)) throw const ApiFailure(ApiFailureKind.invalidRequest);
    final data = await _gateway.get(
      BiliReadEndpoint.video,
      parameters: {'bvid': bvid},
      cancellation: cancellation,
    );
    return decode(data, bvid);
  }

  static VideoDetail decode(Map<String, Object?> data, String expectedBvid) {
    if (data['bvid'] != expectedBvid) BiliValue.invalid();
    final owner = BiliValue.map(data['owner']);
    final stats = data['stat'] == null
        ? <String, Object?>{}
        : BiliValue.map(data['stat']);
    final aid = BiliValue.id(data['aid']);
    if (stats['aid'] != null && BiliValue.id(stats['aid']) != aid) {
      BiliValue.invalid();
    }
    final rawParts = data['pages'];
    if (rawParts is! List ||
        rawParts.isEmpty ||
        rawParts.length > 1000 ||
        (data['videos'] != null &&
            BiliValue.integer(data['videos']) != rawParts.length)) {
      BiliValue.invalid();
    }
    final parts = <VideoPart>[];
    final ids = <String>{};
    for (final value in rawParts) {
      final part = BiliValue.map(value);
      final cid = BiliValue.id(part['cid']);
      final number = BiliValue.integer(part['page']);
      if (!ids.add(cid) || number != parts.length + 1) BiliValue.invalid();
      parts.add(
        VideoPart(
          cid: cid,
          number: number,
          title: BiliValue.text(part['part'], limit: 10000, required: true),
          duration: BiliValue.duration(part['duration']),
        ),
      );
    }
    if (data['cid'] != null && BiliValue.id(data['cid']) != parts.first.cid) {
      BiliValue.invalid();
    }
    final rights = data['rights'] == null
        ? <String, Object?>{}
        : BiliValue.map(data['rights']);
    final redirect = data['redirect_url'] is String
        ? Uri.tryParse(data['redirect_url'] as String)
        : null;
    final safeRedirect =
        redirect != null &&
            redirect.scheme == 'https' &&
            redirect.host == 'www.bilibili.com' &&
            redirect.port == 443 &&
            redirect.userInfo.isEmpty &&
            redirect.toString().length <= 4096
        ? redirect
        : null;
    return VideoDetail(
      aid: aid,
      parts: parts,
      replyCount: BiliValue.count(stats['reply']),
      favoriteCount: BiliValue.count(stats['favorite']),
      coinCount: BiliValue.count(stats['coin']),
      shareCount: BiliValue.count(stats['share']),
      interactive: rights['is_stein_gate'] == 1,
      redirectUrl: safeRedirect,
      video: VideoSummary(
        identity: ContentIdentity(
          source: ContentSource.bilibiliVideo,
          value: expectedBvid,
        ),
        title: BiliValue.text(data['title'], limit: 10000, required: true),
        creatorName: BiliValue.text(owner['name'], limit: 1000, required: true),
        creatorId: BiliValue.id(owner['mid']),
        creatorAvatarUrl: BiliValue.image(owner['face']),
        coverUrl: BiliValue.image(data['pic']),
        description: BiliValue.text(data['desc']),
        category: BiliValue.text(data['tname'], limit: 1000),
        tags: null,
        publishedAt: BiliValue.date(data['pubdate']),
        duration: BiliValue.duration(data['duration']),
        viewCount: BiliValue.count(stats['view']),
        likeCount: BiliValue.count(stats['like']),
      ),
    );
  }
}
