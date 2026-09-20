import '../../creator/presentation/creator_link.dart';
import '../../subscriptions/presentation/subscription_feed_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';
import '../domain/library_page.dart';
import '../application/library_pager.dart';
import 'library_paged_list.dart';
import 'content_actions.dart';
import 'library_common.dart';
import 'saved_content_page.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(libraryFoldersProvider);
    final repository = ref.read(libraryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏夹'),
        actions: [
          IconButton(
            tooltip: '新建收藏夹',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              final name = await requestLibraryName(context);
              if (name != null && context.mounted) {
                await libraryAction(context, () async {
                  await repository.createFolder(name);
                });
              }
            },
          ),
        ],
      ),
      body: LibraryBody(
        child: LibraryPagedList(
          state: folders,
          pager: ref.read(libraryFoldersProvider.notifier),
          empty: '还没有收藏夹',
          itemBuilder: (context, folder) {
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              subtitle: Text('${folder.count} 项'),
              onTap: () => context.push('/mine/saved/${folder.id}'),
              trailing: folder.isDefault
                  ? const Icon(Icons.chevron_right)
                  : PopupMenuButton<String>(
                      tooltip: '管理收藏夹',
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'delete', child: Text('删除收藏夹')),
                      ],
                      onSelected: (action) async {
                        if (action == 'rename') {
                          final name = await requestLibraryName(
                            context,
                            initial: folder.name,
                            title: '重命名',
                          );
                          if (name != null && context.mounted) {
                            await libraryAction(
                              context,
                              () => repository.renameFolder(folder.id, name),
                            );
                          }
                        } else if (await confirmLibraryAction(
                              context,
                              '删除「${folder.name}」？',
                              body: '仅移除此收藏夹，不影响其他收藏夹、稍后看与历史记录。',
                            ) &&
                            context.mounted) {
                          await libraryAction(
                            context,
                            () => repository.deleteFolder(folder.id),
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

class CollectionPage extends ConsumerWidget {
  const CollectionPage({required this.folderId, super.key});
  final String folderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = libraryRecordsProvider(LibraryQuery.collection(folderId));
    final records = ref.watch(provider);
    final folderState = ref.watch(collectionFolderProvider(folderId));
    final folder = folderState.valueOrNull;
    if (folderState.hasValue && !folderState.isLoading && folder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('收藏夹')),
        body: const Center(child: Text('收藏夹不存在')),
      );
    }
    final name = folder?.name ?? '收藏夹';
    final repository = ref.read(libraryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: LibraryBody(
        child: LibraryRecordList(
          state: records,
          pager: ref.read(provider.notifier),
          empty: '收藏夹里还没有内容',
          removeLabel: '移出收藏夹',
          onRemove: (entry) => libraryAction(
            context,
            () => repository.setCollected(entry.item, folderId, false),
          ),
        ),
      ),
    );
  }
}

class WatchLaterPage extends ConsumerStatefulWidget {
  const WatchLaterPage({super.key});
  @override
  ConsumerState<WatchLaterPage> createState() => _WatchLaterPageState();
}

class _WatchLaterPageState extends ConsumerState<WatchLaterPage> {
  bool _pendingOnly = true;
  @override
  Widget build(BuildContext context) {
    final provider = libraryRecordsProvider(
      LibraryQuery.later(pendingOnly: _pendingOnly),
    );
    final records = ref.watch(provider);
    final repository = ref.read(libraryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('稍后看')),
      body: LibraryBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('待处理'),
                    selected: _pendingOnly,
                    onSelected: (_) => setState(() => _pendingOnly = true),
                  ),
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: !_pendingOnly,
                    onSelected: (_) => setState(() => _pendingOnly = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LibraryRecordList(
                state: records,
                pager: ref.read(provider.notifier),
                empty: _pendingOnly ? '没有待处理的内容' : '稍后看里还没有内容',
                removeLabel: '移出稍后看',
                onRemove: (entry) => libraryAction(
                  context,
                  () => repository.setLater(entry.item, false),
                ),
                onDone: (entry) => libraryAction(
                  context,
                  () =>
                      repository.setLaterDone(entry.item.identity, !entry.done),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryHistoryPage extends ConsumerStatefulWidget {
  const LibraryHistoryPage({super.key});
  @override
  ConsumerState<LibraryHistoryPage> createState() => _LibraryHistoryPageState();
}

class _LibraryHistoryPageState extends ConsumerState<LibraryHistoryPage> {
  HistoryAction? _filter;
  @override
  Widget build(BuildContext context) {
    final provider = libraryRecordsProvider(
      LibraryQuery.history(action: _filter),
    );
    final repository = ref.read(libraryRepositoryProvider);
    final records = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            tooltip: '清空当前历史',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: records.items.isEmpty || records.loading
                ? null
                : () async {
                    final action = _filter;
                    if (await confirmLibraryAction(
                          context,
                          '清空${action == null ? '全部' : historyLabel(action)}记录？',
                          body: '不会删除收藏、稍后看或播放进度。',
                        ) &&
                        context.mounted) {
                      await libraryAction(
                        context,
                        () => repository.clearHistory(action: action),
                      );
                    }
                  },
          ),
        ],
      ),
      body: LibraryBody(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (final action in [null, ...HistoryAction.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          action == null ? '全部' : historyLabel(action),
                        ),
                        selected: _filter == action,
                        onSelected: (_) => setState(() => _filter = action),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LibraryRecordList(
                state: records,
                pager: ref.read(provider.notifier),
                empty: '暂无记录',
                removeLabel: '删除这条记录',
                onRemove: (entry) => libraryAction(
                  context,
                  () => repository.removeHistory(
                    entry.item.identity,
                    entry.action!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String historyLabel(HistoryAction action) => switch (action) {
  HistoryAction.detail => '浏览详情',
  HistoryAction.external => '外部打开',
  HistoryAction.playback => '观看',
};

class LibraryRecordList extends StatelessWidget {
  const LibraryRecordList({
    required this.state,
    required this.pager,
    required this.empty,
    required this.removeLabel,
    required this.onRemove,
    this.onDone,
    super.key,
  });
  final LibraryListState<LibraryRecord> state;
  final LibraryPager<LibraryRecord> pager;
  final String empty;
  final String removeLabel;
  final void Function(LibraryRecord) onRemove;
  final void Function(LibraryRecord)? onDone;
  @override
  Widget build(BuildContext context) {
    return LibraryPagedList(
      state: state,
      pager: pager,
      empty: empty,
      itemBuilder: (context, entry) {
        final item = entry.item;
        final image = item.images.firstOrNull;
        final date = entry.at.toLocal();
        return ListTile(
          leading: SizedBox(
            width: 68,
            height: 48,
            child: image == null
                ? Icon(
                    item.kind == LibraryMediaKind.video
                        ? Icons.play_circle_outline
                        : Icons.article_outlined,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      image.toString(),
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (item.authorName.isNotEmpty) item.authorName,
              if (entry.action != null) historyLabel(entry.action!),
              if (entry.done) '已处理',
              '${date.year}-${date.month}-${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => SavedContentPage(item: item),
            ),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: '管理内容',
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'save', child: Text('收藏与稍后看')),
              if (onDone != null)
                PopupMenuItem(
                  value: 'done',
                  child: Text(entry.done ? '恢复待处理' : '标为已处理'),
                ),
              PopupMenuItem(value: 'remove', child: Text(removeLabel)),
            ],
            onSelected: (value) {
              if (value == 'save') {
                showContentActions(context, item);
              } else if (value == 'done') {
                onDone?.call(entry);
              } else {
                onRemove(entry);
              }
            },
          ),
        );
      },
    );
  }
}

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(localSubscriptionsProvider);
    final repository = ref.read(libraryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地订阅'),
        actions: [
          IconButton(
            tooltip: '订阅更新',
            icon: const Icon(Icons.subscriptions_outlined),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('订阅更新')),
                  body: const SubscriptionFeedView(),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '添加 UP',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () async {
              final creator = await showDialog<LocalSubscription>(
                context: context,
                builder: (_) => const _SubscriptionDialog(),
              );
              if (creator != null && context.mounted) {
                await libraryAction(
                  context,
                  () => repository.subscribe(creator),
                );
              }
            },
          ),
        ],
      ),
      body: LibraryBody(
        child: LibraryPagedList(
          state: subscriptions,
          pager: ref.read(localSubscriptionsProvider.notifier),
          empty: '还没有订阅',
          itemBuilder: (context, creator) {
            return ListTile(
              leading: CircleAvatar(
                foregroundImage: creator.avatar == null
                    ? null
                    : ResizeImage(
                        NetworkImage(creator.avatar.toString()),
                        width: 120,
                      ),
                onForegroundImageError: creator.avatar == null
                    ? null
                    : (_, _) {},
                child: const Icon(Icons.person_outline),
              ),
              title: Text(
                creator.name.isEmpty ? 'UP ${creator.mid}' : creator.name,
              ),
              subtitle: Text('UID ${creator.mid}'),
              onTap: () => openCreatorPage(context, creator.mid),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '在 B 站打开 UP 主页',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () async {
                      final opened = await ref
                          .read(externalLinkServiceProvider)
                          .open(creator.sourceUrl);
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
                      }
                    },
                  ),
                  IconButton(
                    tooltip: '取消订阅',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () async {
                      if (await confirmLibraryAction(context, '取消订阅此 UP？') &&
                          context.mounted) {
                        await libraryAction(
                          context,
                          () => repository.unsubscribe(creator.mid),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog();
  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final _mid = TextEditingController();
  final _name = TextEditingController();
  @override
  void dispose() {
    _mid.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加 UP'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _mid,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Bilibili UID'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _name,
            maxLength: 64,
            decoration: const InputDecoration(labelText: '名称（可选）'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: LocalSubscription.validMid(_mid.text.trim())
            ? () => Navigator.pop(
                context,
                LocalSubscription(
                  mid: _mid.text.trim(),
                  name: _name.text.trim(),
                ),
              )
            : null,
        child: const Text('订阅'),
      ),
    ],
  );
}
