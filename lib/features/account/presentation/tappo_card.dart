import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/main_account_providers.dart';
import '../data/tappo_api.dart';

/// The account's AsoulTappo desktop pet: shards, collection and the two
/// resonance guarantees, or a way to get the app when there is no save.
class TappoCard extends ConsumerWidget {
  const TappoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = ref.watch(tappoProgressProvider);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    Future<void> download() async {
      final opened = await ref
          .read(externalLinkServiceProvider)
          .open(TappoApi.downloads);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法打开下载页')));
      }
    }

    final Widget body = switch (progress) {
      AsyncData(value: final save?) => _Progress(save: save),
      AsyncData() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('这个账号还没有桌宠存档', style: muted),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: download,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                '下载 AsoulTappo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      AsyncError() => Row(
        children: [
          Expanded(child: Text('桌宠进度暂时读不到', style: muted)),
          AppButton(
            tonal: true,
            onPressed: () => ref.invalidate(tappoProgressProvider),
            child: const Text('重试'),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ToneBadge(icon: Icons.pets_rounded, member: '贝拉'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AsoulTappo 桌宠',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.save});
  final TappoProgress save;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final value = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: AppTheme.tabular,
    );
    Widget stat(String name, String number) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: label),
          const SizedBox(height: 2),
          Text(number, style: value),
        ],
      ),
    );
    Widget meter(String name, int current, int total, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: label)),
            Text(
              '$current / $total',
              style: label?.copyWith(fontFeatures: AppTheme.tabular),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : (current / total).clamp(0, 1),
            minHeight: 6,
            color: color,
            backgroundColor: colors.surfaceContainerHigh,
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            stat('碎片', '${save.shards}'),
            stat('图鉴', '${save.owned} / ${save.items}'),
            stat('共鸣', '${save.draws} 次'),
          ],
        ),
        const SizedBox(height: 16),
        meter(
          '大隐藏保底',
          save.legendaryPity,
          save.legendaryHard,
          AppTheme.dianaPink,
        ),
        const SizedBox(height: 12),
        meter(
          '皮肤保底',
          save.skinPity,
          save.skinHard,
          AppTheme.memberColors['贝拉'] ?? colors.primary,
        ),
      ],
    );
  }
}
