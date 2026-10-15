import 'package:flutter/material.dart';

import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/sliver_content_masonry.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../rules/application/feed_visibility.dart';
import '../application/fanart_feed_controller.dart';
import '../domain/fanart_repository.dart';
import 'fanart_card.dart';
import 'feed_status_footer.dart';

/// An endless grid of works with its loading, empty and failed states: the
/// fanart channel's, and the random feed's.
class FanartGrid extends StatelessWidget {
  const FanartGrid({
    required this.state,
    required this.header,
    required this.controller,
    required this.onOpen,
    required this.onRetryAppend,
    required this.onRefresh,
    required this.onClear,
    this.hidden = 0,
    this.onBuilt,
    this.storageKey,
    super.key,
  });

  final ValueChanged<List<FanartItem>>? onBuilt;
  final ValueChanged<FanartItem> onOpen;

  /// Back to the defaults, from the empty state.
  final VoidCallback onClear;

  /// Loaded items the user's rules hide.
  final int hidden;
  final FanartFeedState state;
  final List<Widget> header;
  final ScrollController controller;
  final VoidCallback onRetryAppend;
  final Future<void> Function() onRefresh;
  final Key? storageKey;

  @override
  Widget build(BuildContext context) {
    onBuilt?.call(state.items);
    final placeholder = state.items.isNotEmpty
        ? null
        : switch (state.status) {
            FeedStatus.failed => FeedMessage(
              icon: Icons.cloud_off_outlined,
              text: state.failure?.message ?? '内容加载失败',
              failure: state.failure,
              onRetry: onRefresh,
            ),
            FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
              child: CircularProgressIndicator(),
            ),
            FeedStatus.endOfList || FeedStatus.stalled when hidden > 0 =>
              FeedAllHiddenMessage(count: hidden),
            FeedStatus.endOfList => FeedMessage.empty(
              noun: '二创',
              filtered: state.query != const FanartQuery(),
              // Unlike the summary's 清除条件, this also clears the members:
              // the label says so.
              clearLabel: '清除全部条件',
              onClear: onClear,
              onRefresh: onRefresh,
            ),
            _ => null,
          };
    return FeedScrollView(
      storageKey: storageKey,
      controller: controller,
      onRefresh: onRefresh,
      header: header,
      placeholder: placeholder,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          // Each work as tall as its own content: a video's words follow its
          // cover, a text work ends with its excerpt. Built lazily, measured
          // as they come.
          sliver: SliverContentMasonry(
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return FanartCard(
                key: ValueKey(item.identity),
                item: item,
                heroTag: fanartHeroTag(item),
                onLongPress: () => showContentActions(
                  context,
                  ContentSnapshots.fanart(item),
                  ruleSubject: RuleSubjects.fanart(item),
                ),
                onTap: () => onOpen(item),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: FeedStatusFooter(
            status: state.status,
            failure: state.failure,
            onRetry: onRetryAppend,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }
}
