import '../../rules/application/feed_visibility.dart';
import '../../rules/application/rules_providers.dart';
import '../../rules/domain/content_rules.dart';
import '../../rules/presentation/blocking_actions.dart';
import '../../rules/presentation/rule_common.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/library_providers.dart';
import '../domain/library_models.dart';
import 'library_common.dart';
import 'library_paged_list.dart';

Future<void> showContentActions(
  BuildContext context,
  ContentSnapshot item, {
  RuleSubject? ruleSubject,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 600),
  builder: (_) => ContentActionsSheet(item: item, ruleSubject: ruleSubject),
);

class ContentActionsButton extends StatelessWidget {
  const ContentActionsButton({required this.item, this.ruleSubject, super.key});
  final ContentSnapshot item;
  final RuleSubject? ruleSubject;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '收藏与稍后看',
    icon: const Icon(Icons.bookmark_add_outlined),
    onPressed: () =>
        showContentActions(context, item, ruleSubject: ruleSubject),
  );
}

class ContentActionsSheet extends ConsumerStatefulWidget {
  const ContentActionsSheet({required this.item, this.ruleSubject, super.key});
  final ContentSnapshot item;
  final RuleSubject? ruleSubject;
  @override
  ConsumerState<ContentActionsSheet> createState() =>
      _ContentActionsSheetState();
}

class _ContentActionsSheetState extends ConsumerState<ContentActionsSheet> {
  bool _busy = false;
  String? _error;
  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = libraryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemState = ref.watch(libraryItemStateProvider(widget.item.identity));
    final folders = ref.watch(libraryFoldersProvider);
    final subscriptionProvider = isSubscribedProvider(
      widget.item.creator?.mid ?? '',
    );
    final subscriptions = ref.watch(subscriptionProvider);
    final repository = ref.read(libraryRepositoryProvider);
    final disabled = _busy || itemState.isLoading || folders.loading;
    return SizedBox(
      height: math.min(580, MediaQuery.sizeOf(context).height * .8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: LibraryAsync(
              value: itemState,
              retry: () => ref.invalidate(
                libraryItemStateProvider(widget.item.identity),
              ),
              builder: (state) => LibraryPagedList(
                state: folders,
                pager: ref.read(libraryFoldersProvider.notifier),
                empty: '还没有收藏夹',
                header: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('稍后看'),
                      secondary: const Icon(Icons.watch_later_outlined),
                      value: state.later,
                      onChanged: disabled
                          ? null
                          : (value) => _act(
                              () => repository.setLater(widget.item, value),
                            ),
                    ),
                    if (widget.item.creator case final creator?)
                      subscriptions.when(
                        loading: () => const ListTile(
                          title: Text('订阅'),
                          trailing: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (error, _) => ListTile(
                          title: Text(libraryError(error)),
                          trailing: IconButton(
                            tooltip: '重试订阅',
                            onPressed: () =>
                                ref.invalidate(subscriptionProvider),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                        data: (subscribed) => SwitchListTile(
                          title: Text(
                            creator.name.isEmpty
                                ? '订阅 UP ${creator.mid}'
                                : '订阅 ${creator.name}',
                          ),
                          secondary: const Icon(Icons.person_add_alt),
                          value: subscribed,
                          onChanged: _busy || subscriptions.isLoading
                              ? null
                              : (value) => _act(
                                  () => value
                                      ? repository.subscribe(creator)
                                      : repository.unsubscribe(creator.mid),
                                ),
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.block_outlined),
                      title: const Text('屏蔽'),
                      enabled: !_busy,
                      onTap: () async {
                        final rules = ref.read(rulesRepositoryProvider);
                        final change = await requestContentRule(
                          context,
                          rules,
                          widget.ruleSubject ?? RuleSubjects.saved(widget.item),
                        );
                        if (change != null && context.mounted) {
                          showRuleUndo(context, rules, change, label: '已屏蔽');
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined),
                      title: const Text('新建收藏夹'),
                      enabled: !disabled,
                      onTap: () async {
                        final name = await requestLibraryName(context);
                        if (name != null && mounted) {
                          await _act(() async {
                            await repository.createFolder(name);
                          });
                        }
                      },
                    ),
                  ],
                ),
                itemBuilder: (context, folder) => CheckboxListTile(
                  title: Text(folder.name),
                  value: state.folderIds.contains(folder.id),
                  onChanged: disabled
                      ? null
                      : (value) => _act(
                          () => repository.setCollected(
                            widget.item,
                            folder.id,
                            value ?? false,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
