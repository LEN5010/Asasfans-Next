import 'package:flutter/material.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(savedChannelsProvider(feed));
    final repository = ref.read(savedChannelRepositoryProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('保存频道'),
            onPressed: () => _save(context, ref),
          ),
          // A failed or pending load shows nothing extra rather than an error
          // chip: saved channels are a shortcut, not the way to reach content.
          for (final channel in channels.valueOrNull ?? const <SavedChannel>[])
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InputChip(
                label: Text(channel.name),
                onPressed: () => onOpen(channel.spec),
                onDeleted: () async {
                  if (await confirmLibraryAction(
                        context,
                        '删除频道「${channel.name}」？',
                        body: '只删除这个查询条件，不影响内容、收藏或规则。',
                      ) &&
                      context.mounted) {
                    await libraryAction(
                      context,
                      () => repository.remove(channel.id),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      ValueListenableBuilder(
        valueListenable: _controller,
        builder: (context, value, _) => TextButton(
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, value.text.trim()),
          child: const Text('保存'),
        ),
      ),
    ],
  );
}
