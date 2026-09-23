import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/library_common.dart';
import '../application/content_providers.dart';
import '../domain/saved_channel.dart';

/// Saves the current query under a name and reopens it later.
///
/// The spec is captured when the user saves, so later edits to the live filters
/// do not silently rewrite a stored channel.
class SavedChannelBar extends ConsumerWidget {
  const SavedChannelBar({
    required this.feed,
    required this.currentSpec,
    required this.onOpen,
    super.key,
  });

  final ChannelFeed feed;

  /// Built on demand rather than passed as a value, so the bar always saves the
  /// filters as they stand at the moment the user confirms.
  final ChannelSpec Function() currentSpec;
  final void Function(ChannelSpec) onOpen;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || !context.mounted) return;
    final repository = ref.read(savedChannelRepositoryProvider);
    final spec = currentSpec();
    await libraryAction(context, () => repository.save(name, feed, spec));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppGlassButton.icon(
    tooltip: '保存频道',
    icon: const Icon(Icons.bookmarks_outlined),
    onPressed: () async {
      final choice = await showDialog<(SavedChannel?, bool)>(
        context: context,
        builder: (dialogContext) => Consumer(
          builder: (context, ref, _) {
            final channels = ref.watch(savedChannelsProvider(feed));
            return SimpleDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('保存频道')),
                  AppGlassButton.icon(
                    tooltip: '关闭频道',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: const Text('保存当前筛选'),
                  onTap: () => Navigator.pop(dialogContext, (null, false)),
                ),
                if (channels.isLoading) const LinearProgressIndicator(),
                if (channels.hasError)
                  ListTile(
                    title: Text(libraryError(channels.error!)),
                    trailing: AppGlassButton.icon(
                      tooltip: '重试频道',
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.invalidate(savedChannelsProvider(feed)),
                    ),
                  ),
                for (final channel
                    in channels.valueOrNull ?? const <SavedChannel>[])
                  ListTile(
                    title: Text(channel.name),
                    onTap: () => Navigator.pop(dialogContext, (channel, false)),
                    trailing: AppGlassButton.icon(
                      tooltip: '删除频道「${channel.name}」',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          Navigator.pop(dialogContext, (channel, true)),
                    ),
                  ),
              ],
            );
          },
        ),
      );
      if (choice == null || !context.mounted) return;
      final channel = choice.$1;
      if (channel == null) {
        await _save(context, ref);
        return;
      }
      if (!choice.$2) {
        onOpen(channel.spec);
        return;
      }
      if (await confirmLibraryAction(
            context,
            '删除频道「${channel.name}」？',
            body: '只删除这个查询条件，不影响内容、收藏或规则。',
          ) &&
          context.mounted) {
        await libraryAction(
          context,
          () => ref.read(savedChannelRepositoryProvider).remove(channel.id),
        );
      }
    },
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('保存当前筛选'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 64,
      decoration: const InputDecoration(
        labelText: '频道名称',
        helperText: '同名频道会被覆盖',
      ),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      AppGlassButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      ValueListenableBuilder(
        valueListenable: _controller,
        builder: (context, value, _) => AppGlassButton(
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, value.text.trim()),
          child: const Text('保存'),
        ),
      ),
    ],
  );
}
