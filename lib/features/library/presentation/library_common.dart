import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_failure.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/domain/return_context.dart';
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

/// Hands one item to its external source and records the attempt.
///
/// Every entry point goes through here, so the behaviour of "open this
/// elsewhere" is the same from a card, a detail page, a folder or the schedule.
/// Pass [returnTo] to also register a return session; without it this is an
/// ordinary outbound link that does not claim a restore.
Future<void> openContentSource(
  BuildContext context,
  WidgetRef ref,
  ContentSnapshot item, {
  Uri? url,
  ReturnTarget? returnTo,
  String? channel,
  Map<String, Object?>? query,
  ReturnAnchor? anchor,
}) async {
  final repository = ref.read(libraryRepositoryProvider);
  final result = await ref
      .read(handoffCoordinatorProvider)
      .open(
        url: url ?? item.sourceUrl,
        target: returnTo ?? ReturnTarget.today,
        channel: returnTo == ReturnTarget.contentChannel ? channel : null,
        query: query,
        anchor: anchor,
        openedContent: item.identity,
      );
  if (!result.accepted) {
    if (context.mounted && result.outcome != HandoffOutcome.duplicate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
    return;
  }
  if (!result.contextSaved && context.mounted && returnTo != null) {
    // Say so rather than promising a restore that may not survive a cold start.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('返回位置未保存，重新打开应用可能回到频道开头')));
  }
  try {
    // Only an accepted handoff is an external open. This is not playback.
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
      AppGlassButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      AppGlassButton(
        selected: true,
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
          AppGlassButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          AppGlassButton(
            selected: true,
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
            AppGlassButton(onPressed: retry, child: const Text('重试')),
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
