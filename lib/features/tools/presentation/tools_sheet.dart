import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/app_panel.dart';
import '../domain/community_tool.dart';

Future<void> showToolsSheet(BuildContext context) async {
  await showAppPanel<void>(
    context: context,
    builder: (_) => const ToolsSheet(),
  );
}

class ToolsSheet extends ConsumerStatefulWidget {
  const ToolsSheet({super.key});
  @override
  ConsumerState<ToolsSheet> createState() => _ToolsSheetState();
}

class _ToolsSheetState extends ConsumerState<ToolsSheet> {
  String _keyword = '';
  bool _opening = false;
  bool _openFailed = false;

  Future<void> _open(CommunityTool tool) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final opened = await ref
        .read(externalLinkServiceProvider)
        .open(Uri.parse(tool.url));
    if (mounted) {
      setState(() {
        _opening = false;
        _openFailed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _keyword.trim().toLowerCase();
    final visible = communityTools
        .where(
          (tool) => '${tool.name} ${tool.id}'.toLowerCase().contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '工具',
                  style: Theme.of(context).textTheme.titleLarge,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            maxLength: 100,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '搜索工具',
              counterText: '',
              isDense: true,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() {
              _keyword = value;
              _openFailed = false;
            }),
          ),
        ),
        const SizedBox(height: 8),
        if (_openFailed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                '无法打开链接',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('没有匹配的工具'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final scaler = MediaQuery.textScalerOf(context);
                    final minimum = 128 * scaler.scale(1).clamp(1.0, 1.4);
                    final columns =
                        ((constraints.maxWidth - 40 + 12) / (minimum + 12))
                            .floor()
                            .clamp(1, 5);
                    return CustomScrollView(
                      slivers: [
                        for (final category in ToolCategory.values) ...[
                          if (visible.any(
                            (tool) => tool.category == category,
                          )) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  14,
                                  20,
                                  10,
                                ),
                                child: Text(
                                  switch (category) {
                                    ToolCategory.content => '内容',
                                    ToolCategory.community => '社区',
                                    ToolCategory.utility => '实用工具',
                                  },
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      mainAxisExtent:
                                          80 +
                                          (scaler.scale(14) * 1.35)
                                                  .ceilToDouble() *
                                              2,
                                    ),
                                delegate: SliverChildListDelegate([
                                  for (final tool in visible.where(
                                    (tool) => tool.category == category,
                                  ))
                                    _ToolTile(
                                      tool: tool,
                                      onTap: _opening
                                          ? null
                                          : () => _open(tool),
                                    ),
                                ]),
                              ),
                            ),
                          ],
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});
  final CommunityTool tool;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _toolIcon(tool.id),
                  size: 23,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tool.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ],
          ),
        ),
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
