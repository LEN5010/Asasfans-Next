import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../release/application/release_providers.dart';
import '../../release/presentation/release_check.dart';
import '../application/operations_controller.dart';
import '../domain/app_operations.dart';
import 'operation_widgets.dart';

/// One place orders launch messages, so a poster and two dialogs never compete.
class OperationsHost extends ConsumerStatefulWidget {
  const OperationsHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<OperationsHost> createState() => _OperationsHostState();
}

class _OperationsHostState extends ConsumerState<OperationsHost> {
  final _startup = Stopwatch()..start();
  bool _presenting = false, _splashConsidered = false, _releaseChecked = false;
  final _presentedUpdates = <String>{};
  final _presentedAnnouncements = <String>{};
  AppOperation? _splash;
  File? _splashFile;
  Timer? _splashTimer;
  int _remaining = 0;

  /// Set while the poster fades out; the fade's end removes it.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      operationsProvider,
      (_, _) => _schedule(),
      fireImmediately: true,
    );
  }

  void _schedule() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) unawaited(_present());
  });

  BuildContext? get _navigationContext => ref
      .read(appRouterProvider)
      .routerDelegate
      .navigatorKey
      .currentState
      ?.overlay
      ?.context;

  AppUpdatePolicy? _policy(OperationsState state) => state.fresh
      ? state.data.updates
            .where(
              (item) =>
                  item.platform == defaultTargetPlatform.name.toLowerCase(),
            )
            .firstOrNull
      : null;

  Future<void> _present() async {
    if (_presenting || !ref.read(operationsProvider).ready) return;
    _presenting = true;
    try {
      if (!_splashConsidered) {
        _splashConsidered = true;
        await _considerSplash();
      }
      if (!mounted || _splash != null) return;
      final state = ref.read(operationsProvider);
      if (state.loading) return;
      final policy = _policy(state);
      if (policy?.requires(currentVersion) ?? false) return;
      final controller = ref.read(operationsProvider.notifier);
      if (policy != null && policy.recommends(currentVersion)) {
        final key = '${policy.platform}:${policy.recommendedVersion}';
        if (!controller.seen('updates', key) && _presentedUpdates.add(key)) {
          await _showImportantUpdate(policy, key);
        }
      }
      if (!mounted) return;
      while (mounted) {
        final latest = ref.read(operationsProvider);
        if (_policy(latest)?.requires(currentVersion) ?? false) return;
        final item = latest.announcements
            .where(
              (item) =>
                  item.important &&
                  !controller.read(item.id) &&
                  !_presentedAnnouncements.contains(item.id),
            )
            .firstOrNull;
        if (item == null) break;
        final context = _navigationContext;
        if (context == null || !context.mounted) return;
        if (mounted &&
            context.mounted &&
            item.activeAt(controller.clock()) &&
            ref
                .read(operationsProvider)
                .announcements
                .any((current) => current.id == item.id)) {
          _presentedAnnouncements.add(item.id);
          await showAnnouncement(context, ref, item);
        }
        if (!mounted) return;
      }
      if (!_releaseChecked &&
          !kDebugMode &&
          !(policy?.recommends(currentVersion) ?? false)) {
        _releaseChecked = true;
        await _checkRelease();
      }
    } finally {
      _presenting = false;
    }
  }

  Future<void> _considerSplash() async {
    final state = ref.read(operationsProvider);
    if (_policy(state)?.requires(currentVersion) ?? false) return;
    final controller = ref.read(operationsProvider.notifier);
    if (controller.splashSeenToday || _startup.elapsedMilliseconds > 1200) {
      return;
    }
    final item = state.campaigns
        .where(
          (item) =>
              item.splash != null && !controller.seen('splashOff', item.id),
        )
        .firstOrNull;
    if (item == null) return;
    try {
      final size = MediaQuery.sizeOf(context);
      final file = await controller.cachedSplash(
        item.splash!,
        tall: size.height >= size.width,
      );
      if (file == null || !mounted) return;
      var decoded = true;
      await precacheImage(
        _poster(file),
        context,
        onError: (_, _) => decoded = false,
      );
      if (!decoded ||
          !mounted ||
          _startup.elapsedMilliseconds > 1200 ||
          !item.activeAt(controller.clock())) {
        return;
      }
      final path = ref
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri
          .path;
      if (path != '/today') return;
      await controller.markSplashSeen();
      if (!mounted) return;
      setState(() {
        _splash = item;
        _splashFile = file;
        _remaining = item.splash!.seconds;
      });
      controller.report('splash', item.id, 'impression');
      _splashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining <= 1) {
          _closeSplash();
        } else {
          setState(() => _remaining--);
        }
      });
    } catch (_) {
      // An unavailable cached poster never delays the first screen.
    }
  }

  ImageProvider _poster(File file) => ResizeImage(
    FileImage(file),
    width: 1440,
    height: 2560,
    policy: ResizeImagePolicy.fit,
  );

  /// Fades the poster out; with animations off it goes at once.
  void _closeSplash() {
    _splashTimer?.cancel();
    if (!mounted || _splash == null || _leaving) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _removeSplash();
    } else {
      setState(() => _leaving = true);
    }
  }

  void _removeSplash() {
    setState(() {
      _splash = null;
      _splashFile = null;
      _leaving = false;
    });
    _schedule();
  }

  void _openSplash(AppOperation item) {
    ref.read(operationsProvider.notifier).report('splash', item.id, 'click');
    final nav = _navigationContext;
    _closeSplash();
    if (nav != null && nav.mounted) openOperation(nav, ref, item.action!);
  }

  /// Stops this poster only; later campaigns still get their launch.
  Future<void> _muteSplash(AppOperation item) async {
    ref.read(operationsProvider.notifier).report('splash', item.id, 'mute');
    _closeSplash();
    try {
      await ref
          .read(operationsProvider.notifier)
          .markSeen('splashOff', item.id);
    } catch (_) {
      final context = _navigationContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('开屏偏好保存失败')));
      }
    }
  }

  Future<void> _showImportantUpdate(AppUpdatePolicy policy, String key) async {
    final context = _navigationContext;
    if (context == null || !context.mounted) return;
    final controller = ref.read(operationsProvider.notifier);
    controller.report('update', policy.platform, 'impression');
    final postponed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.system_update_outlined),
        title: Text('发现新版本 ${policy.recommendedVersion}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 360),
          child: _UpdateDetails(policy: policy),
        ),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('稍后'),
          ),
          AppButton(
            selected: true,
            onPressed: () async {
              controller.report('update', policy.platform, 'click');
              if (await _download() && dialog.mounted) {
                Navigator.pop(dialog, false);
              }
            },
            child: const Text('前往下载'),
          ),
        ],
      ),
    );
    if (postponed == false || !mounted) return;
    controller.report('update', policy.platform, 'dismiss');
    try {
      await controller.markSeen('updates', key);
    } catch (_) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新偏好保存失败')));
      }
    }
  }

  Future<bool> _download() async {
    final opened = await ref
        .read(externalLinkServiceProvider)
        .open(downloadPage(defaultTargetPlatform));
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开下载页')));
    }
    return opened;
  }

  Future<void> _checkRelease() async {
    try {
      final release = await ref.read(releaseCheckProvider.notifier).check();
      if (release == null || !mounted) return;
      final context = _navigationContext;
      if (context == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发现新版本 ${release.version}'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => showReleaseDialog(context, release),
          ),
        ),
      );
    } catch (_) {
      // Manual checks retain their existing error reporting.
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final policy = _policy(state);
    final required = policy?.requires(currentVersion) ?? false;
    final splash = _splash;
    final showSplash =
        !required && splash != null && splash.activeAt(state.now);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: required || showSplash,
          child: IgnorePointer(
            ignoring: required || showSplash,
            child: ExcludeFocus(
              excluding: required || showSplash,
              child: widget.child,
            ),
          ),
        ),
        if (required)
          Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AppCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/brand/asasfans.png',
                                width: 64,
                                height: 64,
                              ),
                            ),
                          ),
                          Text(
                            '发现新版本 ${policy!.recommendedVersion}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          _UpdateDetails(policy: policy),
                          AppButton(
                            onPressed: _download,
                            selected: true,
                            child: const Text('前往下载'),
                          ),
                          AppButton(
                            onPressed: ref
                                .read(operationsProvider.notifier)
                                .refresh,
                            child: const Text('重新检查'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (showSplash)
          _SplashView(
            item: splash,
            image: _poster(_splashFile!),
            remaining: _remaining,
            leaving: _leaving,
            animate: !MediaQuery.disableAnimationsOf(context),
            onGone: _removeSplash,
            onOpen: splash.action == null ? null : () => _openSplash(splash),
            onSkip: () {
              ref
                  .read(operationsProvider.notifier)
                  .report('splash', splash.id, 'dismiss');
              _closeSplash();
            },
            onMute: () => _muteSplash(splash),
          ),
      ],
    );
  }
}

/// Version step and notes, shared by the important-update dialog and the
/// required-update screen.
class _UpdateDetails extends StatelessWidget {
  const _UpdateDetails({required this.policy});
  final AppUpdatePolicy policy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$currentVersion → ${policy.recommendedVersion}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (policy.message.isNotEmpty) ...[
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Text(policy.message, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ],
    );
  }
}

/// The launch poster filling the window, the campaign's words over a scrim
/// at the foot, and a counting 跳过 at the top.
class _SplashView extends StatelessWidget {
  const _SplashView({
    required this.item,
    required this.image,
    required this.remaining,
    required this.leaving,
    required this.animate,
    required this.onGone,
    required this.onOpen,
    required this.onSkip,
    required this.onMute,
  });
  final AppOperation item;
  final ImageProvider image;
  final int remaining;
  final bool leaving, animate;
  final VoidCallback onGone, onSkip, onMute;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const light = Colors.white;
    final view = Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Dark well before the text so pale poster edges stay legible.
                  stops: [0, .4, 1],
                  colors: [
                    Color(0x00000000),
                    Color(0x99000000),
                    Color(0xD9000000),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 72, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: light,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (item.body.isNotEmpty)
                            Text(
                              item.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: light.withValues(alpha: .85),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            spacing: 12,
                            children: [
                              if (onOpen != null)
                                AppButton.withIcon(
                                  selected: true,
                                  onPressed: onOpen,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: Text(item.buttonLabel),
                                ),
                              TextButton(
                                onPressed: onMute,
                                style: TextButton.styleFrom(
                                  foregroundColor: light.withValues(alpha: .8),
                                ),
                                child: const Text('不再提醒'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.black.withValues(alpha: .45),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onSkip,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '跳过 $remaining',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: light,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!animate) return view;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: leaving ? 0 : 1),
      duration: AppTokens.controlMotion,
      curve: leaving ? AppCurves.exit : AppCurves.enter,
      onEnd: () {
        if (leaving) onGone();
      },
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
      child: view,
    );
  }
}
