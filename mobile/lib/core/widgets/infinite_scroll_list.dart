import 'package:flutter/material.dart';

class InfiniteScrollList<T> extends StatefulWidget {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? separatorBuilder;
  final Widget? loadingIndicator;
  final Widget? emptyState;
  final EdgeInsets padding;

  const InfiniteScrollList({
    Key? key,
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    this.separatorBuilder,
    this.loadingIndicator,
    this.emptyState,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  _InfiniteScrollListState<T> createState() => _InfiniteScrollListState<T>();
}

class _InfiniteScrollListState<T> extends State<InfiniteScrollList<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom && !widget.isLoading && widget.hasMore) {
      widget.onLoadMore();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && !widget.isLoading) {
      return widget.emptyState ??
          RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(child: Text('Aucune donnée disponible')),
              ],
            ),
          );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            widget.separatorBuilder ?? const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == widget.items.length) {
            return widget.loadingIndicator ??
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
          }
          return widget.itemBuilder(context, widget.items[index]);
        },
      ),
    );
  }
}
