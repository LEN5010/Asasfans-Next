import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../application/music_providers.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

/// One day's 歌回 as an album: the cover, the date and who sang, play and
/// shuffle, then every song that day in the catalogue's order.
class MusicDayPage extends ConsumerWidget {
  const MusicDayPage({super.key, required this.day});

  /// A [MusicSession.key].
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(musicCatalogProvider);
    final date = musicDay(day);
    final session = switch (catalog.valueOrNull) {
      final catalog? when date != null => musicSessions(
        catalog.tracks.where((track) => track.date == date),
      ).firstOrNull,
      _ => null,
    };
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('歌回')),
      body: switch (catalog) {
        AsyncValue(hasValue: true) when session == null => const Center(
          child: Text('这一天没有歌回'),
        ),
        AsyncValue(hasValue: true) => _DayBody(session: session!),
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
      },
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({required this.session});
  final MusicSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    final handler = ref.read(musicAudioHandlerProvider);
    final tracks = session.tracks;
    final first = tracks.first;
    final mixed = tracks.any((track) => track.singers != first.singers);
    final insets = pageInsets(context);
    final tone = AppTheme.memberColors[session.members.firstOrNull];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final gutter = AppTokens.gutter(constraints.maxWidth);
        final cover = MusicCover(
          members: session.members,
          size: wide ? 200 : 184,
          radius: 16,
        );
        final details = Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Text(
              first.dateLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: AppTheme.tabular,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${session.members.join('、')} · ${tracks.length} 首 · '
              '${session.duration.inMinutes} 分钟',
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: wide ? WrapAlignment.start : WrapAlignment.center,
              children: [
                AppButton.withIcon(
                  selected: true,
                  onPressed: () => unawaited(handler.playTracks(tracks)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('播放'),
                ),
                AppButton.withIcon(
                  tonal: true,
                  onPressed: () =>
                      unawaited(handler.playTracks(List.of(tracks)..shuffle())),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('随机播放'),
                ),
                AppButton.withIcon(
                  tonal: true,
                  onPressed: () => unawaited(
                    openMusicSearch(context, ref, first, replay: true),
                  ),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('搜录播'),
                ),
              ],
            ),
          ],
        );
        final header = Padding(
          padding: EdgeInsets.fromLTRB(gutter, insets.top + 8, gutter, 16),
          child: wide
              ? Row(
                  children: [
                    cover,
                    const SizedBox(width: 24),
                    Expanded(child: details),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [cover, const SizedBox(height: 16), details],
                  ),
                ),
        );
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              // A wash of the first singer's colour behind the header, as an
              // album page takes its cover's.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (tone ?? theme.colorScheme.primary).withValues(
                        alpha: .22,
                      ),
                      (tone ?? theme.colorScheme.primary).withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppTokens.readingWidth,
                    ),
                    child: header,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                gutter - 8,
                0,
                gutter - 8,
                insets.bottom,
              ),
              sliver: SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppTokens.readingWidth,
                    ),
                    child: MusicTrackRow(
                      track: tracks[index],
                      number: index + 1,
                      showSingers: mixed,
                      selected: tracks[index].id == currentId,
                      onPlay: () =>
                          unawaited(handler.playTracks(tracks, start: index)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
