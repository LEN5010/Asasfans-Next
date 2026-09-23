import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/library_providers.dart';
import '../domain/library_models.dart';
import 'library_common.dart';
import 'library_paged_list.dart';
import 'saved_content_page.dart';

/// `0:42` under an hour, `1:02:03` beyond it. Never a bare millisecond count.
String formatPosition(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Position, and the total only when it is actually known. An unknown duration
/// stays absent rather than being shown as a confident zero.
String describeProgress(PlaybackProgress progress) {
  final position = formatPosition(progress.position);
  if (progress.completed) return '已看完 · $position';
  return progress.durationKnown
      ? '$position / ${formatPosition(progress.duration)}'
      : position;
}

class ContinueWatchingPage extends ConsumerWidget {
  const ContinueWatchingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProgressProvider);
    final pager = ref.read(playbackProgressProvider.notifier);
    final repository = ref.read(libraryRepositoryProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        title: const Text('继续观看'),
        actions: [
          AppGlassButton.icon(
            tooltip: '清空播放进度',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: state.items.isEmpty || state.loading
                ? null
                : () async {
                    if (await confirmLibraryAction(
                          context,
                          '清空播放进度？',
                          body: '不会删除书签、收藏、稍后看或历史记录。',
                        ) &&
                        context.mounted) {
                      await libraryAction(context, repository.clearProgress);
                    }
                  },
          ),
        ],
      ),
      body: LibraryBody(
        child: LibraryPagedList(
          state: state,
          pager: pager,
          empty: '还没有观看进度',
          itemBuilder: (context, entry) {
            final item = entry.item;
            final progress = entry.progress;
            final fraction = progress.fraction;
            return ListTile(
              leading: SizedBox(
                width: 68,
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline),
                    if (fraction != null) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: fraction, minHeight: 3),
                    ],
                  ],
                ),
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (item.authorName.isNotEmpty) item.authorName,
                  describeProgress(progress),
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => SavedContentPage(item: item),
                ),
              ),
              trailing: AppGlassButton.icon(
                tooltip: '移除这条进度',
                icon: const Icon(Icons.close),
                onPressed: () => libraryAction(
                  context,
                  () => repository.removeProgress(progress.part),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackBookmarksProvider);
    final pager = ref.read(playbackBookmarksProvider.notifier);
    final repository = ref.read(libraryRepositoryProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(title: const Text('时间书签')),
      body: LibraryBody(
        child: LibraryPagedList(
          state: state,
          pager: pager,
          empty: '还没有书签',
          itemBuilder: (context, entry) {
            final bookmark = entry.bookmark;
            final title = bookmark.title.isEmpty
                ? formatPosition(bookmark.start)
                : bookmark.title;
            final range = bookmark.end == null
                ? formatPosition(bookmark.start)
                : '${formatPosition(bookmark.start)} – ${formatPosition(bookmark.end!)}';
            return ListTile(
              leading: const SizedBox(
                width: 68,
                height: 48,
                child: Icon(Icons.bookmark_outline),
              ),
              title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  range,
                  entry.item.title,
                  if (bookmark.note.isNotEmpty) bookmark.note,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => SavedContentPage(item: entry.item),
                ),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: '管理书签',
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'remove', child: Text('删除书签')),
                ],
                onSelected: (value) async {
                  if (value == 'remove') {
                    await libraryAction(
                      context,
                      () => repository.removeBookmark(bookmark.id),
                    );
                    return;
                  }
                  final edited =
                      await showDialog<({String title, String note})>(
                        context: context,
                        builder: (_) => _BookmarkDialog(bookmark: bookmark),
                      );
                  if (edited != null && context.mounted) {
                    await libraryAction(
                      context,
                      () => repository.updateBookmark(
                        bookmark.id,
                        title: edited.title,
                        note: edited.note,
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Edits only the text. The time belongs to the player, which is the only place
/// that knows a valid position for this part.
class _BookmarkDialog extends StatefulWidget {
  const _BookmarkDialog({required this.bookmark});
  final PlaybackBookmark bookmark;
  @override
  State<_BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<_BookmarkDialog> {
  late final _title = TextEditingController(text: widget.bookmark.title);
  late final _note = TextEditingController(text: widget.bookmark.note);
  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(formatPosition(widget.bookmark.start)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        TextField(
          controller: _note,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '备注'),
        ),
      ],
    ),
    actions: [
      AppGlassButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      AppGlassButton(
        onPressed: () =>
            Navigator.pop(context, (title: _title.text, note: _note.text)),
        child: const Text('保存'),
      ),
    ],
  );
}
