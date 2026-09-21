import 'dart:convert';

import '../../../core/domain/content_identity.dart';

/// Where a return lands. Only targets the app already knows are listed: a
/// return must never execute a route that arrived from outside, so the stored
/// value is an enum name rather than a path.
enum ReturnTarget {
  /// A content channel, identified by [ReturnContext.channel].
  contentChannel,

  /// The saved-items area the handoff started from.
  library,

  /// Today, used when there is no source list to go back to.
  today,
}

/// What a handoff attempt actually did.
///
/// `accepted` means the system took the request, which is not the same as
/// Bilibili having loaded anything, let alone the user having watched it. The
/// distinction matters because only an accepted open may be recorded as an
/// external open.
enum HandoffOutcome {
  /// The system accepted the request. Not proof of playback.
  accepted,

  /// Refused before dispatch: the target was not a URL this app will open.
  rejected,

  /// Dispatched and the platform reported failure, or threw.
  failed,

  /// A handoff was already in flight for this session.
  duplicate,
}

/// The list position a return should restore.
///
/// Identity comes first and the offset is only a fallback: a pixel offset alone
/// points at whatever has since moved into that position, while an identity
/// still names the item the user was looking at.
class ReturnAnchor {
  const ReturnAnchor({required this.identity, this.offset});

  final ContentIdentity? identity;

  /// Scroll offset at capture time, used only when [identity] cannot be found.
  final double? offset;

  Map<String, Object?> toJson() => {
    if (identity != null) 'source': identity!.source.name,
    if (identity != null) 'id': identity!.value,
    if (offset != null) 'offset': offset,
  };

  static ReturnAnchor? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final source = ContentSource.values
        .where((value) => value.name == raw['source'])
        .firstOrNull;
    final id = raw['id'];
    final offset = raw['offset'];
    return ReturnAnchor(
      identity: source == null || id is! String || id.isEmpty
          ? null
          : ContentIdentity(source: source, value: id),
      offset: offset is num && offset.isFinite && offset >= 0
          ? offset.toDouble()
          : null,
    );
  }
}

/// What the user was doing before handing a video to Bilibili.
///
/// This is picking context, not playback context: it holds the list, the query
/// that produced it and where the user was in it. It deliberately carries no
/// credentials, no signed media URL and no playback position — the app cannot
/// observe any of those from an external player, so storing them would be
/// inventing state. See [HandoffOutcome] on why an accepted open is not
/// playback.
class ReturnContext {
  const ReturnContext({
    required this.sessionId,
    required this.target,
    required this.createdAt,
    this.channel,
    this.query,
    this.anchor,
    this.openedContent,
    this.consumed = false,
  });

  /// Identifies one handoff. A system callback carrying a stale id must not
  /// drive a restore, and the same id must only ever be consumed once.
  final String sessionId;
  final ReturnTarget target;
  final DateTime createdAt;

  /// Channel slug when [target] is [ReturnTarget.contentChannel].
  final String? channel;

  /// The committed query behind the list, never an in-progress text field.
  final Map<String, Object?>? query;
  final ReturnAnchor? anchor;

  /// What was handed over. Kept so a return can offer to reopen it, never as
  /// evidence that it was watched.
  final ContentIdentity? openedContent;

  /// Whether a return already used this session.
  final bool consumed;

  ReturnContext copyWith({bool? consumed}) => ReturnContext(
    sessionId: sessionId,
    target: target,
    createdAt: createdAt,
    channel: channel,
    query: query,
    anchor: anchor,
    openedContent: openedContent,
    consumed: consumed ?? this.consumed,
  );

  String encodeQuery() => jsonEncode(query ?? const <String, Object?>{});
  String encodeAnchor() => jsonEncode(anchor?.toJson() ?? const {});
}
