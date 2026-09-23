import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/content_identity.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../handoff/application/handoff_coordinator.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/domain/return_context.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/library_common.dart';
import '../application/update_providers.dart';
import '../domain/update_event.dart';

/// One inbox entry, with everything needed to deal with it in place.
///
/// The point of the card is that an update is actionable where it is found:
/// save it, watch it, or file it away without first navigating somewhere else.
/// Opening a video marks the entry read, because the user has plainly dealt
/// with it — nothing here claims they watched anything.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({
    required this.event,
    this.returnTo = ReturnTarget.updates,
    super.key,
  });

  final UpdateEvent event;

  /// Where a handoff from this card should come back to. Today passes its own
  /// target so a return lands on the module the user actually left from.
  final ReturnTarget returnTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.watch(updateControllerProvider);
    final coordinator = ref.watch(handoffCoordinatorProvider);
    final unread = !event.read;
    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _Badge(event: event, unread: unread),
        title: Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${event.subtitle} · ${_when(context, event.occurredAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        onTap: () => _open(context, ref),
        trailing: constraints.maxWidth < 560
            ? PopupMenuButton<String>(
                tooltip: '更新操作',
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) {
                  switch (action) {
                    case 'open':
                      _open(context, ref);
                    case 'read':
                      controller.markRead([event.id], read: unread);
                    case 'archive':
                      controller.archive([event.id], archived: !event.archived);
                  }
                },
                itemBuilder: (_) => [
                  if (event.kind == UpdateKind.subscriptionVideo)
                    PopupMenuItem(
                      value: 'open',
                      enabled: !coordinator.busy,
                      child: const Text('去 B 站看'),
                    ),
                  PopupMenuItem(
                    value: 'read',
                    child: Text(unread ? '标记已读' : '标记未读'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(event.archived ? '移回收件箱' : '归档'),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (event.kind == UpdateKind.subscriptionVideo)
                    AppGlassButton.icon(
                      tooltip: '去 B 站看',
                      // One handoff at a time, matching every other video entry.
                      onPressed: coordinator.busy
                          ? null
                          : () => _open(context, ref),
                      icon: const Icon(Icons.play_arrow),
                    ),
                  AppGlassButton.icon(
                    tooltip: unread ? '标记已读' : '标记未读',
                    onPressed: () =>
                        controller.markRead([event.id], read: unread),
                    icon: Icon(
                      unread
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                  ),
                  AppGlassButton.icon(
                    tooltip: event.archived ? '移回收件箱' : '归档',
                    onPressed: () => controller.archive([
                      event.id,
                    ], archived: !event.archived),
                    icon: Icon(
                      event.archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Acts on the entry according to what it points at.
  ///
  /// A video goes to Bilibili through the shared handoff, so the trip out and
  /// the way back are identical to every other video entry in the app. A
  /// schedule change stays in the app — there is nothing external to open, and
  /// the calendar is where the user can act on it.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(updateControllerProvider);
    switch (event.kind) {
      case UpdateKind.subscriptionVideo:
        final content = event.content;
        if (content == null || content.source != ContentSource.bilibiliVideo) {
          return;
        }
        await openContentSource(
          context,
          ref,
          _snapshot(content),
          url: BilibiliTargets.video(content.value),
          returnTo: returnTo,
        );
        // Handled, so it stops waiting. This is not a claim that it was watched.
        await controller.markRead([event.id]);
      case UpdateKind.scheduleChange:
        final key = event.followKey;
        if (key == null) return;
        // Land on the month the occurrence is in rather than today's.
        ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
          event.occurredAt.year,
          event.occurredAt.month,
        );
        ref.read(selectedCalendarDayProvider.notifier).state = null;
        await controller.markRead([event.id]);
        if (context.mounted) context.go('/calendar');
    }
  }

  ContentSnapshot _snapshot(ContentIdentity content) =>
      updateSnapshot(event, content);

  static String _when(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context).formatShortDate(at.toLocal());
}

/// The reading snapshot an update stands for.
///
/// It is built from what the update already carries. Saving from the inbox must
/// not require a second request, and the stored snapshot is the user's own
/// record rather than a cached source response.
ContentSnapshot updateSnapshot(UpdateEvent event, ContentIdentity content) =>
    ContentSnapshot(
      identity: content,
      title: event.title,
      body: '',
      authorName: event.creator?.name ?? event.subtitle,
      authorId: event.creator?.mid ?? '',
      kind: LibraryMediaKind.video,
    );

class _Badge extends StatelessWidget {
  const _Badge({required this.event, required this.unread});
  final UpdateEvent event;
  final bool unread;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (event.kind) {
      UpdateKind.subscriptionVideo => Icons.subscriptions_outlined,
      UpdateKind.scheduleChange =>
        event.scheduleChange == ScheduleChange.cancelled
            ? Icons.event_busy_outlined
            : Icons.edit_calendar_outlined,
    };
    return Badge(
      // A dot only for what is still waiting: a read entry is still listed, it
      // just no longer asks for attention.
      isLabelVisible: unread,
      backgroundColor: scheme.primary,
      child: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

/// The saved-items actions for an update that points at a video.
class UpdateSaveButton extends ConsumerWidget {
  const UpdateSaveButton({required this.event, super.key});
  final UpdateEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = event.content;
    if (content == null) return const SizedBox.shrink();
    return ContentActionsButton(item: updateSnapshot(event, content));
  }
}
