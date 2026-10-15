import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../handoff/domain/return_context.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';
import '../application/content_providers.dart';
import '../application/fanart_feed_controller.dart';
import '../domain/fanart_repository.dart';
import '../domain/saved_channel.dart';
import 'fanart_card.dart';
import 'fanart_detail_page.dart';
import 'fanart_filter_bar.dart';
import 'fanart_grid.dart';

/// Opens the random feed, drawing from what [query] narrows to.
void openRandomFanart(
  BuildContext context, {
  FanartQuery query = const FanartQuery(),
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => RandomFanartPage(query: query)),
  );
}

/// The way into the random feed, filled in the accent: it is the fanart
/// side's lead feature, not one more grey control. [compact] keeps only
/// the icon, for the narrowest rows.
class RandomFanartButton extends StatelessWidget {
  const RandomFanartButton({
    this.query = const FanartQuery(),
    this.label = '随机刷',
    this.compact = false,
    super.key,
  });
  final FanartQuery query;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = AppSegments.heightFor(context);
    final style = FilledButton.styleFrom(
      minimumSize: Size(height, height),
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.inputRadius),
      ),
    );
    void open() => openRandomFanart(context, query: query);
    if (compact) {
      return Tooltip(
        message: label,
        child: FilledButton(
          style: style.copyWith(
            fixedSize: WidgetStatePropertyAll(Size.square(height)),
          ),
          onPressed: open,
          child: const Icon(Icons.shuffle, size: 20),
        ),
      );
    }
    return FilledButton.icon(
      style: style,
      onPressed: open,
      icon: const Icon(Icons.shuffle, size: 18),
      label: Text(label, maxLines: 1),
    );
  }
}

/// Random works without end: scrolling down draws another batch, and a work
/// already shown here is not shown again. 换一批 and pulling down start over.
///
/// A draw has no order and no position to come back to, so the feed lives
/// only as long as the page; a trip out to Bilibili returns to it while the
/// app stays alive.
class RandomFanartPage extends ConsumerStatefulWidget {
  const RandomFanartPage({this.query = const FanartQuery(), super.key});
  final FanartQuery query;

  @override
  ConsumerState<RandomFanartPage> createState() => _RandomFanartPageState();
}

class _RandomFanartPageState extends ConsumerState<RandomFanartPage> {
  late final _controller = FanartFeedController(
    ref.read(fanartRepositoryProvider),
    // A draw ignores the order; leaving one set would only show it as an
    // applied condition.
    query: widget.query.copyWith(sort: FanartSort.newest),
    random: true,
  );
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _redraw() {
    _toTop();
    return _controller.refresh();
  }

  void _apply(FanartQuery query) {
    _controller.applyQuery(query);
    _toTop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final state = _controller.state;
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppPageBar(
          title: const Text('随机二创'),
          actions: [
            AppButton.icon(
              tooltip: '换一批',
              onPressed: state.isBusy ? null : _redraw,
              icon: const Icon(Icons.shuffle),
            ),
          ],
        ),
        body: Builder(
          // Inside the body, so MediaQuery carries the page bar height.
          builder: (context) => _feed(state),
        ),
      );
    },
  );

  Widget _feed(FanartFeedState state) {
    final filters = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FanartQuickFilters(query: state.query, onChanged: _apply),
        FanartFilterBar(query: state.query, onChanged: _apply),
      ],
    );
    return RuleFilterScope(
      items: state.items,
      subjectOf: RuleSubjects.fanart,
      unavailableBuilder: (status) => FeedScrollView(
        controller: _scroll,
        onRefresh: _redraw,
        header: [filters],
        placeholder: status,
      ),
      builder: (visible) => AutoFillViewport(
        controller: _scroll,
        resetKey: (_controller.generation, visible.epoch),
        canLoadMore: state.status == FeedStatus.ready,
        onLoadMore: () => _controller.loadMore(automatic: true),
        child: FanartGrid(
          hidden: visible.userHidden.length,
          state: state.copyWith(items: visible.items),
          header: [
            filters,
            if (state.status == FeedStatus.failed && visible.items.isNotEmpty)
              FeedStaleNotice(failure: state.failure, onRetry: _redraw),
            RuleStatusBar(visibility: visible),
          ],
          controller: _scroll,
          onRetryAppend: _controller.loadMore,
          onRefresh: _redraw,
          onClear: () => _apply(const FanartQuery()),
          // A cold return lands on the fanart channel with these filters:
          // the draw itself cannot be rebuilt.
          onOpen: (item) => openFanart(
            context,
            ref,
            item,
            returnTo: ReturnTarget.contentChannel,
            channel: ContentChannel.fanart.slug,
            query: ChannelSpec.ofFanart(state.query).values,
            heroTag: fanartHeroTag(item),
          ),
        ),
      ),
    );
  }
}
