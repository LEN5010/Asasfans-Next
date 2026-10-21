import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/media_cover.dart';
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
        .where((item) => item.strip && !controller.collapsed(item.id))
        .toList();
    if (campaigns.isEmpty) return const SizedBox.shrink();
    for (final item in campaigns) {
      controller.report('strip', item.id, 'impression');
    }
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
                    onPressed: () {
                      controller.report('strip', item.id, 'click');
                      openOperation(context, ref, item.action!);
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(item.buttonLabel),
                  ),
                  AppButton.icon(
                    tooltip: '收起',
                    onPressed: () async {
                      controller.report('strip', item.id, 'dismiss');
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
        .where((item) => item.strip && controller.collapsed(item.id));
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final item in campaigns)
          AppButton.icon(
            tooltip: item.title,
            filled: true,
            onPressed: () {
              controller.report('strip', item.id, 'click');
              openOperation(context, ref, item.action!);
            },
            icon: Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

/// 今日's live announcements, newest first, with a dot on unread ones.
class AnnouncementCards extends ConsumerWidget {
  const AnnouncementCards({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(operationsProvider).announcements
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnnouncementList(items: items),
    );
  }
}

/// Announcement rows in one card, shared by 今日 and the full list.
class AnnouncementList extends ConsumerWidget {
  const AnnouncementList({required this.items, super.key});
  final List<AppOperation> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final controller = ref.read(operationsProvider.notifier);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            InkWell(
              onTap: () => showAnnouncement(context, ref, item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 10),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: controller.read(item.id)
                              ? Colors.transparent
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              _date(item.startsAt),
                              if (item.endedAt(state.now)) '已结束',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (item.body.isNotEmpty)
                            Text(
                              item.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.image != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox.square(
                            dimension: 64,
                            child: MediaCover(
                              image: item.image!.url,
                              aspectRatio: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every announcement this platform was sent, ended ones included.
class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(operationsProvider).announcementHistory;
    return Scaffold(
      appBar: const AppPageBar(title: Text('公告')),
      body: items.isEmpty
          ? const Center(child: Text('暂无公告'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppTokens.readingWidth,
                    ),
                    child: AnnouncementList(items: items),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Opens one announcement: a bottom sheet on compact windows, a dialog on
/// wide ones. Opening it counts as read.
Future<void> showAnnouncement(
  BuildContext context,
  WidgetRef ref,
  AppOperation item,
) async {
  final controller = ref.read(operationsProvider.notifier);
  controller.report('announcement', item.id, 'impression');
  unawaited(controller.markRead(item.id).catchError((Object _) {}));
  final wide = MediaQuery.sizeOf(context).width >= 840;
  Widget detail(BuildContext sheet) => _AnnouncementDetail(
    item: item,
    onAction: item.action == null
        ? null
        : () {
            controller.report('announcement', item.id, 'click');
            Navigator.pop(sheet);
            openOperation(context, ref, item.action!);
          },
    onClose: () => Navigator.pop(sheet),
  );
  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: detail(dialog),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: detail,
  );
}

class _AnnouncementDetail extends StatelessWidget {
  const _AnnouncementDetail({
    required this.item,
    required this.onAction,
    required this.onClose,
  });
  final AppOperation item;
  final VoidCallback? onAction, onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = item.image;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppTokens.artworkRadius,
                      ),
                      child: MediaCover(
                        image: image.url,
                        aspectRatio: image.aspectRatio.clamp(.75, 2.4),
                      ),
                    ),
                  Text(
                    item.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _date(item.startsAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (item.body.isNotEmpty)
                    SelectableText(item.body, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                spacing: 12,
                children: [
                  AppButton(onPressed: onClose, child: const Text('关闭')),
                  if (onAction != null)
                    Expanded(
                      child: AppButton(
                        selected: true,
                        onPressed: onAction,
                        child: Text(item.buttonLabel),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
