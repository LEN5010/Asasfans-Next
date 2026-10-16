import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../application/preferences_controller.dart';

class StartupDisclaimerGate extends ConsumerWidget {
  const StartupDisclaimerGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(preferencesControllerProvider);
    if (state.values.disclaimerAccepted) return child;
    if (state.ready) return const DisclaimerPage(requireConfirmation: true);
    return Scaffold(
      body: Center(
        child: state.failure == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.failure!.message),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: state.loading
                          ? null
                          : ref
                                .read(preferencesControllerProvider.notifier)
                                .reload,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class DisclaimerPage extends ConsumerStatefulWidget {
  const DisclaimerPage({this.requireConfirmation = false, super.key});
  final bool requireConfirmation;

  @override
  ConsumerState<DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends ConsumerState<DisclaimerPage> {
  Timer? _timer;
  int _remaining = 3;

  @override
  void initState() {
    super.initState();
    if (widget.requireConfirmation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _remaining--);
          if (_remaining == 0) timer.cancel();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(preferencesControllerProvider);
    final paragraphStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.65);
    return Scaffold(
      appBar: widget.requireConfirmation
          ? null
          : const AppPageBar(title: Text('免责声明')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTokens.gutter(MediaQuery.sizeOf(context).width),
            vertical: 24,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: widget.requireConfirmation
                      ? Alignment.center
                      : Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AppCard(
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 400 ? 24 : 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.requireConfirmation) ...[
                            Wrap(
                              spacing: 14,
                              runSpacing: 16,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/brand/asasfans.png',
                                    width: 44,
                                    height: 44,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                                Text(
                                  '免责声明',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: '二创数据来自开发者运营的 '),
                                TextSpan(
                                  text: 'len5010.top',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const TextSpan(text: '。'),
                              ],
                            ),
                            style: paragraphStyle,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '站点使用 AI 大模型自动清洗数据，部分二创可能存在人物识别、分类等错误。',
                            style: paragraphStyle,
                          ),
                          if (widget.requireConfirmation) ...[
                            if (state.failure != null) ...[
                              const SizedBox(height: 20),
                              Text(
                                state.failure!.message,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.inputRadius,
                                  ),
                                ),
                              ),
                              onPressed: _remaining == 0 && state.canEdit
                                  ? ref
                                        .read(
                                          preferencesControllerProvider
                                              .notifier,
                                        )
                                        .acceptDisclaimer
                                  : null,
                              child: Text(
                                _remaining > 0 ? '我已阅读（$_remaining 秒）' : '我已阅读',
                              ),
                            ),
                          ],
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
    );
  }
}
