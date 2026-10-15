import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/theme/app_icons.dart';
import '../../../shared/widgets/app_panel.dart';
import '../../../shared/widgets/member_tone.dart';
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
          (tool) => '${tool.name} ${tool.id} ${_address(tool)}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppPanelHeader(title: '工具'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            maxLength: 100,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '搜索工具',
              filled: true,
              counterText: '',
              isDense: true,
              prefixIcon: Icon(AppIcons.search),
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
                    final minimum = 168 * scaler.scale(1);
                    final columns =
                        ((constraints.maxWidth - 40 + 10) / (minimum + 10))
                            .floor()
                            .clamp(1, 3);
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
                                // The kind, and how many of it are shown.
                                child: Row(
                                  spacing: 8,
                                  children: [
                                    Text(
                                      switch (category) {
                                        ToolCategory.content => '内容',
                                        ToolCategory.community => '社区',
                                        ToolCategory.utility => '实用工具',
                                      },
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      '${visible.where((tool) => tool.category == category).length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontFeatures: AppTheme.tabular,
                                          ),
                                    ),
                                  ],
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
                                      mainAxisExtent: _ToolTile.extent(scaler),
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

/// Where a tool goes, as its address reads: the host without www, and the
/// path when there is one (two tools share len5010.top).
String _address(CommunityTool tool) {
  final uri = Uri.parse(tool.url);
  final path = uri.path.replaceFirst(RegExp(r'/$'), '');
  return '${uri.host.replaceFirst(RegExp(r'^www\.'), '')}$path';
}

/// A tool as a small launcher card: its mark in a support colour, its name,
/// and the address it opens in the browser.
class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});
  final CommunityTool tool;
  final VoidCallback? onTap;

  /// Neighbouring tiles take neighbouring support colours.
  static const _tones = ['嘉然', '乃琳', '贝拉', '心宜', '思诺', 'A-SOUL'];

  static double extent(TextScaler scaler) =>
      24 +
      math.max(
        40,
        (scaler.scale(14) * 1.35).ceilToDouble() +
            (scaler.scale(12) * 1.35).ceilToDouble() +
            2,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = _tones[communityTools.indexOf(tool) % _tones.length];
    return Tooltip(
      message: tool.url,
      child: Material(
        color: colors.surfaceContainerHigh.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ToneBadge(icon: _toolIcon(tool.id), member: tone, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _address(tool),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
