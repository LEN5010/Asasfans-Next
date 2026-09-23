import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../library/presentation/library_common.dart';
import '../../library/presentation/library_paged_list.dart';
import '../application/update_providers.dart';
import '../domain/update_repository.dart';
import 'update_card.dart';

/// The in-app inbox.
///
/// It is explicitly an in-app record: the app collected these while it was
/// running and the user is reading them here. Nothing on this screen was
/// delivered by the system, and the wording does not suggest otherwise.
class UpdatesPage extends ConsumerStatefulWidget {
  const UpdatesPage({super.key});
  @override
  ConsumerState<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends ConsumerState<UpdatesPage> {
  UpdateFilter _filter = UpdateFilter.inbox;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(updateControllerProvider);
    final state = ref.watch(updateListProvider(_filter));
    final pager = ref.read(updateListProvider(_filter).notifier);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        title: const Text('更新'),
        actions: [
          IconButton(
            tooltip: '全部标记已读',
            onPressed: state.items.isEmpty ? null : controller.markAllRead,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: '检查更新',
            onPressed: controller.running ? null : controller.run,
            icon: controller.running
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LibraryBody(
        child: LibraryPagedList(
          state: state,
          pager: pager,
          empty: switch (_filter) {
            UpdateFilter.inbox => '收件箱是空的',
            UpdateFilter.unread => '没有未读更新',
            UpdateFilter.archived => '没有归档的更新',
          },
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: SegmentedButton<UpdateFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: UpdateFilter.inbox,
                      label: Text('收件箱'),
                    ),
                    ButtonSegment(
                      value: UpdateFilter.unread,
                      label: Text('未读'),
                    ),
                    ButtonSegment(
                      value: UpdateFilter.archived,
                      label: Text('已归档'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              const UpdateStatusBanner(),
            ],
          ),
          itemBuilder: (context, event) => UpdateCard(event: event),
        ),
      ),
    );
  }
}

/// Says what the last collection pass could and could not see.
///
/// A source that failed is a gap in the list, not an absence of news. Saying so
/// is the difference between "nothing new" and "we could not check".
class UpdateStatusBanner extends ConsumerWidget {
  const UpdateStatusBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(updateControllerProvider);
    final messages = <String>[
      if (controller.failure case final failure?) failure.message,
      if (controller.storageFailure case final failure?) failure.message,
      if (controller.failedSources > 0)
        '有 ${controller.failedSources} 个订阅来源没有读取成功，这里显示的不是全部更新',
      if (controller.baselineOnly) '已记录当前进度，新订阅的历史投稿不会补进收件箱，之后的新视频才会出现',
    ];
    if (messages.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final message in messages)
                    Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (controller.failure?.kind == ApiFailureKind.rateLimited ||
                controller.failedSources > 0)
              TextButton(
                onPressed: controller.running ? null : controller.run,
                child: const Text('重试'),
              ),
          ],
        ),
      ),
    );
  }
}
