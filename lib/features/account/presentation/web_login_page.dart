import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../application/account_controller.dart';
import '../application/account_providers.dart';
import '../application/login_browser_lifecycle.dart';
import '../domain/bili_account.dart';

abstract final class BiliLoginNavigation {
  static final entry = Uri.https('passport.bilibili.com', '/login');
  static bool allowed(String raw, {bool mainFrame = true}) {
    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        (!mainFrame ||
            uri.host == 'bilibili.com' ||
            uri.host.endsWith('.bilibili.com'));
  }
}

class WebLoginPage extends ConsumerStatefulWidget {
  const WebLoginPage({required this.generation, super.key});
  final int generation;
  @override
  ConsumerState<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends ConsumerState<WebLoginPage> {
  Widget _browser(WebViewController web) =>
      web.platform is AndroidWebViewController
      ? WebViewWidget.fromPlatformCreationParams(
          params: AndroidWebViewWidgetCreationParams(
            controller: web.platform,
            displayWithHybridComposition: true,
          ),
        )
      : WebViewWidget(controller: web);
  WebViewController? _web;
  final _lifecycle = LoginBrowserLifecycle();
  late final AccountController _account = ref.read(accountControllerProvider);
  bool _closedView = false;
  bool _leaving = false;
  bool _failed = false;
  bool _ready = false;
  int _progress = 0;
  @override
  void initState() {
    super.initState();
    _account.registerBrowserCloser(widget.generation, _closeView);
    unawaited(_begin());
  }

  Future<void> _begin() async {
    try {
      await _lifecycle.initialize(_initialize);
    } catch (_) {
      if (mounted && _lifecycle.acceptsNavigation) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _initialize() async {
    if (!_lifecycle.acceptsNavigation ||
        _account.loginGeneration != widget.generation ||
        _account.loginPhase != AccountLoginPhase.web) {
      return;
    }
    final web = _web = WebViewController();
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) =>
            _lifecycle.acceptsNavigation &&
                BiliLoginNavigation.allowed(
                  request.url,
                  mainFrame: request.isMainFrame,
                )
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onPageFinished: (url) {
          if (mounted &&
              _lifecycle.acceptsNavigation &&
              BiliLoginNavigation.allowed(url)) {
            _complete(silent: true);
          }
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() => _failed = true);
          }
        },
      ),
    );
    if (!mounted ||
        !_lifecycle.acceptsNavigation ||
        _account.loginGeneration != widget.generation ||
        _account.loginPhase != AccountLoginPhase.web) {
      return;
    }
    await web.loadRequest(BiliLoginNavigation.entry);
    if (mounted && _lifecycle.acceptsNavigation) setState(() => _ready = true);
  }

  Future<void> _closeView() => _lifecycle.close(() async {
    final web = _web;
    if (web != null) {
      final platform = web.platform;
      final id = switch (platform) {
        AndroidWebViewController() => platform.webViewIdentifier,
        WebKitWebViewController() => platform.webViewIdentifier,
        _ => throw const AccountFailure(AccountFailureKind.cleanup),
      };
      await web.setJavaScriptMode(JavaScriptMode.disabled);
      final blank = Completer<void>();
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (url) {
            if (url == 'about:blank' && !blank.isCompleted) blank.complete();
          },
        ),
      );
      // Use the plugin's native identifier: a detached platform view can still
      // be alive, so walking the current window hierarchy is insufficient.
      await _account.cookies.stopNavigation(webViewId: id);
      await web.loadHtmlString(
        '<!doctype html><html></html>',
        baseUrl: 'about:blank',
      );
      await blank.future.timeout(const Duration(seconds: 10));
    }
    if (mounted) {
      setState(() => _closedView = true);
      await WidgetsBinding.instance.endOfFrame;
    } else {
      _closedView = true;
    }
    _web = null;
  });

  Future<void> _complete({bool silent = false}) async {
    if (_leaving || !_lifecycle.acceptsNavigation || !mounted) return;
    final success = await _account.completeWeb(
      widget.generation,
      silent: silent,
    );
    if (!mounted) return;
    if (success || _account.loginPhase != AccountLoginPhase.web) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } else if (!silent && _account.failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先完成 B 站页面登录')));
    }
  }

  Future<void> _cancel() async {
    if (_leaving) return;
    await _account.cancelLogin(generation: widget.generation);
    if (mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    if (!_closedView) {
      // Keep the closer registered until cancellation has stopped this native
      // view, including an unexpected route removal, before cookie cleanup.
      unawaited(
        Future<void>.microtask(
          () => _account.cancelLogin(generation: widget.generation),
        ),
      );
    } else {
      _account.registerBrowserCloser(widget.generation, null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountControllerProvider);
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('B 站登录'),
          actions: [
            TextButton(
              onPressed: account.busy || _closedView ? null : () => _complete(),
              child: const Text('完成登录'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_progress < 100 || account.busy)
                LinearProgressIndicator(
                  value: account.busy ? null : _progress / 100,
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('登录页面加载失败'),
                      TextButton(
                        onPressed: !_lifecycle.acceptsNavigation
                            ? null
                            : () {
                                if (!_ready) {
                                  unawaited(_cancel());
                                  return;
                                }
                                setState(() => _failed = false);
                                unawaited(_retryPage());
                              },
                        child: Text(_ready ? '重试' : '返回'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _ready && !_closedView && _web != null
                    ? _browser(_web!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryPage() async {
    try {
      await _lifecycle.navigate(() async {
        await _web?.loadRequest(BiliLoginNavigation.entry);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }
}
