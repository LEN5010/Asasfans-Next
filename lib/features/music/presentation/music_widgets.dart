import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/member_tone.dart';
import '../../../shared/widgets/glass/app_glass_navigation.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/library_common.dart';
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

/// The studio the catalogue comes from; [compact] is its icon alone, for a
/// phone's title row.
class MusicStudioButton extends ConsumerWidget {
  const MusicStudioButton({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> open() async {
      final opened = await ref
          .read(externalLinkServiceProvider)
          .open(Uri.https('studio.asoul.us.kg'));
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法打开录音棚')));
      }
    }

    const icon = Icon(Icons.open_in_new, size: 18);
    return compact
        ? AppButton.icon(tooltip: '打开录音棚', onPressed: open, icon: icon)
        : AppButton.withIcon(
            onPressed: open,
            icon: icon,
            label: const Text('录音棚'),
          );
  }
}

/// A song's cover without pictures: its singers' colours run corner to
/// corner under a note, one singer's from her colour to a deeper shade.
class MusicCover extends StatelessWidget {
  const MusicCover({
    super.key,
    required this.members,
    required this.size,
    this.radius = 10,
  });
  final List<String> members;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tones = [
      for (final member in members)
        AppTheme.memberColors[member] ?? AppTheme.dianaPink,
    ];
    final colors = switch (tones) {
      [] => [AppTheme.dianaPink, AppTheme.deepRose],
      [final one] => [one, Color.lerp(one, Colors.black, .3)!],
      _ => tones,
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: size * .42,
            color: Colors.white.withValues(alpha: .9),
          ),
        ),
      ),
    );
  }
}

/// Where the song is, draggable. The thumb follows the finger and the song
/// seeks once, on release, rather than on every frame of the drag.
class MusicProgress extends StatefulWidget {
  const MusicProgress({super.key, required this.handler, this.dense = false});
  final MusicAudioHandler handler;

  /// The times beside the track rather than under it, for the desktop bar.
  final bool dense;

  @override
  State<MusicProgress> createState() => _MusicProgressState();
}

class _MusicProgressState extends State<MusicProgress> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handler = widget.handler;
    final total = handler.duration.inMilliseconds.toDouble();
    final value =
        _dragging ??
        handler.position.inMilliseconds.clamp(0, math.max(total, 0)).toDouble();
    final time = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: AppTheme.tabular,
    );
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        inactiveTrackColor: theme.colorScheme.surfaceContainerHigh,
      ),
      child: Slider(
        value: math.min(value, total > 0 ? total : 1),
        max: total > 0 ? total : 1,
        onChanged: total > 0
            ? (value) => setState(() => _dragging = value)
            : null,
        onChangeEnd: total > 0
            ? (value) {
                setState(() => _dragging = null);
                unawaited(handler.seek(Duration(milliseconds: value.round())));
              }
            : null,
      ),
    );
    final position = Text(
      musicDuration(Duration(milliseconds: value.round())),
      style: time,
    );
    final length = Text(musicDuration(handler.duration), style: time);
    if (widget.dense) {
      return Row(
        children: [
          position,
          Expanded(child: slider),
          length,
        ],
      );
    }
    return Column(
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [position, length],
          ),
        ),
      ],
    );
  }
}

/// The round play button music apps lead their controls with.
class MusicPlayButton extends StatelessWidget {
  const MusicPlayButton({super.key, required this.handler, this.size = 40});
  final MusicAudioHandler handler;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(size),
          shape: const CircleBorder(),
          backgroundColor: colors.onSurface,
          foregroundColor: colors.surface,
          disabledBackgroundColor: colors.onSurface.withValues(alpha: .6),
        ),
        onPressed: handler.loading
            ? null
            : () => handler.playing ? handler.pause() : handler.play(),
        child: handler.loading
            ? SizedBox.square(
                dimension: size * .4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.surface,
                ),
              )
            : Icon(
                handler.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: size * .58,
                semanticLabel: handler.playing ? '暂停' : '播放',
              ),
      ),
    );
  }
}

class MusicRepeatButton extends StatelessWidget {
  const MusicRepeatButton({super.key, required this.handler});
  final MusicAudioHandler handler;
  @override
  Widget build(BuildContext context) => AppButton.icon(
    tooltip: switch (handler.repeat) {
      AudioServiceRepeatMode.none => '顺序播放',
      AudioServiceRepeatMode.one => '单曲循环',
      _ => '列表循环',
    },
    selected: handler.repeat != AudioServiceRepeatMode.none,
    onPressed: () => handler.setRepeatMode(switch (handler.repeat) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    }),
    icon: Icon(
      handler.repeat == AudioServiceRepeatMode.one
          ? Icons.repeat_one_rounded
          : Icons.repeat_rounded,
    ),
  );
}

/// The playing song's cover, title and who sang, as the players lead.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.track, required this.cover});
  final MusicTrack track;
  final double cover;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        MusicCover(members: track.members, size: cover, radius: 8),
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The song that is playing, above the dock on a phone. A tap opens the
/// player.
class MusicMiniPlayer extends ConsumerWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    if (track == null) return const SizedBox.shrink();
    final duration = handler.duration.inMilliseconds;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => unawaited(context.push('/music/player')),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
              child: Row(
                children: [
                  Expanded(child: _NowPlaying(track: track, cover: 44)),
                  const SizedBox(width: 8),
                  MusicPlayButton(handler: handler, size: 38),
                  AppButton.icon(
                    tooltip: '下一首',
                    onPressed: handler.skipToNext,
                    icon: const Icon(Icons.skip_next_rounded, size: 26),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: duration == 0
                      ? 0
                      : (handler.position.inMilliseconds / duration).clamp(
                          0.0,
                          1.0,
                        ),
                  minHeight: 2,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wide window's player along its foot, as on desktop music apps: the
/// song on the left, the controls and progress in the middle, the player
/// page on the right. [bare] leaves out the card, for the shell to draw one
/// round it while the bar folds into the rail.
class MusicPlayerBar extends ConsumerWidget {
  const MusicPlayerBar({super.key, this.bare = false});
  final bool bare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    if (track == null) return const SizedBox.shrink();
    void open() => unawaited(context.push('/music/player'));
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(300.0, constraints.maxWidth * .28);
        return Row(
          children: [
            SizedBox(
              width: side,
              child: Tooltip(
                message: '打开播放页',
                child: InkWell(
                  onTap: open,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _NowPlaying(track: track, cover: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      AppButton.icon(
                        tooltip: '上一首',
                        onPressed: handler.skipToPrevious,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      MusicPlayButton(handler: handler, size: 36),
                      AppButton.icon(
                        tooltip: '下一首',
                        onPressed: handler.skipToNext,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: MusicProgress(handler: handler, dense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: side,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MusicFavoriteButton(track: track),
                  MusicRepeatButton(handler: handler),
                  AppButton.icon(
                    tooltip: '播放队列',
                    onPressed: open,
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    const padding = EdgeInsets.all(8);
    return bare
        ? Padding(padding: padding, child: content)
        : AppCard(padding: padding, child: content);
  }
}

/// The player folded into the rail's free space on every page but 音乐:
/// the cover opens the player, and the song pauses without leaving.
class MusicDockPlayer extends ConsumerWidget {
  const MusicDockPlayer({super.key, this.bare = false});
  final bool bare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    if (track == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final duration = handler.duration.inMilliseconds;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '${track.title} · ${track.singers}',
            child: InkWell(
              onTap: () => unawaited(context.push('/music/player')),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    MusicCover(members: track.members, size: 48, radius: 10),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: duration == 0
                              ? 0
                              : (handler.position.inMilliseconds / duration)
                                    .clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          MusicPlayButton(handler: handler, size: 36),
        ],
      ),
    );
    return SizedBox(
      width: AppSidebar.width,
      child: bare ? content : AppCard(padding: EdgeInsets.zero, child: content),
    );
  }
}

/// The heart beside a song: kept songs are listed under 收藏的歌.
class MusicFavoriteButton extends ConsumerWidget {
  const MusicFavoriteButton({super.key, required this.track});
  final MusicTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(musicFavoriteIdsProvider);
    final kept = ids.valueOrNull?.contains(track.id) ?? false;
    return AppButton.icon(
      tooltip: kept ? '取消收藏' : '收藏',
      onPressed: ids.hasValue
          ? () => unawaited(
              libraryAction(
                context,
                () => ref
                    .read(libraryRepositoryProvider)
                    .setMusicFavorite(track, !kept),
              ),
            )
          : null,
      icon: Icon(
        kept ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: kept ? AppTheme.dianaPink : null,
      ),
    );
  }
}

/// A song as a long card: a bar in its singers' colours, the title, who
/// sang it, when and how long, the heart and a round play button. A tap
/// anywhere plays from it; a long press or a right click opens its menu,
/// which a wide card also shows a button for. Inside a list that is itself
/// a card, [card] is false.
class MusicSongTile extends ConsumerWidget {
  const MusicSongTile({
    super.key,
    required this.track,
    required this.onPlay,
    this.selected = false,
    this.card = true,
  });
  final MusicTrack track;
  final VoidCallback onPlay;
  final bool selected;
  final bool card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // [tile] is the card itself, which the menu is placed against.
    Widget content(BuildContext tile, MenuController menu) => LayoutBuilder(
      builder: (context, constraints) {
        void openMenu(Offset? at) =>
            menu.isOpen ? menu.close() : menu.open(position: at);
        // A phone leaves out the length and the menu button, and the
        // singers give way before the date does.
        final roomy = constraints.maxWidth >= 480;
        final when = [
          track.dateLabel,
          if (roomy) musicDuration(track.duration),
          if (track.isLive) 'Live',
        ].join(' · ');
        final detailStyle = theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontFeatures: AppTheme.tabular,
        );
        return InkWell(
          onTap: onPlay,
          onLongPress: () => openMenu(null),
          onSecondaryTapUp: (details) => openMenu(details.localPosition),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                MemberBar(
                  members: track.members,
                  fallback: AppTheme.dianaPink,
                  length: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (selected) ...[
                            Icon(
                              Icons.graphic_eq,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected ? colors.primary : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      LayoutBuilder(
                        builder: (context, line) => Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.singers,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // As wide as what is shown, with no gap
                                // before the date once it is cut.
                                textWidthBasis: TextWidthBasis.longestLine,
                                style: detailStyle,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: line.maxWidth * .75,
                              ),
                              child: Text(
                                ' · $when',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: detailStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                MusicFavoriteButton(track: track),
                if (roomy)
                  Builder(
                    builder: (button) => AppButton.icon(
                      tooltip: '歌曲操作',
                      onPressed: () {
                        final box = button.findRenderObject()! as RenderBox;
                        openMenu(
                          box.localToGlobal(
                            box.size.bottomLeft(Offset.zero),
                            ancestor: tile.findRenderObject(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ),
                const SizedBox(width: 4),
                _SongPlayButton(selected: selected, onPlay: onPlay),
              ],
            ),
          ),
        );
      },
    );
    return _SongMenu(
      track: track,
      builder: (context, menu) => !card
          ? content(context, menu)
          : AppCard(
              padding: EdgeInsets.zero,
              color: selected
                  ? Color.alphaBlend(
                      colors.primaryContainer.withValues(alpha: .35),
                      colors.surfaceContainerLow,
                    )
                  : null,
              child: content(context, menu),
            ),
    );
  }
}

/// The round button at a song's end: it plays the song, or, for the song
/// that is on, pauses and resumes it.
class _SongPlayButton extends ConsumerWidget {
  const _SongPlayButton({required this.selected, required this.onPlay});
  final bool selected;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selected) {
      // Rebuilt for play and pause only, not every tick of the position.
      ref.watch(
        musicAudioHandlerProvider.select((h) => (h.playing, h.loading)),
      );
      return MusicPlayButton(
        handler: ref.read(musicAudioHandlerProvider),
        size: 42,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 42,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(42),
          shape: const CircleBorder(),
          backgroundColor: colors.onSurface,
          foregroundColor: colors.surface,
        ),
        onPressed: onPlay,
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 24,
          semanticLabel: '播放',
        ),
      ),
    );
  }
}

/// A song's menu, anchored to its whole card.
class _SongMenu extends ConsumerWidget {
  const _SongMenu({required this.track, required this.builder});
  final MusicTrack track;
  final Widget Function(BuildContext tile, MenuController menu) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MenuAnchor(
    menuChildren: [
      MenuItemButton(
        leadingIcon: const Icon(Icons.open_in_new),
        onPressed: () =>
            unawaited(openMusicSearch(context, ref, track, replay: false)),
        child: const Text('去 B 站搜这首'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.playlist_play),
        onPressed: () => unawaited(
          ref.read(musicAudioHandlerProvider).enqueue(track, next: true),
        ),
        child: const Text('下一首播放'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.playlist_add),
        onPressed: () =>
            unawaited(ref.read(musicAudioHandlerProvider).enqueue(track)),
        child: const Text('加入队列'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.today_outlined),
        // The day as the catalogue lists it, starting from this song.
        onPressed: () {
          final day = [
            for (final song
                in ref.read(musicCatalogProvider).valueOrNull?.tracks ??
                    <MusicTrack>[track])
              if (song.date == track.date) song,
          ];
          unawaited(
            ref
                .read(musicAudioHandlerProvider)
                .playTracks(day, start: math.max(0, day.indexOf(track))),
          );
        },
        child: const Text('播放这天'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.video_library_outlined),
        onPressed: () =>
            unawaited(openMusicSearch(context, ref, track, replay: true)),
        child: const Text('搜这天的录播'),
      ),
    ],
    // A context below the anchor, whose render object is the card.
    builder: (context, menu, _) =>
        Builder(builder: (tile) => builder(tile, menu)),
  );
}

class MusicQueue extends StatelessWidget {
  const MusicQueue({super.key, required this.handler});
  final MusicAudioHandler handler;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: handler.tracks.length,
      itemBuilder: (context, index) {
        final selected = index == handler.index;
        return Material(
          color: selected
              ? colors.primaryContainer.withValues(alpha: .45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => handler.skipToQueueItem(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _NowPlaying(track: handler.tracks[index], cover: 40),
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
