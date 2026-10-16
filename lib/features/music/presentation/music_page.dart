import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/music_providers.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});
  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  String _keyword = '';
  String? _member;
  int? _year;
  bool? _live;
  bool _oldest = false;
  bool _filtersOpen = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _filters(List<int> years, VoidCallback update) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      DropdownButton<int>(
        value: _year,
        hint: const Text('全部年份'),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('全部年份')),
          for (final year in years)
            DropdownMenuItem(value: year, child: Text('$year')),
        ],
        onChanged: (v) {
          setState(() => _year = v);
          update();
        },
      ),
      DropdownButton<bool>(
        value: _live,
        hint: const Text('全部版本'),
        items: const [
          DropdownMenuItem<bool>(value: null, child: Text('全部版本')),
          DropdownMenuItem(value: false, child: Text('完整')),
          DropdownMenuItem(value: true, child: Text('Live')),
        ],
        onChanged: (v) {
          setState(() => _live = v);
          update();
        },
      ),
      DropdownButton<bool>(
        value: _oldest,
        items: const [
          DropdownMenuItem(value: false, child: Text('最新在前')),
          DropdownMenuItem(value: true, child: Text('最早在前')),
        ],
        onChanged: (v) {
          setState(() => _oldest = v!);
          update();
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(musicCatalogProvider);
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        controlExtent: MediaQuery.textScalerOf(context).scale(28) * 1.3 < 48
            ? 48
            : MediaQuery.textScalerOf(context).scale(28) * 1.3,
        title: const Text(
          '音乐',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        actions: const [MusicStudioButton()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('暂时无法读取歌单'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(musicCatalogProvider),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
            data: (value) {
              final years =
                  value.tracks.map((t) => t.date.year).toSet().toList()
                    ..sort((a, b) => b.compareTo(a));
              final tracks =
                  value.tracks
                      .where(
                        (t) =>
                            (_keyword.isEmpty ||
                                t.title.toLowerCase().contains(
                                  _keyword.toLowerCase(),
                                )) &&
                            (_member == null || t.members.contains(_member)) &&
                            (_year == null || t.date.year == _year) &&
                            (_live == null || t.isLive == _live),
                      )
                      .toList()
                    ..sort((a, b) {
                      final date = a.date.compareTo(b.date);
                      return (_oldest ? date : -date);
                    });
              final groups = <String, List<MusicTrack>>{};
              for (final track in tracks) {
                groups.putIfAbsent(track.sessionKey, () => []).add(track);
              }
              final sessions = groups.values.toList();
              final entries = <Object>[];
              for (final session in sessions) {
                entries.add(session);
                entries.addAll(session);
              }
              final padding = pageInsets(context);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(musicCatalogProvider);
                  await ref.read(musicCatalogProvider.future);
                },
                child: CustomScrollView(
                  key: const PageStorageKey('music-catalog'),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        padding.top,
                        padding.right,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _search,
                                        onChanged: (v) =>
                                            setState(() => _keyword = v.trim()),
                                        decoration: const InputDecoration(
                                          hintText: '搜索歌名',
                                          prefixIcon: Icon(Icons.search),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      tooltip: '筛选',
                                      onPressed: () {
                                        if (wide) {
                                          setState(
                                            () => _filtersOpen = !_filtersOpen,
                                          );
                                        } else {
                                          showModalBottomSheet<void>(
                                            context: context,
                                            isScrollControlled: true,
                                            showDragHandle: true,
                                            builder: (context) => SafeArea(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      24,
                                                      8,
                                                      24,
                                                      24,
                                                    ),
                                                child: StatefulBuilder(
                                                  builder: (context, update) =>
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            '筛选',
                                                            style: TextStyle(
                                                              fontSize: 19,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 16,
                                                          ),
                                                          _filters(
                                                            years,
                                                            () => update(() {}),
                                                          ),
                                                        ],
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.tune),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('全部'),
                                      selected: _member == null,
                                      onSelected: (_) =>
                                          setState(() => _member = null),
                                    ),
                                    for (final member in const [
                                      '贝拉',
                                      '嘉然',
                                      '乃琳',
                                      '向晚',
                                      '珈乐',
                                      '心宜',
                                      '思诺',
                                    ])
                                      ChoiceChip(
                                        avatar: MemberDots(members: [member]),
                                        label: Text(member),
                                        selected: _member == member,
                                        onSelected: (selected) => setState(
                                          () => _member = selected
                                              ? member
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                                if (wide && _filtersOpen)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _filters(years, () {}),
                                  ),
                                if (value.warning != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      value.warning!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                if (tracks.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(child: Text('没有符合条件的歌回')),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: padding.left),
                      sliver: SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: entry is List<MusicTrack>
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        top: 16,
                                        bottom: 8,
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 16,
                                        children: [
                                          Text(
                                            '${entry.first.dateLabel} · ${entry.first.singers} · ${entry.length} 首',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => unawaited(
                                              ref
                                                  .read(
                                                    musicAudioHandlerProvider,
                                                  )
                                                  .playTracks(entry),
                                            ),
                                            icon: const Icon(
                                              Icons.play_arrow,
                                              size: 18,
                                            ),
                                            label: const Text('播放这场'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : MusicSurface(
                                      child: MusicTrackRow(
                                        track: entry as MusicTrack,
                                        selected: currentId == entry.id,
                                        onPlay: () => unawaited(
                                          ref
                                              .read(musicAudioHandlerProvider)
                                              .playTracks(
                                                tracks,
                                                start: tracks.indexOf(entry),
                                              ),
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: padding.bottom + 24),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
