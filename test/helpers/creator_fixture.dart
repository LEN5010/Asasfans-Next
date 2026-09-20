import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';

VideoSummary creatorVideo(int id, {String mid = '123', String? title}) =>
    VideoSummary(
      identity: ContentIdentity(
        source: ContentSource.bilibiliVideo,
        value: 'BV${id.toString().padLeft(10, '0')}',
      ),
      title: title ?? '投稿 $id',
      creatorId: mid,
      creatorName: '作者 $mid',
    );

class OfflineCreatorRepository implements CreatorRepository {
  int profileCalls = 0;
  final archiveQueries = <(CreatorArchiveQuery, int)>[];
  Future<CreatorProfile> Function(String mid)? onProfile;
  Future<CreatorArchivePage> Function(CreatorArchiveQuery query, int page)?
  onArchives;
  @override
  Future<CreatorProfile> profile(
    String mid, {
    RequestCancellation? cancellation,
  }) async {
    profileCalls++;
    return onProfile != null
        ? await onProfile!(mid)
        : CreatorProfile(mid: mid, name: '测试 UP', signature: '个人简介');
  }

  @override
  Future<CreatorArchivePage> archives(
    CreatorArchiveQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    archiveQueries.add((query, page));
    return onArchives != null
        ? await onArchives!(query, page)
        : CreatorArchivePage(items: [], page: page, total: 0, hasMore: false);
  }
}
