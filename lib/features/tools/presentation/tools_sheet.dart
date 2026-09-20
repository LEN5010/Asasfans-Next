import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/community_tool.dart';

Future<void> showToolsSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (context) => const ToolsSheet(),
);

class ToolsSheet extends ConsumerWidget {
  const ToolsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '工具',
                    style: Theme.of(context).textTheme.headlineSmall,
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
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisExtent: 120,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: communityTools.length,
              itemBuilder: (context, index) {
                final tool = communityTools[index];
                return Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      final opened = await ref
                          .read(externalLinkServiceProvider)
                          .open(Uri.parse(tool.url));
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                _toolIcon(tool.id),
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tool.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

IconData _toolIcon(String id) => switch (id) {
  'studio' => Icons.headphones_outlined,
  'calendar' => Icons.calendar_month_outlined,
  'dynamics' => Icons.dynamic_feed_outlined,
  'fanart' => Icons.palette_outlined,
  'navigation' => Icons.explore_outlined,
  'cnki' => Icons.fingerprint,
  'book' => Icons.edit_note,
  'rank' => Icons.leaderboard_outlined,
  'wiki' => Icons.menu_book_outlined,
  'recordings' => Icons.video_library_outlined,
  'bili-tools' => Icons.build_outlined,
  'subtitles' => Icons.subtitles_outlined,
  'aicu' => Icons.manage_search,
  'vtbs' => Icons.groups_outlined,
  _ => Icons.open_in_new,
};
