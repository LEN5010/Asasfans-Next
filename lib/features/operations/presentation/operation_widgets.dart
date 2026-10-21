import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/app_controls.dart';
import '../application/operations_controller.dart';
import '../domain/app_operations.dart';

Future<void> openOperation(
  BuildContext context,
  WidgetRef ref,
  OperationAction action,
) async {
  if (action.type == 'collection' &&
      RegExp(r'^[a-z0-9-]+$').hasMatch(action.value)) {
    await context.push<void>('/collections/${action.value}');
    return;
  }
  final uri = action.type == 'url' ? operationHttps(action.value) : null;
  if (uri == null) return;
  final opened = await ref.read(externalLinkServiceProvider).open(uri);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
  }
}

/// The fanart channel's entry to live campaigns: a slim strip that the viewer
/// can close into a button beside the channel tabs (see [CampaignShortcuts]).
class CampaignStrip extends ConsumerWidget {
  const CampaignStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(operationsProvider.notifier);
    final campaigns = ref
        .watch(operationsProvider)
        .campaigns
        .where((item) => item.action != null && !controller.collapsed(item.id))
        .toList();
    if (campaigns.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        spacing: 8,
        children: [
          for (final item in campaigns)
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton.withIcon(
                    selected: true,
                    onPressed: () => openOperation(context, ref, item.action!),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(item.buttonLabel),
                  ),
                  AppButton.icon(
                    tooltip: '收起',
                    onPressed: () async {
                      try {
                        await controller.collapse(item.id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('收起状态保存失败')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Closed campaign strips, kept as buttons beside the tabs until they end.
class CampaignShortcuts extends ConsumerWidget {
  const CampaignShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(operationsProvider.notifier);
    final campaigns = ref
        .watch(operationsProvider)
        .campaigns
        .where((item) => item.action != null && controller.collapsed(item.id));
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final item in campaigns)
          AppButton.icon(
            tooltip: item.title,
            filled: true,
            onPressed: () => openOperation(context, ref, item.action!),
            icon: Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

class AnnouncementCards extends ConsumerWidget {
  const AnnouncementCards({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(operationsProvider).announcements;
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            for (final item in items)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.campaign_outlined),
                title: Text(item.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAnnouncement(context, ref, item),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAnnouncement(
  BuildContext context,
  WidgetRef ref,
  AppOperation item,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(item.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(child: Text(item.body)),
      ),
      actions: [
        AppButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('关闭'),
        ),
        if (item.action != null)
          AppButton(
            selected: true,
            onPressed: () {
              Navigator.pop(dialog);
              openOperation(context, ref, item.action!);
            },
            child: Text(item.buttonLabel),
          ),
      ],
    ),
  );
}
