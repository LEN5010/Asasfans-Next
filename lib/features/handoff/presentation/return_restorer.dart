import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/application/content_providers.dart';
import '../../content/domain/community_video_repository.dart';
import '../application/handoff_providers.dart';
import '../application/return_entry_controller.dart';
import '../domain/return_context.dart';

/// Restores the list the user was picking from when they left for Bilibili.
///
/// Wraps the shell so both paths run through one place: a cold start, where the
/// process was reclaimed while Bilibili was in the foreground, and a warm
/// resume, where the widgets are still alive. A warm resume deliberately does
/// nothing to the tree — the controllers, loaded pages and scroll offset are
/// already correct, and re-navigating would throw them away to rebuild the same
/// thing. Only a cold start has anything to rebuild.
///
/// Restoring never re-opens the video. The user came back to keep picking, and
/// re-dispatching the original URL would bounce them straight back out.
class ReturnRestorer extends ConsumerStatefulWidget {
  const ReturnRestorer({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<ReturnRestorer> createState() => _ReturnRestorerState();
}

class _ReturnRestorerState extends ConsumerState<ReturnRestorer>
    with WidgetsBindingObserver {
  /// True once this process has already decided what to do with the stored
  /// session. A resume after that is an ordinary return to a live tree.
  bool _settled = false;

  /// Held from the first build so cleanup never reads a ref that is already
  /// gone. Reading the provider in dispose is what produced the account page's
  /// ref-after-dispose failure; the same mistake here would be the same bug.
  ReturnEntryController? _entry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreColdStart());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A tap on the floating entry restores the same context an ordinary return
    // would. The controller reports the tap; navigating is this widget's job,
    // so there is one restore path rather than one per way of coming back.
    final entry = ref.read(returnEntryControllerProvider);
    if (identical(entry, _entry)) return;
    _entry?.onReturnRequested = null;
    _entry = entry
      ..onReturnRequested = (_) {
        if (mounted) unawaited(_restoreWarm());
      };
  }

  @override
  void dispose() {
    _entry?.onReturnRequested = null;
    _entry = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Restores after a tap on the entry, when the process is still alive.
  ///
  /// The stored context is read rather than assumed: the tap only says the user
  /// wants to come back, not where to. A session already consumed by an
  /// ordinary resume leaves nothing to do, which is what stops one return from
  /// being restored twice.
  Future<void> _restoreWarm() async {
    final coordinator = ref.read(handoffCoordinatorProvider);
    final pending = await coordinator.pending();
    if (pending == null || !mounted) return;
    final claimed = await coordinator.consume(pending.sessionId);
    if (claimed == null || !mounted) return;
    _navigate(claimed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final entry = _entry;
    if (entry == null) return;
    if (entry.awaitingPermission) {
      // Coming back from the system permission screen is not coming back from
      // Bilibili. Settling it here is what stops a freshly granted permission
      // from immediately ending the session it was granted for.
      unawaited(entry.settlePermissionReturn());
      return;
    }
    // Any other resume means the user came back, however they did it. The
    // entry has done its job either way.
    unawaited(entry.returnedElsewhere());
    // A warm return needs no navigation, but the session is finished with, so
    // consume it rather than leaving one a later cold start would replay.
    if (_settled) _consumeQuietly();
  }

  Future<void> _consumeQuietly() async {
    final coordinator = ref.read(handoffCoordinatorProvider);
    final pending = await coordinator.pending();
    if (pending != null) await coordinator.consume(pending.sessionId);
  }

  Future<void> _restoreColdStart() async {
    final coordinator = ref.read(handoffCoordinatorProvider);
    final pending = await coordinator.pending();
    _settled = true;
    if (pending == null || !mounted) return;
    final claimed = await coordinator.consume(pending.sessionId);
    // Losing the race means something else already restored this trip.
    if (claimed == null || !mounted) return;
    _navigate(claimed);
  }

  void _navigate(ReturnContext context) {
    final router = GoRouter.of(this.context);
    switch (context.target) {
      case ReturnTarget.contentChannel:
        // Resolve the slug through the enum rather than interpolating it: a
        // return composes a route from known values only, so a corrupted or
        // renamed row lands on the channel list instead of a bad path.
        final channel = ContentChannel.fromSlug(context.channel);
        // A video kind returns as the video channel's filter.
        final kind = CommunityChannel.values
            .where((c) => c.name == context.channel)
            .firstOrNull;
        router.go(
          channel == null
              ? '/content'
              : kind != null
              ? '/content/videos?kind=${kind.name}'
              : '/content/${channel.slug}',
        );
      case ReturnTarget.library:
        router.go('/mine');
      case ReturnTarget.updates:
        router.go('/mine/updates');
      case ReturnTarget.today:
        router.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
