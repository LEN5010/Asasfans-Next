import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/feature_pending.dart';
import '../application/content_providers.dart';
import '../application/fanart_feed_controller.dart';
import '../domain/fanart_repository.dart';
import 'dynamic_feed_view.dart';
import 'fanart_card.dart';
import 'fanart_detail_page.dart';
import 'fanart_filter_bar.dart';

class ContentPage extends ConsumerWidget {
  const ContentPage({this.channel = 'fanart', super.key});
  final String channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ContentChannel.fromSlug(channel) ?? ContentChannel.fanart;
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容'),
        actions: [if (current.isBackedByFanartApi) const _RandomFanartAction()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in ContentChannel.values)
                  ChoiceChip(
                    label: Text(value.label),
                    selected: current == value,
                    onSelected: (_) => context.go('/content/${value.slug}'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (current) {
              _ when current.isBackedByFanartApi => _FanartFeed(
                channel: current,
              ),
              _ when current.isBackedByDynamicsApi => const DynamicFeedView(),
              // Live clips come from a separate source that is not wired yet.
              _ => const FeaturePending(
                icon: Icons.auto_awesome_mosaic_outlined,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Draws one random post and opens it directly.
///
/// Each draw is an independent request, so the button disables itself while
/// one is in flight instead of letting repeated taps stack up requests.
class _RandomFanartAction extends ConsumerStatefulWidget {
  const _RandomFanartAction();

  @override
  ConsumerState<_RandomFanartAction> createState() =>
      _RandomFanartActionState();
}

class _RandomFanartActionState extends ConsumerState<_RandomFanartAction> {
  bool _loading = false;

  Future<void> _draw() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final item = await ref.read(fanartRepositoryProvider).random();
      if (!mounted) return;
      if (item == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可用的二创')));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FanartDetailPage(item: item)),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '随机二创',
    onPressed: _loading ? null : _draw,
    icon: _loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.shuffle),
  );
}

/// Infinite fanart grid. Scroll position is owned by this widget so returning
/// to the channel restores where the user was, and the controller keeps its
/// already-loaded pages.
class _FanartFeed extends ConsumerStatefulWidget {
  const _FanartFeed({required this.channel});
  final ContentChannel channel;

  @override
  ConsumerState<_FanartFeed> createState() => _FanartFeedState();
}

class _FanartFeedState extends ConsumerState<_FanartFeed> {
  final _scrollController = ScrollController();
  late FanartFeedController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(fanartFeedControllerProvider(widget.channel));
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadInitial();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Request the next page before the user reaches the very bottom.
    if (position.pixels >= position.maxScrollExtent - 600) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Applying a filter starts a new query generation, so the view returns to
  /// the top rather than keeping an offset that belonged to the old result.
  void _applyQuery(FanartQuery query) {
    _controller.applyQuery(query);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Column(
          children: [
            _SearchField(
              key: ValueKey(state.query.keyword),
              initial: state.query.keyword,
              onSubmitted: (keyword) =>
                  _applyQuery(state.query.copyWith(keyword: keyword)),
            ),
            const SizedBox(height: 8),
            FanartFilterBar(query: state.query, onChanged: _applyQuery),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(state)),
          ],
        );
      },
    );
  }

  Widget _buildBody(FanartFeedState state) {
    if (state.items.isEmpty) {
      return switch (state.status) {
        FeedStatus.failed => _FeedError(
          failure: state.failure,
          onRetry: _controller.refresh,
        ),
        FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => const _FeedEmpty(),
      };
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: _FanartGrid(
        state: state,
        controller: _scrollController,
        onRetryAppend: _controller.loadMore,
      ),
    );
  }
}

/// Submitting starts a new query; typing alone does not, so a partly typed
/// keyword never spends requests against the shared rate limit.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.initial,
    required this.onSubmitted,
    super.key,
  });

  final String initial;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      // The server caps the keyword, so the field does too.
      maxLength: 200,
      decoration: InputDecoration(
        hintText: '搜索二创正文或作者',
        counterText: '',
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: '清除搜索',
                onPressed: () {
                  _controller.clear();
                  widget.onSubmitted('');
                },
              ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: widget.onSubmitted,
    ),
  );
}

class _FanartGrid extends StatelessWidget {
  const _FanartGrid({
    required this.state,
    required this.controller,
    required this.onRetryAppend,
  });

  final FanartFeedState state;
  final ScrollController controller;
  final VoidCallback onRetryAppend;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide windows get more columns rather than a stretched phone layout.
        final columns = switch (constraints.maxWidth) {
          >= 1400 => 5,
          >= 1100 => 4,
          >= 760 => 3,
          _ => 2,
        };
        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Taller cells at larger text scales, so the caption keeps
                  // its room instead of overflowing the card.
                  childAspectRatio:
                      0.78 /
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                ),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return FanartCard(
                    item: item,
                    // Pushed on the local navigator so returning restores the
                    // scroll offset and the already-loaded pages.
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FanartDetailPage(item: item),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _FeedFooter(state: state, onRetry: onRetryAppend),
            ),
          ],
        );
      },
    );
  }
}

/// Communicates append progress, a recoverable append failure, or the real end
/// of the list. A failed append never discards the items already shown.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state, required this.onRetry});

  final FanartFeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final child = switch (state.status) {
      FeedStatus.appending => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      FeedStatus.appendFailed => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              state.failure?.message ?? '加载失败',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
      FeedStatus.endOfList => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            '没有更多了',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
      _ => const SizedBox(height: 20),
    };
    return SafeArea(top: false, child: child);
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('没有符合条件的内容'),
        ],
      ),
    ),
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.failure, required this.onRetry});

  final ApiFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(failure?.message ?? '内容加载失败'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
