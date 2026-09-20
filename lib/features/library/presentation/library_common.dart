import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_failure.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';

String libraryError(Object error) =>
    error is StorageFailure ? error.message : '本地资料暂时无法读写，请重试';

Future<bool> libraryAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(libraryError(error))));
    }
    return false;
  }
}

Future<void> openContentSource(
  BuildContext context,
  WidgetRef ref,
  ContentSnapshot item, {
  Uri? url,
}) async {
  final links = ref.read(externalLinkServiceProvider);
  final repository = ref.read(libraryRepositoryProvider);
  final opened = await links.open(url ?? item.sourceUrl);
  if (!opened) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
    return;
  }
  try {
    await repository.recordHistory(item, HistoryAction.external);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('历史记录保存失败')));
    }
  }
}

Future<String?> requestLibraryName(
  BuildContext context, {
  String initial = '',
  String title = '新建收藏夹',
}) => showDialog<String>(
  context: context,
  builder: (_) => _LibraryNameDialog(initial: initial, title: title),
);

class _LibraryNameDialog extends StatefulWidget {
  const _LibraryNameDialog({required this.initial, required this.title});
  final String initial;
  final String title;
  @override
  State<_LibraryNameDialog> createState() => _LibraryNameDialogState();
}

class _LibraryNameDialogState extends State<_LibraryNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 64,
      decoration: const InputDecoration(labelText: '名称'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('保存'),
      ),
    ],
  );
}

Future<bool> confirmLibraryAction(
  BuildContext context,
  String title, {
  String? body,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ??
    false;

class LibraryAsync<T> extends StatelessWidget {
  const LibraryAsync({
    required this.value,
    required this.retry,
    required this.builder,
    super.key,
  });
  final AsyncValue<T> value;
  final VoidCallback retry;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(libraryError(error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('重试')),
          ],
        ),
      ),
    ),
    data: builder,
  );
}

class LibraryBody extends StatelessWidget {
  const LibraryBody({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: child,
    ),
  );
}
