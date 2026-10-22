import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_controls.dart';
import '../application/music_audio_handler.dart';
import '../application/music_providers.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

/// The full player: a large cover over a wash of the first singer's colour,
/// the song, its progress and the controls; the queue beside it on a wide
/// window, in a sheet on a phone.
class MusicPlayerPage extends ConsumerWidget {
  const MusicPlayerPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    final theme = Theme.of(context);
    final tone =
        AppTheme.memberColors[track?.members.firstOrNull] ??
        theme.colorScheme.primary;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: AppButton.icon(
          tooltip: '收起播放页',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tone.withValues(alpha: .28),
              theme.scaffoldBackgroundColor,
            ],
            stops: const [0, .7],
          ),
        ),
        child: track == null
            ? const Center(child: Text('播放队列为空'))
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final gutter = constraints.maxWidth < 360 ? 16.0 : 24.0;
                    final player = LayoutBuilder(
                      builder: (context, bounds) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                            child: _PlayerContent(
                              handler: handler,
                              track: track,
                              wide: wide,
                              availableHeight: bounds.maxHeight - 32,
                            ),
                          ),
                        ),
                      ),
                    );
                    if (!wide) return player;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: player),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 24, 24),
                            child: AppCard(
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: _QueuePanel(handler: handler),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.handler});
  final MusicAudioHandler handler;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text(
          '播放队列 · ${handler.tracks.length}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      Expanded(child: MusicQueue(handler: handler)),
    ],
  );
}

class _PlayerContent extends ConsumerWidget {
  const _PlayerContent({
    required this.handler,
    required this.track,
    required this.wide,
    required this.availableHeight,
  });
  final MusicAudioHandler handler;
  final MusicTrack track;
  final bool wide;
  final double availableHeight;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Reserve room for the controls before giving space to the cover.
            // Large text can still scroll without reducing its scale.
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final controlsHeight = 400 + 120 * (textScale - 1);
            final size = math.min(
              math.min(constraints.maxWidth, 360.0),
              math.max(96.0, availableHeight - controlsHeight),
            );
            return Align(
              alignment: Alignment.center,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 32,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: MusicCover(
                  members: track.members,
                  size: size,
                  radius: 20,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            MusicFavoriteButton(track: track),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            track.singers,
            track.dateLabel,
            if (track.isLive) 'Live',
          ].join(' · '),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        MusicProgress(handler: handler),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MusicShuffleButton(handler: handler),
            MusicRepeatButton(handler: handler),
            AppButton.icon(
              tooltip: '上一首',
              onPressed: handler.skipToPrevious,
              icon: const Icon(Icons.skip_previous_rounded, size: 36),
            ),
            MusicPlayButton(handler: handler, size: 48),
            AppButton.icon(
              tooltip: '下一首',
              onPressed: handler.skipToNext,
              icon: const Icon(Icons.skip_next_rounded, size: 36),
            ),
            if (wide)
              const SizedBox(width: 48)
            else
              AppButton.icon(
                tooltip: '播放队列',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .72,
                    child: SafeArea(
                      child: Consumer(
                        builder: (context, ref, _) => _QueuePanel(
                          handler: ref.watch(musicAudioHandlerProvider),
                        ),
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.queue_music_rounded),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const MusicVolumeControl(),
        const SizedBox(height: 16),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: AppButton.withIcon(
                tonal: true,
                onPressed: () =>
                    openMusicSearch(context, ref, track, replay: false),
                icon: const Icon(Icons.search),
                label: const Text('搜切片'),
              ),
            ),
            Expanded(
              child: AppButton.withIcon(
                tonal: true,
                onPressed: () =>
                    openMusicSearch(context, ref, track, replay: true),
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('搜录播'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
