import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/video_summary.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/library_common.dart';
import '../application/handoff_coordinator.dart';
import '../application/handoff_providers.dart';
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

/// The cover affordance that says where a tap goes.
///
/// Without it the same unlabelled area opens details in one list and Bilibili in
/// another. The title and metadata keep opening native details.
class WatchOverlayButton extends ConsumerWidget {
  const WatchOverlayButton({
    required this.video,
    this.origin = WatchOrigin.today,
    super.key,
  });

  final VideoSummary video;
  final WatchOrigin origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.watch(handoffCoordinatorProvider);
    return ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) => Tooltip(
        message: '去 B 站看',
        child: IconButton.filled(
          // Disabled while a handoff is in flight: one tap, one opening.
          onPressed: coordinator.busy
              ? null
              : () => watchOnBilibili(context, ref, video, origin: origin),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_arrow),
        ),
      ),
    );
  }
}
