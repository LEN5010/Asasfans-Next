import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/app_panel.dart';
import '../../../shared/widgets/member_tone.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/query_summary.dart';
import '../../content/presentation/content_search_control.dart';
import '../application/music_providers.dart';
import '../data/music_catalog_repository.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

/// What the catalogue is narrowed to. Members are any-of, as in 二创.
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
      (members.isEmpty || track.members.any(members.contains)) &&
      (year == null || track.date.year == year);
}

/// Members in the strip, in the order the rest of the app lists them; anyone
/// else the catalogue names follows.
const _memberOrder = ['嘉然', '贝拉', '乃琳', '心宜', '思诺', '向晚', '珈乐'];

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});
  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  var _query = const MusicQuery();
  bool _panelOpen = false;

  /// Filtering 5,000 songs is cheap, but not on every rebuild.
  MusicCatalog? _catalog;
  MusicQuery? _shownQuery;
  List<MusicSession> _sessions = const [];
  List<MusicTrack> _shown = const [];

  void _apply(MusicQuery query) => setState(() {
    _query = query;
    _panelOpen = false;
  });

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

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(musicCatalogProvider);
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AppTokens.gutter(constraints.maxWidth);
          final wide = constraints.maxWidth >= 600;
          final value = catalog.valueOrNull;
          if (value != null) _filter(value);
          Widget bounded(Widget child, {double max = AppTokens.readingWidth}) =>
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
                      filter: AppButton.icon(
                        tooltip: '筛选与排序',
                        selected:
                            _panelOpen || _query.year != null || _query.oldest,
                        icon: const Icon(Icons.tune),
                        onPressed: () async {
                          if (wide) {
                            setState(() => _panelOpen = !_panelOpen);
                            return;
                          }
                          final next = await showAppPanel<MusicQuery>(
                            context: context,
                            builder: (context) => _MusicFilterPanel(
                              query: _query,
                              years: _years(value),
                              onApply: (next) => Navigator.pop(context, next),
                              onClose: () => Navigator.pop(context),
                            ),
                          );
                          if (next != null && mounted) _apply(next);
                        },
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: appMotion(context, AppTokens.controlMotion),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !(wide && _panelOpen)
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: bounded(
                            Card(
                              child: _MusicFilterPanel(
                                key: ValueKey(_query),
                                query: _query,
                                years: _years(value),
                                embedded: true,
                                onApply: _apply,
                                onClose: () =>
                                    setState(() => _panelOpen = false),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
          final members = [
            for (final name in _memberOrder)
              if (value?.tracks.any((t) => t.members.contains(name)) ?? true)
                name,
          ];
          final strip = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Row(
              spacing: 6,
              children: [
                MemberQuickChip(
                  label: '全部成员',
                  selected: _query.members.isEmpty,
                  onTap: () => _apply(_query.copyWith(members: const {})),
                ),
                for (final member in members)
                  MemberQuickChip(
                    label: member,
                    members: [member],
                    selected: _query.members.contains(member),
                    onTap: () => _apply(
                      _query.copyWith(
                        members: _query.members.contains(member)
                            ? _query.members.difference({member})
                            : {..._query.members, member},
                      ),
                    ),
                  ),
              ],
            ),
          );
          final summary = QuerySummary(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter - 8, 0),
            status: value == null ? null : '${_shown.length} 首',
            clearLabel: '清除条件',
            clearTooltip: '清除条件，成员不变',
            onClear: () => _apply(MusicQuery(members: _query.members)),
            applied: [
              if (_query.keyword.isNotEmpty)
                (
                  label: '“${_query.keyword}”',
                  remove: () => _apply(_query.copyWith(keyword: '')),
                ),
              if (_query.year case final year?)
                (
                  label: '$year 年',
                  remove: () => _apply(_query.copyWith(clearYear: true)),
                ),
              if (_query.oldest)
                (
                  label: '最早在前',
                  remove: () => _apply(_query.copyWith(oldest: false)),
                ),
            ],
          );
          final Widget? placeholder = switch (catalog) {
            AsyncValue(hasValue: true) when _sessions.isEmpty => const Center(
              child: Text('没有符合条件的歌回'),
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
                SliverToBoxAdapter(child: strip),
                SliverToBoxAdapter(child: summary),
                if (value?.warning case final warning?)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        warning,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (placeholder != null)
                  SliverFillRemaining(hasScrollBody: false, child: placeholder)
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      12,
                      gutter,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    sliver: SliverList.separated(
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTokens.itemGap),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return bounded(
                          MusicSessionCard(
                            session: session,
                            currentId: currentId,
                            onPlayDay: () =>
                                unawaited(handler.playTracks(session.tracks)),
                            // A song plays on through the list as shown, into
                            // the days after it.
                            onPlayTrack: (at) => unawaited(
                              handler.playTracks(
                                _shown,
                                start: _shown.indexOf(session.tracks[at]),
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

class _MusicFilterPanel extends StatefulWidget {
  const _MusicFilterPanel({
    super.key,
    required this.query,
    required this.years,
    required this.onApply,
    required this.onClose,
    this.embedded = false,
  });
  final MusicQuery query;
  final List<int> years;
  final ValueChanged<MusicQuery> onApply;
  final VoidCallback onClose;
  final bool embedded;
  @override
  State<_MusicFilterPanel> createState() => _MusicFilterPanelState();
}

class _MusicFilterPanelState extends State<_MusicFilterPanel> {
  late var _draft = widget.query;

  @override
  Widget build(BuildContext context) => AppFilterPanel(
    title: '筛选歌回',
    embedded: widget.embedded,
    onReset: () => setState(
      () =>
          _draft = MusicQuery(keyword: _draft.keyword, members: _draft.members),
    ),
    onApply: () => widget.onApply(_draft),
    onClose: widget.onClose,
    sections: [
      AppFilterSection(
        title: '年份',
        child: AppChoiceWrap<int?>(
          values: [null, ...widget.years],
          labelOf: (year) => year == null ? '全部年份' : '$year',
          selected: _draft.year,
          onChanged: (year) => setState(
            () => _draft = year == null
                ? _draft.copyWith(clearYear: true)
                : _draft.copyWith(year: year),
          ),
        ),
      ),
      AppFilterSection(
        title: '排序',
        child: AppSegments<bool>(
          values: const [false, true],
          labelOf: (oldest) => oldest ? '最早在前' : '最新在前',
          selected: _draft.oldest,
          onChanged: (oldest) =>
              setState(() => _draft = _draft.copyWith(oldest: oldest)),
        ),
      ),
    ],
  );
}
