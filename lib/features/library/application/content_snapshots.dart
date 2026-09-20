import '../../../core/domain/video_summary.dart';
import '../../content/domain/dynamic_repository.dart';
import '../../content/domain/fanart_repository.dart';
import '../domain/library_models.dart';

abstract final class ContentSnapshots {
  static ContentSnapshot fanart(FanartItem item) => ContentSnapshot(
    identity: item.identity,
    title: _title(item.text, '二创作品'),
    body: item.text,
    authorName: item.authorName,
    authorId: item.authorUid,
    images: item.images,
    kind: switch (item.contentType) {
      FanartContentType.video => LibraryMediaKind.video,
      FanartContentType.image => LibraryMediaKind.image,
      _ => LibraryMediaKind.text,
    },
  );
  static ContentSnapshot video(VideoSummary item) => ContentSnapshot(
    identity: item.identity,
    title: item.title,
    body: item.description,
    authorName: item.creatorName,
    authorId: item.creatorId,
    images: [if (item.coverUrl != null) item.coverUrl!],
    kind: LibraryMediaKind.video,
  );
  static ContentSnapshot dynamic(DynamicPost post) => ContentSnapshot(
    identity: post.identity,
    title: _title(post.text, '历史动态'),
    body: [
      post.text,
      if (post.forwardedFrom != null)
        '转发自 ${post.forwardedFrom!.authorName}\n${post.forwardedFrom!.text}',
    ].join('\n\n'),
    authorName: post.member.name,
    authorId: post.member.bilibiliUid,
    images: post.images,
    kind: post.type == DynamicType.video
        ? LibraryMediaKind.video
        : post.images.isNotEmpty
        ? LibraryMediaKind.image
        : LibraryMediaKind.text,
  );
  static String _title(String text, String fallback) {
    final line = text.trim().split('\n').first;
    return line.isEmpty
        ? fallback
        : line.length > 120
        ? line.substring(0, 120)
        : line;
  }
}
