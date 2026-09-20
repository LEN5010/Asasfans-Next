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

/// A part is addressed by its source part id (CID for Bilibili), never by the
/// position it currently occupies in the part list.
class PlaybackPart {
  const PlaybackPart({required this.identity, required this.partId});
  final ContentIdentity identity;
  final String partId;
  @override
  bool operator ==(Object other) =>
      other is PlaybackPart &&
      other.identity == identity &&
      other.partId == partId;
  @override
  int get hashCode => Object.hash(identity, partId);
}

/// The most recent position of one video part. `completed` is an explicit state,
/// not something inferred from the position on every read: a user who finished a
/// part and then rewound is still finished until playback says otherwise.
///
/// An unknown duration is [Duration.zero]; it does not mean a zero-length part
/// and must not be shown as a determinate 0% or 100%.
class PlaybackProgress {
  const PlaybackProgress({
    required this.part,
    required this.position,
    this.duration = Duration.zero,
    this.completed = false,
    required this.updatedAt,
  });
  final PlaybackPart part;
  final Duration position;
  final Duration duration;
  final bool completed;
  final DateTime updatedAt;

  bool get durationKnown => duration > Duration.zero;

  /// Null when the duration is unknown, so callers render an indeterminate
  /// state instead of a fabricated ratio.
  double? get fraction => durationKnown
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : null;

  /// What a resume action should seek to. A completed part restarts, and a
  /// position inside the trailing window counts as finished rather than
  /// dropping the user seconds before the end.
  Duration get resumePosition =>
      completed || (durationKnown && duration - position <= completionTail)
      ? Duration.zero
      : position;

  static const completionTail = Duration(seconds: 5);
}

/// A user-authored time marker inside one part. It survives the video becoming
/// unplayable: the note is the user's own record, not source metadata.
class PlaybackBookmark {
  const PlaybackBookmark({
    required this.id,
    required this.part,
    required this.start,
    this.end,
    required this.title,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final PlaybackPart part;
  final Duration start;

  /// Null is a point in time. A range is an optional enhancement and never a
  /// zero-length interval standing in for a point.
  final Duration? end;
  final String title;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRange => end != null;
  Duration? get length => end == null ? null : end! - start;
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

/// Progress joined with the snapshot needed to render a resume entry.
class PlaybackRecord {
  const PlaybackRecord({required this.item, required this.progress});
  final ContentSnapshot item;
  final PlaybackProgress progress;
}

/// A bookmark joined with its snapshot. Kept separate from [PlaybackRecord] so
/// a resume list never silently renders bookmarks or the reverse.
class BookmarkRecord {
  const BookmarkRecord({required this.item, required this.bookmark});
  final ContentSnapshot item;
  final PlaybackBookmark bookmark;
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
