import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../application/library_pager.dart';
import 'library_common.dart';

class LibraryPagedList<T> extends StatefulWidget {
  const LibraryPagedList({
    required this.state,
    required this.pager,
    required this.empty,
    required this.itemBuilder,
    this.header,
    super.key,
  });
  final LibraryListState<T> state;
  final LibraryPager<T> pager;
  final String empty;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? header;
  @override
  State<LibraryPagedList<T>> createState() => _LibraryPagedListState<T>();
}

class _LibraryPagedListState<T> extends State<LibraryPagedList<T>> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final padding = MediaQuery.paddingOf(context);
    return AutoFillViewport(
      controller: _scroll,
      resetKey: (widget.pager, state.epoch),
      scrollResetKey: (widget.pager, state.epoch),
      canLoadMore: state.canLoadMore,
      onLoadMore: widget.pager.loadMore,
      child: RefreshIndicator(
        onRefresh: widget.pager.refresh,
        edgeOffset: padding.top,
        child: Scrollbar(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: padding.top + 4)),
              if (widget.header != null)
                SliverToBoxAdapter(child: widget.header),
              if (state.items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                    ),
                    sliver: SliverList.builder(
                      itemCount: state.items.length,
                      itemBuilder: (context, index) => Column(
                        children: [
                          if (index > 0) const Divider(indent: 16),
                          widget.itemBuilder(context, state.items[index]),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + padding.bottom),
                  child: Center(
                    child: state.loading
                        ? const CircularProgressIndicator()
                        : state.failure != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(libraryError(state.failure!)),
                              const SizedBox(height: 8),
                              AppGlassButton(
                                onPressed: widget.pager.retry,
                                child: const Text('重试'),
                              ),
                            ],
                          )
                        : Text(
                            state.items.isEmpty
                                ? widget.empty
                                : state.next == null
                                ? '已显示全部'
                                : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
