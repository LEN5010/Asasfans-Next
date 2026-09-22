import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/application/content_providers.dart';
import '../application/handoff_providers.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreColdStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A warm return needs no navigation, but the session is finished with, so
    // consume it rather than leaving one a later cold start would replay.
    if (state == AppLifecycleState.resumed && _settled) {
      _consumeQuietly();
    }
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
        router.go(channel == null ? '/content' : '/content/${channel.slug}');
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
