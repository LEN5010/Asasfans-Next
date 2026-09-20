import 'package:flutter/material.dart';

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
    return AutoFillViewport(
      controller: _scroll,
      resetKey: (widget.pager, state.epoch),
      scrollResetKey: (widget.pager, state.epoch),
      canLoadMore: state.canLoadMore,
      onLoadMore: widget.pager.loadMore,
      child: RefreshIndicator(
        onRefresh: widget.pager.refresh,
        child: Scrollbar(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (widget.header != null)
                SliverToBoxAdapter(child: widget.header),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) => Column(
                    children: [
                      if (index > 0) const Divider(height: 1),
                      widget.itemBuilder(context, state.items[index]),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: state.loading
                        ? const CircularProgressIndicator()
                        : state.failure != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(libraryError(state.failure!)),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: widget.pager.retry,
                                child: const Text('重试'),
                              ),
                            ],
                          )
                        : state.items.isEmpty
                        ? Text(widget.empty)
                        : state.next == null
                        ? const Text('已显示全部')
                        : const SizedBox.shrink(),
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
