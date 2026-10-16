import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../content/presentation/content_images.dart';
import '../../content/presentation/content_search_control.dart';
import '../application/music_providers.dart';
import '../data/music_catalog_repository.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

/// What the catalogue is narrowed to: one singer, one year, a title.
class MusicQuery {
  const MusicQuery({
    this.keyword = '',
    this.member,
    this.year,
    this.oldest = false,
  });
  final String keyword;
  final String? member;
  final int? year;
  final bool oldest;

  MusicQuery copyWith({
    String? keyword,
    String? member,
    bool clearMember = false,
    int? year,
    bool clearYear = false,
    bool? oldest,
  }) => MusicQuery(
    keyword: keyword ?? this.keyword,
    member: clearMember ? null : member ?? this.member,
    year: clearYear ? null : year ?? this.year,
    oldest: oldest ?? this.oldest,
  );

  bool matches(MusicTrack track) =>
      (keyword.isEmpty ||
          track.title.toLowerCase().contains(keyword.toLowerCase())) &&
      (member == null || track.members.contains(member)) &&
      (year == null || track.date.year == year);
}

/// Members in the avatar row. Those who have left wait behind 更多, as in
/// the dynamics filter; their songs stay in 全部.
const _members = ['嘉然', '贝拉', '乃琳', '心宜', '思诺'];
const _moreMembers = ['向晚', '珈乐'];

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});
  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  var _query = const MusicQuery();
  bool _moreOpen = false;

  /// Filtering 5,000 songs is cheap, but not on every rebuild.
  MusicCatalog? _catalog;
  MusicQuery? _shownQuery;
  List<MusicSession> _sessions = const [];
  List<MusicTrack> _shown = const [];

  void _apply(MusicQuery query) => setState(() => _query = query);

  void _filter(MusicCatalog catalog) {
    if (identical(catalog, _catalog) && identical(_query, _shownQuery)) return;
    _catalog = catalog;
    _shownQuery = _query;
    _sessions = musicSessions(
      catalog.tracks.where(_query.matches),
      oldest: _query.oldest,
    );
    _shown = [for (final session in _sessions) ...session.tracks];
  }

  Future<void> _toggleMore() async {
    if (!_moreOpen && !await confirmMoreMembers(context)) return;
    if (!mounted) return;
    setState(() {
      _moreOpen = !_moreOpen;
      if (!_moreOpen && _moreMembers.contains(_query.member)) {
        _query = _query.copyWith(clearMember: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(musicCatalogProvider);
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    final theme = Theme.of(context);
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AppTokens.gutter(constraints.maxWidth);
          final width = math.min(constraints.maxWidth, AppTokens.pageWidth);
          final value = catalog.valueOrNull;
          if (value != null) _filter(value);
          final searching = _query.keyword.isNotEmpty;
          Widget bounded(Widget child, {double max = AppTokens.pageWidth}) =>
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: max),
                  child: child,
                ),
              );
          final header = Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              MediaQuery.paddingOf(context).top + 16,
              gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bounded(
                  const RootHeading(
                    title: '音乐',
                    actions: [MusicStudioButton()],
                  ),
                ),
                const SizedBox(height: 12),
                bounded(
                  max: ContentSearchControl.rowWidth,
                  SizedBox(
                    width: double.infinity,
                    child: ContentSearchControl(
                      value: _query.keyword,
                      hint: '搜索歌名',
                      expanded: true,
                      onSubmitted: (keyword) =>
                          _apply(_query.copyWith(keyword: keyword)),
                    ),
                  ),
                ),
              ],
            ),
          );
          bool sang(String member) =>
              value?.tracks.any((t) => t.members.contains(member)) ?? true;
          final hidden = _moreMembers.where(sang).toList();
          final members = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(gutter - 6, 16, gutter - 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MemberOption(
                  label: '全部',
                  selected: _query.member == null,
                  onTap: () => _apply(_query.copyWith(clearMember: true)),
                  icon: Icons.library_music_rounded,
                ),
                for (final member in [
                  ..._members.where(sang),
                  if (_moreOpen) ...hidden,
                ])
                  _MemberOption(
                    label: member,
                    member: member,
                    selected: _query.member == member,
                    onTap: () => _apply(
                      _query.member == member
                          ? _query.copyWith(clearMember: true)
                          : _query.copyWith(member: member),
                    ),
                  ),
                if (hidden.isNotEmpty)
                  _MemberOption(
                    label: _moreOpen ? '收起' : '更多',
                    selected: false,
                    onTap: _toggleMore,
                    icon: _moreOpen
                        ? Icons.chevron_left_rounded
                        : Icons.more_horiz_rounded,
                  ),
              ],
            ),
          );
          final years = _years(value);
          final count = value == null
              ? null
              : searching
              ? '${_shown.length} 首'
              : '${_sessions.length} 天 · ${_shown.length} 首';
          final sectionHeader = Padding(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter - 6, 4),
            child: bounded(
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: searching ? '搜索结果' : '歌回',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          if (count != null)
                            TextSpan(
                              text: '  $count',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  MenuAnchor(
                    menuChildren: [
                      for (final year in [null, ...years])
                        MenuItemButton(
                          trailingIcon: year == _query.year
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onPressed: () => _apply(
                            year == null
                                ? _query.copyWith(clearYear: true)
                                : _query.copyWith(year: year),
                          ),
                          child: Text(year == null ? '全部年份' : '$year 年'),
                        ),
                    ],
                    builder: (context, menu, _) => AppButton(
                      selected: _query.year != null,
                      onPressed: years.isEmpty
                          ? null
                          : () => menu.isOpen ? menu.close() : menu.open(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _query.year == null ? '全部年份' : '${_query.year} 年',
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.expand_more, size: 18),
                        ],
                      ),
                    ),
                  ),
                  AppButton.withIcon(
                    onPressed: () =>
                        _apply(_query.copyWith(oldest: !_query.oldest)),
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: Text(_query.oldest ? '最早在前' : '最新在前'),
                  ),
                ],
              ),
            ),
          );
          final Widget? placeholder = switch (catalog) {
            AsyncValue(hasValue: true) when _sessions.isEmpty => Center(
              child: Text(searching ? '没有找到这首歌' : '没有符合条件的歌回'),
            ),
            AsyncValue(hasValue: true) => null,
            AsyncValue(hasError: true) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('暂时无法读取歌单'),
                  const SizedBox(height: 12),
                  AppButton(
                    selected: true,
                    onPressed: () => ref.invalidate(musicCatalogProvider),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          };
          final bottom = MediaQuery.paddingOf(context).bottom + 24;
          final Widget results;
          if (placeholder != null) {
            results = SliverFillRemaining(
              hasScrollBody: false,
              child: placeholder,
            );
          } else if (searching) {
            final handler = ref.read(musicAudioHandlerProvider);
            results = SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter - 8, 0, gutter - 8, bottom),
              sliver: SliverList.builder(
                itemCount: _shown.length,
                itemBuilder: (context, index) => bounded(
                  max: AppTokens.readingWidth,
                  MusicTrackRow(
                    track: _shown[index],
                    selected: _shown[index].id == currentId,
                    // On through the results, as they are listed.
                    onPlay: () =>
                        unawaited(handler.playTracks(_shown, start: index)),
                  ),
                ),
              ),
            );
          } else {
            // Album tiles about 180 wide: two across a phone, more as the
            // window grows. A tile's height is its square cover and two
            // lines at the current text size.
            final columns = math.max(
              2,
              ((width - 2 * gutter + 12) / 192).floor(),
            );
            final tile = (width - 2 * gutter + 12) / columns;
            final scaler = MediaQuery.textScalerOf(context);
            double line(TextStyle? style) =>
                scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.5);
            final extent =
                tile +
                8 +
                line(theme.textTheme.titleSmall) +
                2 +
                line(theme.textTheme.bodySmall) +
                6;
            results = SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter - 6,
                0,
                constraints.maxWidth - width + gutter - 6,
                bottom,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: extent,
                ),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return MusicDayCard(
                    session: session,
                    onOpen: () => context.go('/music/day/${session.key}'),
                  );
                },
              ),
            );
          }
          return RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: () async {
              ref.invalidate(musicCatalogProvider);
              await ref.read(musicCatalogProvider.future);
            },
            child: CustomScrollView(
              key: const PageStorageKey('music-catalog'),
              slivers: [
                SliverToBoxAdapter(child: header),
                SliverToBoxAdapter(child: members),
                SliverToBoxAdapter(child: sectionHeader),
                if (value?.warning case final warning?)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(warning, style: theme.textTheme.bodySmall),
                    ),
                  ),
                results,
              ],
            ),
          );
        },
      ),
    );
  }

  static List<int> _years(MusicCatalog? catalog) => [
    ...<int>{
      for (final track in catalog?.tracks ?? const <MusicTrack>[])
        track.date.year,
    },
  ]..sort((a, b) => b.compareTo(a));
}

/// A singer as a round picture with her name under it, as music apps list
/// artists; chosen, it gains a ring in her colour. Without [member] it is
/// [icon] on a plain disc, for 全部 and 更多.
class _MemberOption extends StatelessWidget {
  const _MemberOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.member,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? member;
  final IconData? icon;

  static const size = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ring = member == null
        ? colors.primary
        : AppTheme.memberColors[member] ?? colors.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: appMotion(context, AppTokens.controlMotion),
                  curve: AppCurves.standard,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? ring : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: member == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surfaceContainerHigh,
                          ),
                          child: SizedBox.square(
                            dimension: size,
                            child: Icon(
                              icon,
                              color: colors.onSurfaceVariant,
                              size: 26,
                            ),
                          ),
                        )
                      : MusicCover(
                          members: [member!],
                          size: size,
                          radius: size / 2,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
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
