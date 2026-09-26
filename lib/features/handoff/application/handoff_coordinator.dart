import 'package:flutter/foundation.dart';

import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/content_identity.dart';
import '../../../core/platform/external_link_service.dart';
import '../data/sqlite_return_store.dart';
import '../domain/return_context.dart';
import 'return_entry_controller.dart';

/// The result of one handoff attempt, including whether the return context
/// survived. A caller needs both: an accepted open with an unsaved context is
/// still a usable trip out, it just cannot promise a cold return.
class HandoffResult {
  const HandoffResult(this.outcome, {this.sessionId, this.contextSaved = true});
  final HandoffOutcome outcome;
  final String? sessionId;

  /// False when the context could not be persisted. The user is told the cold
  /// return is not guaranteed rather than being blocked from watching.
  final bool contextSaved;

  bool get accepted => outcome == HandoffOutcome.accepted;
}

/// Builds Bilibili targets from verified identifiers.
///
/// Nothing here accepts a URL from a response body: a page is addressed by the
/// id the app already validated, so a redirected or injected location cannot
/// become the thing the app opens.
abstract final class BilibiliTargets {
  static Uri? video(String bvid, {int? part}) {
    if (!validBvid(bvid)) return null;
    final base = Uri(
      scheme: 'https',
      host: 'www.bilibili.com',
      pathSegments: ['video', bvid],
    );
    // Part numbers are 1-based positions in the page list, not ids, so an
    // out-of-range value is dropped rather than sent as-is.
    return part == null || part < 1
        ? base
        : base.replace(queryParameters: {'p': '$part'});
  }

  static Uri? dynamicPost(String id) =>
      id.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(id)
      ? null
      : Uri(scheme: 'https', host: 't.bilibili.com', pathSegments: [id]);
}

/// Owns one trip out to Bilibili and the context needed to come back.
///
/// Separate from [ExternalLinkService], which stays a plain "open this https
/// URL" boundary. Widening that service to understand one platform's scheme
/// would make every tools link inherit the exemption.
class HandoffCoordinator extends ChangeNotifier {
  HandoffCoordinator(
    this._links,
    this._store, {
    DateTime Function()? clock,
    ReturnEntryController? entry,
  }) : _clock = clock ?? DateTime.now,
       _entry = entry;

  final ExternalLinkService _links;
  final ReturnStore _store;
  final DateTime Function() _clock;

  /// The optional floating return entry. Null on platforms without one, and
  /// inert until the user turns it on: a handoff never depends on it, and its
  /// absence changes nothing about the trip out or the way back.
  final ReturnEntryController? _entry;

  bool _busy = false;

  /// True while a handoff is in flight. A second tap is refused rather than
  /// producing two openings of the same video.
  bool get busy => _busy;

  /// Hands [url] to the system, saving [context] first so a return has
  /// something to restore.
  ///
  /// The context is written before dispatch because the process may not be
  /// alive afterwards. A write failure does not block the trip: the user came
  /// here to watch something, so the open proceeds and the caller reports the
  /// weaker guarantee.
  Future<HandoffResult> open({
    required Uri? url,
    required ReturnTarget target,
    String? channel,
    Map<String, Object?>? query,
    ReturnAnchor? anchor,
    ContentIdentity? openedContent,
  }) async {
    if (_busy) return const HandoffResult(HandoffOutcome.duplicate);
    if (url == null) return const HandoffResult(HandoffOutcome.rejected);
    _busy = true;
    notifyListeners();
    final sessionId = SqliteReturnStore.newSessionId();
    var saved = true;
    try {
      try {
        await _store.save(
          ReturnContext(
            sessionId: sessionId,
            target: target,
            createdAt: _clock().toUtc(),
            channel: channel,
            query: query,
            anchor: anchor,
            openedContent: openedContent,
          ),
        );
      } catch (_) {
        saved = false;
      }
      // Prepared before dispatch, while this app is still in the foreground:
      // a newer Android will not start the overlay's service from the
      // background. A platform refusal is not a handoff failure, so the result
      // is ignored here and the trip proceeds either way.
      await _entry?.prepare(sessionId);
      final accepted = await _links.open(url);
      if (!accepted) {
        // Nothing was handed over, so nothing should look like it was. Drop the
        // session rather than leaving one that a later resume would restore.
        if (saved) await _clearQuietly();
        await _entry?.abandon(sessionId);
        return HandoffResult(
          HandoffOutcome.failed,
          sessionId: sessionId,
          contextSaved: saved,
        );
      }
      await _entry?.dispatched(sessionId);
      if (target == ReturnTarget.contentChannel && channel != null) {
        _browsing = BrowseSnapshot(
          channel: channel,
          query: query,
          anchor: anchor,
          at: _clock().toUtc(),
        );
      }
      return HandoffResult(
        HandoffOutcome.accepted,
        sessionId: sessionId,
        contextSaved: saved,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The pending session, if the user has not returned through it yet.
  Future<ReturnContext?> pending() async {
    try {
      final context = await _store.read();
      return context == null || context.consumed ? null : context;
    } catch (_) {
      return null;
    }
  }

  /// The stored session whether or not a return already consumed it.
  ///
  /// Consumption stops a second *navigation*; the query and anchor still have to
  /// be readable afterwards, because the list that gets rebuilt is what needs
  /// them. Callers here only read — the restorer owns consuming.
  Future<ReturnContext?> lastReturn() async {
    try {
      return await _store.read();
    } catch (_) {
      return null;
    }
  }

  /// Claims a session for exactly one restore.
  ///
  /// A restore never re-opens anything: the user came back to keep picking, and
  /// re-dispatching the original URL would bounce them straight out again.
  Future<ReturnContext?> consume(String sessionId) async {
    try {
      return await _store.consume(sessionId);
    } catch (_) {
      return null;
    }
  }

  /// Sessions a cold start navigated back to in this process. Only those
  /// rebuild a list once consumed: a warm return (or a later launch) left
  /// the list alive or is history, and must not replay an old position.
  final _coldRestores = <String>{};

  /// Called by the restorer when a cold start navigates to [sessionId]'s list.
  void grantListRestore(String sessionId) => _coldRestores.add(sessionId);

  /// (session, channel) pairs whose list context was already handed out.
  final _restoredLists = <(String, String)>{};

  /// The list context a newly built [channel] feed should rebuild, at most
  /// once per session.
  ///
  /// Either the return has not been consumed yet (the feed was built before
  /// the restorer claimed it) or this process's cold start navigated to it.
  /// A warm return, or a session some earlier launch consumed, is not.
  Future<ReturnContext?> listRestoreFor(String channel) async {
    // An explicit 继续挑选 wins, and is used up by the one feed it names.
    final browse = _browseRestore;
    if (browse != null && browse.channel == channel) {
      _browseRestore = null;
      return browse;
    }
    final context = await lastReturn();
    if (context == null ||
        context.target != ReturnTarget.contentChannel ||
        context.channel != channel ||
        (context.consumed && !_coldRestores.contains(context.sessionId)) ||
        !_restoredLists.add((context.sessionId, channel))) {
      return null;
    }
    return context;
  }

  BrowseSnapshot? _browsing;
  ReturnContext? _browseRestore;
  var _browseSerial = 0;

  /// Where the user was last picking before a trip out, for 继续挑选.
  ///
  /// Held in memory for this process only and never written: it is a
  /// convenience, separate from the one-shot [ReturnContext] that carries a
  /// cold return. Reading it never consumes or replays a session.
  BrowseSnapshot? get browsing => _browsing;

  /// Drops the snapshot (dismissed, or history cleared).
  void forgetBrowsing() {
    if (_browsing == null && _browseRestore == null) return;
    _browsing = null;
    _browseRestore = null;
    notifyListeners();
  }

  /// Asks the snapshot's channel feed to rebuild its query and anchor once,
  /// and returns the id of that request (null with no snapshot). Listeners
  /// (a mounted feed) claim it at once; a feed built later claims it through
  /// [listRestoreFor]. A newer request replaces an unclaimed older one.
  int? resumeBrowsing() {
    final snapshot = _browsing;
    if (snapshot == null) return null;
    final request = ++_browseSerial;
    _browseRestore = ReturnContext(
      sessionId: 'browse-$request',
      target: ReturnTarget.contentChannel,
      createdAt: snapshot.at,
      channel: snapshot.channel,
      query: snapshot.query,
      anchor: snapshot.anchor,
    );
    notifyListeners();
    return request;
  }

  /// Withdraws [request] if no feed claimed it, so it cannot surface later on
  /// an unrelated visit to that channel. Only that request: a newer one, or
  /// one already claimed, is left alone.
  void cancelBrowseRestore(int request) {
    if (_browseRestore?.sessionId == 'browse-$request') _browseRestore = null;
  }

  /// Whether a 继续挑选 restore is waiting for [channel].
  bool hasBrowseRestoreFor(String channel) =>
      _browseRestore?.channel == channel;

  Future<void> end() => _clearQuietly();

  Future<void> _clearQuietly() async {
    try {
      await _store.clear();
    } catch (_) {
      // An orphaned session is harmless: it is consumed once and ignored after.
    }
  }
}
