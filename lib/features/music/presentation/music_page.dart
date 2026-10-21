import 'dart:async';

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
import '../../library/application/library_providers.dart';
import '../application/music_providers.dart';
import '../data/music_catalog_repository.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

/// What the catalogue is narrowed to: singers together, a year, a title.
class MusicQuery {
  const MusicQuery({
    this.keyword = '',
    this.members = const {},
    this.year,
    this.oldest = false,
  });
  final String keyword;
  final Set<String> members;
  final int? year;
  final bool oldest;

  MusicQuery copyWith({
    String? keyword,
    Set<String>? members,
    int? year,
    bool clearYear = false,
    bool? oldest,
  }) => MusicQuery(
    keyword: keyword ?? this.keyword,
    members: members ?? this.members,
    year: clearYear ? null : year ?? this.year,
    oldest: oldest ?? this.oldest,
  );

  bool matches(MusicTrack track) =>
      (keyword.isEmpty ||
          track.title.toLowerCase().contains(keyword.toLowerCase())) &&
      members.every(track.members.contains) &&
      (year == null || track.date.year == year);
}

/// Members as the dynamics filter lists them. Those who have left wait
/// behind 更多成员, including their songs.
const _members = ['嘉然', '贝拉', '乃琳', '心宜', '思诺'];
const _moreMembers = ['向晚', '珈乐'];

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});
  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  var _query = const MusicQuery();
  bool get _moreOpen => ref.read(musicMoreMembersProvider);
  bool? _shownMore;

  /// Filtering 5,000 songs is cheap, but not on every rebuild.
  MusicCatalog? _catalog;
  MusicQuery? _shownQuery;
  List<MusicTrack> _shown = const [];

  void _apply(MusicQuery query) => setState(() => _query = query);

  void _filter(MusicCatalog catalog) {
    if (identical(catalog, _catalog) &&
        identical(_query, _shownQuery) &&
        _shownMore == _moreOpen) {
      return;
    }
    _catalog = catalog;
    _shownQuery = _query;
    _shownMore = _moreOpen;
    // Newest day first; within a day, the catalogue's own order.
    _shown = [
      for (final session in musicSessions(
        catalog.tracks.where(
          (track) =>
              (_moreOpen || !track.hasMoreMembers) && _query.matches(track),
        ),
        oldest: _query.oldest,
      ))
        ...session.tracks,
    ];
  }

  Future<void> _toggleMore() async {
    if (!_moreOpen && !await confirmMoreMembers(context)) return;
    if (!mounted) return;
    setState(() {
      ref.read(musicMoreMembersProvider.notifier).state = !_moreOpen;
      if (!_moreOpen) {
        _query = _query.copyWith(
          members: _query.members.difference(_moreMembers.toSet()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(musicCatalogProvider);
    ref.watch(musicMoreMembersProvider);
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    final kept = ref.watch(musicFavoriteIdsProvider).valueOrNull?.length;
    final theme = Theme.of(context);
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AppTokens.gutter(constraints.maxWidth);
          final narrow = constraints.maxWidth < 600;
          final value = catalog.valueOrNull;
          if (value != null) _filter(value);
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
                RootHeading(
                  title: '音乐',
                  actions: [
                    AppButton.withIcon(
                      onPressed: () => context.go('/music/favorites'),
                      icon: const Icon(Icons.favorite_rounded, size: 18),
                      label: Text(
                        [narrow ? '收藏' : '收藏的歌', ?kept?.toString()].join(' '),
                      ),
                    ),
                    MusicStudioButton(compact: narrow),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ContentSearchControl.rowWidth,
                    ),
                    child: SizedBox(
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
                ),
              ],
            ),
          );
          bool sang(String member) =>
              value?.tracks.any((t) => t.members.contains(member)) ?? true;
          final hidden = _moreMembers.where(sang).toList();
          Widget member(String name) => MemberChoiceButton(
            label: name,
            members: [name],
            selected: _query.members.contains(name),
            onPressed: () => _apply(
              _query.copyWith(
                members: _query.members.contains(name)
                    ? ({..._query.members}..remove(name))
                    : {..._query.members, name},
              ),
            ),
          );
          final members = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
            child: Row(
              spacing: 8,
              children: [
                for (final name in _members.where(sang)) member(name),
                if (_moreOpen)
                  for (final name in hidden) member(name),
                if (hidden.isNotEmpty)
                  AppButton(
                    onPressed: _toggleMore,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_moreOpen ? '收起' : '更多成员'),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: _moreOpen ? .5 : 0,
                          duration: appMotion(context, AppTokens.controlMotion),
                          child: const Icon(Icons.expand_more, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
          final years = _years(value);
          final sectionHeader = Padding(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: _query.keyword.isEmpty ? '歌曲' : '搜索结果',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            if (value != null)
                              TextSpan(
                                text: '  ${_shown.length} 首',
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
                const SizedBox(height: 8),
                AppButton.withIcon(
                  tonal: true,
                  onPressed: _shown.isEmpty
                      ? null
                      : () => ref
                            .read(musicAudioHandlerProvider)
                            .playTracks(_shown, shuffle: true),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('随机播放'),
                ),
              ],
            ),
          );
          final Widget? placeholder = switch (catalog) {
            AsyncValue(hasValue: true) when _shown.isEmpty => Center(
              child: Text(_query.keyword.isEmpty ? '没有符合条件的歌' : '没有找到这首歌'),
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
          final handler = ref.read(musicAudioHandlerProvider);
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
                if (placeholder != null)
                  SliverFillRemaining(hasScrollBody: false, child: placeholder)
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      0,
                      gutter,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    sliver: SliverList.separated(
                      itemCount: _shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => MusicSongTile(
                        track: _shown[index],
                        selected: _shown[index].id == currentId,
                        // On through the list as it is shown.
                        onPlay: () =>
                            unawaited(handler.playTracks(_shown, start: index)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<int> _years(MusicCatalog? catalog) => [
    ...<int>{
      for (final track in catalog?.tracks ?? const <MusicTrack>[])
        if (_moreOpen || !track.hasMoreMembers) track.date.year,
    },
  ]..sort((a, b) => b.compareTo(a));
}
