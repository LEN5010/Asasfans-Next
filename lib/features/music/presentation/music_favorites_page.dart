import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_common.dart';
import '../../library/presentation/library_paged_list.dart';
import '../application/music_providers.dart';
import 'music_widgets.dart';

/// Kept songs as a playlist: a header to play them all or shuffled, then
/// the songs, the latest kept first.
class MusicFavoritesPage extends ConsumerWidget {
  const MusicFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicFavoritesProvider);
    final count = ref.watch(musicFavoriteIdsProvider).valueOrNull?.length;
    final currentId = ref.watch(
      musicAudioHandlerProvider.select((h) => h.current?.id),
    );
    final theme = Theme.of(context);
    Future<void> playAll({required bool shuffle}) =>
        libraryAction(context, () async {
          final tracks = await ref
              .read(libraryRepositoryProvider)
              .musicFavorites();
          if (shuffle) tracks.shuffle();
          await ref.read(musicAudioHandlerProvider).playTracks(tracks);
        });
    final tracks = [for (final item in state.items) item.track];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('收藏的歌')),
      // Left-aligned at the music list's width, as the page it opens from.
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppTokens.readingWidth + 24,
          ),
          child: LibraryPagedList<MusicFavorite>(
            state: state,
            pager: ref.read(musicFavoritesProvider.notifier),
            empty: '还没有收藏的歌',
            emptyHint: '点歌曲旁的心形收藏',
            header: count == null || count == 0
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: AppCard(
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
                                Icons.favorite_rounded,
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
                                  '$count 首',
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
                                      onPressed: () =>
                                          unawaited(playAll(shuffle: false)),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text('播放全部'),
                                    ),
                                    AppButton.withIcon(
                                      tonal: true,
                                      onPressed: () =>
                                          unawaited(playAll(shuffle: true)),
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
                    ),
                  ),
            itemBuilder: (context, item) => MusicSongTile(
              track: item.track,
              card: false,
              selected: item.track.id == currentId,
              onPlay: () => unawaited(
                ref
                    .read(musicAudioHandlerProvider)
                    .playTracks(tracks, start: tracks.indexOf(item.track)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
