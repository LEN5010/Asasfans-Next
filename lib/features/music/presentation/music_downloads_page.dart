import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../application/music_providers.dart';
import 'music_widgets.dart';

/// Songs saved on this device, newest first, playable without a network.
class MusicDownloadsPage extends ConsumerWidget {
  const MusicDownloadsPage({super.key});

  static String _size(int bytes) => bytes >= 1 << 30
      ? '${(bytes / (1 << 30)).toStringAsFixed(1)} GB'
      : '${(bytes / (1 << 20)).toStringAsFixed(bytes >= 100 << 20 ? 0 : 1)} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(musicDownloadsProvider);
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    final theme = Theme.of(context);
    final items = downloads.items;
    final tracks = [for (final item in items) item.track];
    void play({int start = 0, bool? shuffle}) => unawaited(
      ref
          .read(musicAudioHandlerProvider)
          .playTracks(tracks, start: start, shuffle: shuffle),
    );
    final Widget body;
    if (!downloads.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (downloads.failed || items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            downloads.failed ? '无法读取本机已下载的歌' : '还没有下载的歌',
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: pageInsets(context, top: 8),
        itemCount: items.length + 1,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return AppCard(
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.dianaPink.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox.square(
                      dimension: 64,
                      child: Icon(
                        Icons.download_done_rounded,
                        size: 32,
                        color: AppTheme.dianaPink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${items.length} 首 · ${_size(downloads.bytes)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppButton.withIcon(
                              selected: true,
                              onPressed: () => play(shuffle: false),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('播放全部'),
                            ),
                            AppButton.withIcon(
                              tonal: true,
                              onPressed: () => play(shuffle: true),
                              icon: const Icon(Icons.shuffle_rounded),
                              label: const Text('随机播放'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final track = items[index - 1].track;
          return MusicSongTile(
            track: track,
            selected: track.id == currentId,
            onPlay: () => play(start: index - 1),
          );
        },
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('已下载')),
      body: Builder(builder: (context) => body),
    );
  }
}
