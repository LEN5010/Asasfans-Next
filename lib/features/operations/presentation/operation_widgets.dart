import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/media_image_policy.dart';
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

class CampaignCards extends ConsumerWidget {
  const CampaignCards({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(operationsProvider).campaigns;
    if (campaigns.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 8 : 20, bottom: compact ? 8 : 0),
      child: Column(
        spacing: 12,
        children: [
          for (final campaign in campaigns)
            _CampaignCard(item: campaign, compact: compact),
        ],
      ),
    );
  }
}

class _CampaignCard extends ConsumerWidget {
  const _CampaignCard({required this.item, required this.compact});
  final AppOperation item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final action = item.action;
    return AppCard(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact && item.bannerImage != null) ...[
            LayoutBuilder(
              builder: (context, box) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 2.8,
                  child: Image(
                    image: MediaImagePolicy.preview(
                      item.bannerImage!,
                      logicalWidth: box.maxWidth,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            item.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          if (!compact && item.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.body, style: theme.textTheme.bodyMedium),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.withIcon(
                selected: true,
                onPressed: () => openOperation(context, ref, action),
                icon: const Icon(Icons.arrow_forward),
                label: Text(item.buttonLabel),
              ),
            ),
          ],
        ],
      ),
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
