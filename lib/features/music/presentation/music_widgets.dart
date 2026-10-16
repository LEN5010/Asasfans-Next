import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/theme/app_icons.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/glass/app_glass_navigation.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/music_audio_handler.dart';
import '../application/music_providers.dart';
import '../domain/music_track.dart';

Future<void> openMusicSearch(
  BuildContext context,
  WidgetRef ref,
  MusicTrack track, {
  required bool replay,
}) async {
  final link = musicSearchLink(
    track,
    replay: replay,
    mobile: Platform.isAndroid || Platform.isIOS,
  );
  final opened = await ref.read(externalLinkServiceProvider).open(link);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('暂时无法打开 B 站搜索')));
  }
}

class MusicStudioButton extends ConsumerWidget {
  const MusicStudioButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppButton.withIcon(
    onPressed: () async {
      final opened = await ref
          .read(externalLinkServiceProvider)
          .open(Uri.https('studio.asoul.us.kg'));
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法打开录音棚')));
      }
    },
    icon: const Icon(Icons.open_in_new, size: 18),
    label: const Text('录音棚'),
  );
}

/// A song's stand-in cover: its singers' colours as a gradient, with the
/// play state on top when [icon] is given.
class MusicArtwork extends StatelessWidget {
  const MusicArtwork({
    super.key,
    required this.members,
    required this.size,
    this.radius = 12,
    this.icon,
  });
  final List<String> members;
  final double size;
  final double radius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = [
      for (final member in members)
        AppTheme.memberColors[member] ?? AppTheme.dianaPink,
    ];
    if (colors.length == 1) {
      colors.add(Color.lerp(colors.first, Colors.black, .3)!);
    }
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              for (final color in colors)
                Color.lerp(color, const Color(0xFF17121A), .18)!,
            ],
          ),
        ),
        child: icon == null
            ? null
            : Icon(icon, color: Colors.white, size: size * .5),
      ),
    );
  }
}

/// The song that is playing, under the pages: above the dock on a phone, at
/// the foot of the rail on a wide window ([rail]), where it keeps the rail's
/// width so starting a song never moves the page. A tap opens the player.
class MusicMiniPlayer extends ConsumerWidget {
  const MusicMiniPlayer({super.key, this.rail = false});
  final bool rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    if (track == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = handler.duration.inMilliseconds;
    final progress = duration == 0
        ? 0.0
        : (handler.position.inMilliseconds / duration).clamp(0.0, 1.0);
    final playPause = AppButton.icon(
      tooltip: handler.playing ? '暂停' : '播放',
      onPressed: () => handler.playing ? handler.pause() : handler.play(),
      icon: Icon(
        handler.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 26,
      ),
    );
    void open() => unawaited(context.push('/music/player'));
    final bar = LinearProgressIndicator(
      value: progress,
      minHeight: 2,
      backgroundColor: colors.outlineVariant.withValues(alpha: .5),
    );
    final Widget body;
    if (rail) {
      body = SizedBox(
        width: AppSidebar.width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: '${track.title} · ${track.singers}',
                child: InkWell(
                  onTap: open,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        MusicArtwork(members: track.members, size: 44),
                        const SizedBox(height: 6),
                        SizedBox(width: 44, child: bar),
                        const SizedBox(height: 6),
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              playPause,
            ],
          ),
        ),
      );
    } else {
      body = InkWell(
        onTap: open,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  MusicArtwork(members: track.members, size: 40, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${track.singers} · ${track.dateLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  playPause,
                  AppButton.icon(
                    tooltip: '下一首',
                    onPressed: handler.skipToNext,
                    icon: const Icon(Icons.skip_next_rounded, size: 26),
                  ),
                ],
              ),
            ),
            bar,
          ],
        ),
      );
    }
    return AppCard(padding: EdgeInsets.zero, child: body);
  }
}

/// One day's 歌回 as a card: the date and who sang, a way to play the day,
/// then its songs.
class MusicSessionCard extends StatelessWidget {
  const MusicSessionCard({
    super.key,
    required this.session,
    required this.currentId,
    required this.onPlayDay,
    required this.onPlayTrack,
  });
  final MusicSession session;
  final String? currentId;
  final VoidCallback onPlayDay;

  /// Plays from the day's song at that index.
  final ValueChanged<int> onPlayTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = session.members;
    final mixed = session.tracks.any(
      (track) => track.singers != session.tracks.first.singers,
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.tracks.first.dateLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          MemberDots(members: members),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${members.join('、')} · ${session.tracks.length} 首',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppButton.withIcon(
                  onPressed: onPlayDay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('播放这天'),
                ),
              ],
            ),
          ),
          for (final (index, track) in session.tracks.indexed) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            MusicTrackRow(
              track: track,
              number: index + 1,
              showSingers: mixed,
              selected: track.id == currentId,
              onPlay: () => onPlayTrack(index),
            ),
          ],
        ],
      ),
    );
  }
}

class MusicTrackRow extends ConsumerWidget {
  const MusicTrackRow({
    super.key,
    required this.track,
    required this.number,
    required this.onPlay,
    this.showSingers = false,
    this.selected = false,
  });
  final MusicTrack track;
  final int number;
  final VoidCallback onPlay;
  final bool showSingers;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontFeatures: AppTheme.tabular,
    );
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: .45)
          : Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: selected
                    ? Icon(Icons.graphic_eq, size: 18, color: colors.primary)
                    : Text('$number', style: muted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: selected ? colors.primary : null,
                      ),
                    ),
                    if (showSingers)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            MemberDots(members: track.members, size: 6),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                track.singers,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (track.isLive) ...[
                const SizedBox(width: 8),
                Text('Live', style: muted),
              ],
              const SizedBox(width: 8),
              Text(musicDuration(track.duration), style: muted),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.playlist_play),
                    onPressed: () => unawaited(
                      ref
                          .read(musicAudioHandlerProvider)
                          .enqueue(track, next: true),
                    ),
                    child: const Text('下一首播放'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.playlist_add),
                    onPressed: () => unawaited(
                      ref.read(musicAudioHandlerProvider).enqueue(track),
                    ),
                    child: const Text('加入队列'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(AppIcons.search),
                    onPressed: () => unawaited(
                      openMusicSearch(context, ref, track, replay: false),
                    ),
                    child: const Text('搜切片'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.video_library_outlined),
                    onPressed: () => unawaited(
                      openMusicSearch(context, ref, track, replay: true),
                    ),
                    child: const Text('搜录播'),
                  ),
                ],
                builder: (context, menu, _) => AppButton.icon(
                  tooltip: '歌曲操作',
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MusicQueue extends StatelessWidget {
  const MusicQueue({super.key, required this.handler});
  final MusicAudioHandler handler;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: handler.tracks.length,
      itemBuilder: (context, index) {
        final track = handler.tracks[index];
        final selected = index == handler.index;
        return Material(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: .45)
              : Colors.transparent,
          child: InkWell(
            onTap: () => handler.skipToQueueItem(index),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  MusicArtwork(members: track.members, size: 36, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${track.singers} · ${track.dateLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppButton.icon(
                    tooltip: '移出队列',
                    onPressed: () => handler.removeTrack(index),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
