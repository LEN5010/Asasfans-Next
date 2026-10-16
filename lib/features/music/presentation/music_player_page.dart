import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/member_tone.dart';
import '../application/music_audio_handler.dart';
import '../application/music_providers.dart';
import '../domain/music_track.dart';
import 'music_widgets.dart';

class MusicPlayerPage extends ConsumerWidget {
  const MusicPlayerPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '收起播放页',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        actions: const [MusicStudioButton(), SizedBox(width: 12)],
      ),
      body: track == null
          ? const Center(child: Text('播放队列为空'))
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final player = Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                        child: _PlayerContent(
                          handler: handler,
                          track: track,
                          wide: wide,
                        ),
                      ),
                    ),
                  );
                  if (!wide) return player;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: player),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '播放队列 · ${handler.tracks.length}',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(child: MusicQueue(handler: handler)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _PlayerContent extends ConsumerWidget {
  const _PlayerContent({
    required this.handler,
    required this.track,
    required this.wide,
  });
  final MusicAudioHandler handler;
  final MusicTrack track;
  final bool wide;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = track.members
        .map((m) => MemberTone.of(m, theme.brightness).color)
        .toList();
    if (colors.length == 1) {
      colors.add(Color.lerp(colors.first, Colors.black, .35)!);
    }
    final total = handler.duration.inMilliseconds;
    final value = handler.position.inMilliseconds.clamp(0, total).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxWidth / 1.15),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors
                      .map(
                        (c) => Color.lerp(
                          c,
                          const Color(0xFF17121A),
                          track.members.length > 1 ? .4 : .15,
                        )!,
                      )
                      .toList(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                    const SizedBox(height: 64),
                    Text(
                      track.singers,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.dateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          track.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${track.singers} · ${track.dateLabel} · ${track.isLive ? 'Live' : '完整'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Slider(
          value: value,
          min: 0,
          max: total > 0 ? total.toDouble() : 1,
          onChanged: total > 0
              ? (value) => handler.seek(Duration(milliseconds: value.round()))
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              musicDuration(handler.position),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              musicDuration(handler.duration),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton(
              tooltip: switch (handler.repeat) {
                AudioServiceRepeatMode.none => '顺序播放',
                AudioServiceRepeatMode.one => '单曲循环',
                _ => '列表循环',
              },
              onPressed: () => handler.setRepeatMode(switch (handler.repeat) {
                AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
                AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
                _ => AudioServiceRepeatMode.none,
              }),
              icon: Icon(
                handler.repeat == AudioServiceRepeatMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: handler.repeat == AudioServiceRepeatMode.none
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
            ),
            IconButton(
              tooltip: '上一首',
              iconSize: 32,
              onPressed: handler.skipToPrevious,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            SizedBox.square(
              dimension: 64,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                onPressed: handler.loading
                    ? null
                    : () => handler.playing ? handler.pause() : handler.play(),
                child: handler.loading
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        handler.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 36,
                      ),
              ),
            ),
            IconButton(
              tooltip: '下一首',
              iconSize: 32,
              onPressed: handler.skipToNext,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: '播放队列',
              onPressed: wide
                  ? null
                  : () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (context) => SizedBox(
                        height: MediaQuery.sizeOf(context).height * .72,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final live = ref.watch(musicAudioHandlerProvider);
                            return SafeArea(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      16,
                                    ),
                                    child: Text(
                                      '播放队列 · ${live.tracks.length}',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: MusicQueue(handler: live)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
              icon: const Icon(Icons.queue_music_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  openMusicSearch(context, ref, track, replay: false),
              icon: const Icon(Icons.search),
              label: const Text('搜切片'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  openMusicSearch(context, ref, track, replay: true),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('搜录播'),
            ),
          ],
        ),
      ],
    );
  }
}
