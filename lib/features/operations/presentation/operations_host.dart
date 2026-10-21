import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/widgets/app_controls.dart';
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
  AppOperation? _splash;
  File? _splashFile;
  Timer? _splashTimer;

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
                  item.enabled &&
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
              (item) => item.important && !controller.seen('notices', item.id),
            )
            .firstOrNull;
        if (item == null) break;
        final context = _navigationContext;
        if (context == null || !context.mounted) return;
        try {
          await controller.markSeen('notices', item.id);
        } catch (_) {
          return;
        }
        if (mounted &&
            context.mounted &&
            item.activeAt(controller.clock()) &&
            ref
                .read(operationsProvider)
                .announcements
                .any((current) => current.id == item.id)) {
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
              item.splashEnabled &&
              item.splashImage != null &&
              !controller.seen('splashOff', item.id),
        )
        .firstOrNull;
    if (item == null) return;
    try {
      final file = await controller.cachedSplash(item);
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
      });
      _splashTimer = Timer(const Duration(seconds: 5), _closeSplash);
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

  void _closeSplash() {
    _splashTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _splash = null;
      _splashFile = null;
    });
    _schedule();
  }

  /// Stops this poster only; later campaigns still get their launch.
  Future<void> _muteSplash(AppOperation item) async {
    _closeSplash();
    try {
      await ref.read(operationsProvider.notifier).markSeen('splashOff', item.id);
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
    final postponed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text('更新至 ${policy.recommendedVersion}'),
        content: policy.message.isEmpty ? null : Text(policy.message),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('稍后'),
          ),
          AppButton(
            selected: true,
            onPressed: () async {
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
    try {
      await ref.read(operationsProvider.notifier).markSeen('updates', key);
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
                          Text(
                            '请更新至 ${policy!.recommendedVersion}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (policy.message.isNotEmpty) Text(policy.message),
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
          Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: _poster(_splashFile!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            Center(child: Text(splash.title)),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Row(
                          spacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _muteSplash(splash),
                              child: const Text('不再提醒'),
                            ),
                            FilledButton.tonal(
                              onPressed: _closeSplash,
                              child: const Text('跳过'),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 24,
                        child: AppCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: [
                              Text(
                                splash.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (splash.body.isNotEmpty) Text(splash.body),
                              if (splash.action != null)
                                AppButton(
                                  selected: true,
                                  onPressed: () {
                                    final nav = _navigationContext;
                                    _closeSplash();
                                    if (nav != null && nav.mounted) {
                                      openOperation(nav, ref, splash.action!);
                                    }
                                  },
                                  child: Text(splash.buttonLabel),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
