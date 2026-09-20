import '../../../core/domain/content_identity.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../calendar/domain/calendar_event.dart';

enum LibraryMediaKind { image, video, text }

enum HistoryAction { detail, external, playback }

/// A durable reading snapshot, not a downloaded video or signed media URL.
class ContentSnapshot {
  const ContentSnapshot({
    required this.identity,
    required this.title,
    required this.body,
    required this.authorName,
    this.authorId = '',
    this.images = const [],
    this.kind = LibraryMediaKind.text,
  });
  final ContentIdentity identity;
  final String title;
  final String body;
  final String authorName;
  final String authorId;
  final List<Uri> images;
  final LibraryMediaKind kind;
  Uri get sourceUrl => switch (identity.source) {
    ContentSource.bilibiliVideo => Uri(
      scheme: 'https',
      host: 'www.bilibili.com',
      pathSegments: ['video', identity.value],
    ),
    ContentSource.bilibiliDynamic => Uri(
      scheme: 'https',
      host: 't.bilibili.com',
      pathSegments: [identity.value],
    ),
    ContentSource.doubanTopic => Uri(
      scheme: 'https',
      host: 'www.douban.com',
      pathSegments: ['group', 'topic', identity.value, ''],
    ),
  };
  LocalSubscription? get creator =>
      identity.source != ContentSource.doubanTopic &&
          LocalSubscription.validMid(authorId)
      ? LocalSubscription(mid: authorId, name: authorName)
      : null;
}

class CollectionFolder {
  const CollectionFolder({
    required this.id,
    required this.name,
    required this.count,
  });
  final String id;
  final String name;
  final int count;
  bool get isDefault => id == 'default';
}

class LibraryItemState {
  const LibraryItemState({
    this.folderIds = const {},
    this.later = false,
    this.laterDone = false,
  });
  final Set<String> folderIds;
  final bool later;
  final bool laterDone;
}

class LibraryRecord {
  const LibraryRecord({
    required this.item,
    required this.at,
    this.action,
    this.visits = 1,
    this.done = false,
  });
  final ContentSnapshot item;
  final DateTime at;
  final HistoryAction? action;
  final int visits;
  final bool done;
}

class LocalSubscription {
  const LocalSubscription({required this.mid, required this.name, this.avatar});
  final String mid;
  final String name;
  final Uri? avatar;
  Uri get sourceUrl => Uri.https('space.bilibili.com', '/$mid');
  static bool validMid(String mid) => validBilibiliMid(mid);
}

class CalendarFollowKey {
  const CalendarFollowKey({
    required this.source,
    required this.uid,
    this.recurrenceId,
  });
  final Uri source;
  final String uid;
  final String? recurrenceId;
  @override
  bool operator ==(Object other) =>
      other is CalendarFollowKey &&
      other.source == source &&
      other.uid == uid &&
      other.recurrenceId == recurrenceId;
  @override
  int get hashCode => Object.hash(source, uid, recurrenceId);
}

class CalendarFollow {
  const CalendarFollow({
    required this.key,
    required this.event,
    required this.followedAt,
    this.observedAt,
  });
  final CalendarFollowKey key;
  final CalendarEvent event;
  final DateTime followedAt;
  final DateTime? observedAt;
}
