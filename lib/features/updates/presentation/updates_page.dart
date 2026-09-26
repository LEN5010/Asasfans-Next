import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// The two things the app records, and the limit on when.
  static const _scope = '关注的日程改期或取消、订阅的 UP 主发了新视频，'
      '会在应用运行时被记在这里；应用没有运行时不会收到';

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
          AppButton.icon(
            tooltip: '全部标记已读',
            onPressed: state.items.isEmpty ? null : controller.markAllRead,
            icon: const Icon(Icons.done_all),
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
          emptyHint: _filter == UpdateFilter.inbox ? _scope : null,
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
              // What this inbox is, in one quiet line: nothing here is a
              // system notification, and nothing arrives while the app is
              // not running.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Text(
                  '由应用运行时检查得到，不是系统推送',
                  style: Theme.of(context).textTheme.bodySmall,
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

/// Says when an inbox action could not be saved.
class UpdateStatusBanner extends ConsumerWidget {
  const UpdateStatusBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(updateControllerProvider).storageFailure;
    if (failure == null) return const SizedBox.shrink();
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
              child: Text(
                failure.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
