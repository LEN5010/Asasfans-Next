import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_tokens.dart';
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
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
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

class MusicMiniPlayer extends ConsumerStatefulWidget {
  const MusicMiniPlayer({super.key, this.compact = false});
  final bool compact;
  @override
  ConsumerState<MusicMiniPlayer> createState() => _MusicMiniPlayerState();
}

class _MusicMiniPlayerState extends ConsumerState<MusicMiniPlayer> {
  String? _lastMessage;
  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(musicAudioHandlerProvider);
    final track = handler.current;
    if (track == null) return const SizedBox.shrink();
    if (handler.message != null && handler.message != _lastMessage) {
      final message = handler.message!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(message)));
        }
      });
    }
    _lastMessage = handler.message;
    final duration = handler.duration.inMilliseconds;
    final progress = duration == 0
        ? 0.0
        : (handler.position.inMilliseconds / duration).clamp(0.0, 1.0);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          track.singers,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: handler.playing ? '暂停' : '播放',
          onPressed: () => handler.playing ? handler.pause() : handler.play(),
          icon: Icon(
            handler.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        IconButton(
          tooltip: '下一首',
          onPressed: handler.skipToNext,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 8 : 12,
        8,
        widget.compact ? 8 : 12,
        4,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/music/player'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: widget.compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          title,
                          Align(
                            alignment: Alignment.centerRight,
                            child: controls,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          controls,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MusicTrackRow extends ConsumerWidget {
  const MusicTrackRow({
    super.key,
    required this.track,
    required this.onPlay,
    this.selected = false,
  });
  final MusicTrack track;
  final VoidCallback onPlay;
  final bool selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    selected: selected,
    contentPadding: const EdgeInsets.only(left: 16, right: 4),
    leading: MemberDots(members: track.members, size: 8),
    title: Text(
      track.title,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Wrap(
      spacing: 10,
      children: [
        Text(
          musicDuration(track.duration),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
        if (track.isLive) const Text('Live'),
      ],
    ),
    onTap: onPlay,
    trailing: PopupMenuButton<String>(
      tooltip: '歌曲操作',
      onSelected: (value) {
        final handler = ref.read(musicAudioHandlerProvider);
        switch (value) {
          case 'next':
            unawaited(handler.enqueue(track, next: true));
          case 'queue':
            unawaited(handler.enqueue(track));
          case 'clip':
            unawaited(openMusicSearch(context, ref, track, replay: false));
          case 'replay':
            unawaited(openMusicSearch(context, ref, track, replay: true));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'next', child: Text('下一首播放')),
        PopupMenuItem(value: 'queue', child: Text('加入队列')),
        PopupMenuItem(value: 'clip', child: Text('搜切片')),
        PopupMenuItem(value: 'replay', child: Text('搜录播')),
      ],
    ),
  );
}

class MusicQueue extends StatelessWidget {
  const MusicQueue({super.key, required this.handler, this.scroll = true});
  final MusicAudioHandler handler;
  final bool scroll;
  @override
  Widget build(BuildContext context) => ListView.builder(
    shrinkWrap: !scroll,
    physics: scroll ? null : const NeverScrollableScrollPhysics(),
    itemCount: handler.tracks.length,
    itemBuilder: (context, index) {
      final track = handler.tracks[index];
      return ListTile(
        selected: index == handler.index,
        leading: MemberDots(members: track.members),
        title: Text(track.title),
        subtitle: Text('${track.singers} · ${track.dateLabel}'),
        onTap: () => handler.skipToQueueItem(index),
        trailing: IconButton(
          tooltip: '移出队列',
          onPressed: () => handler.removeTrack(index),
          icon: const Icon(Icons.close, size: 18),
        ),
      );
    },
  );
}

class MusicSurface extends StatelessWidget {
  const MusicSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      boxShadow: AppTokens.cardShadow(Theme.of(context).brightness),
    ),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}
