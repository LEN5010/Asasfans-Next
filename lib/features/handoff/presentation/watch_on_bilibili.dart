import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/video_summary.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/library_common.dart';
import '../application/handoff_coordinator.dart';
import '../domain/return_context.dart';

/// Where the user was picking from when they chose to watch something.
///
/// Passed down rather than read from the router: the same card appears on Today,
/// a channel and a creator page, and each has a different place to come back to.
class WatchOrigin {
  const WatchOrigin({
    required this.target,
    this.channel,
    this.query,
    this.anchorOf,
  });

  /// Today has no source list to restore, so a return lands there.
  static const today = WatchOrigin(target: ReturnTarget.today);
  static const library = WatchOrigin(target: ReturnTarget.library);

  final ReturnTarget target;
  final String? channel;
  final Map<String, Object?>? query;

  /// Resolved at tap time, so the anchor is where the list actually is rather
  /// than where it was when the card was built.
  final ReturnAnchor? Function()? anchorOf;
}

/// Hands a video to Bilibili from any entry point.
///
/// One function so a cover button, a detail page action and a context menu
/// cannot drift into different behaviour. Video playback is the deliberate
/// external case; everything this app owns stays in the app.
Future<void> watchOnBilibili(
  BuildContext context,
  WidgetRef ref,
  VideoSummary video, {
  WatchOrigin origin = WatchOrigin.today,
  int? part,
  Uri? redirect,
}) async {
  // Built from the validated id, not from any URL in a response body. The one
  // exception is a redirect the repository already constrained to a bare
  // bilibili.com https target, which is how an interactive video is reached at
  // all; anything else it saw was dropped before reaching here.
  final url =
      redirect ?? BilibiliTargets.video(video.identity.value, part: part);
  await openContentSource(
    context,
    ref,
    ContentSnapshots.video(video),
    url: url,
    returnTo: origin.target,
    channel: origin.channel,
    query: origin.query,
    anchor: origin.anchorOf?.call(),
  );
}
