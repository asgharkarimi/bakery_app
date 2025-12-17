import 'package:flutter/material.dart';

/// ویجت لیست با infinite scroll
class InfiniteListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) onLoadMore;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int initialPage;
  final double loadMoreThreshold;
  final Widget? separatorBuilder;
  final Widget? headerWidget;

  const InfiniteListView({
    super.key,
    required this.onLoadMore,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.errorWidget,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.initialPage = 1,
    this.loadMoreThreshold = 200,
    this.separatorBuilder,
    this.headerWidget,
  });

  @override
  State<InfiniteListView<T>> createState() => InfiniteListViewState<T>();
}

class InfiniteListViewState<T> extends State<InfiniteListView<T>> {
  final ScrollController _scrollController = ScrollController();
  final List<T> _items = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - widget.loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final newItems = await widget.onLoadMore(_currentPage);
      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _currentPage++;
          _hasMore = newItems.isNotEmpty;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  /// رفرش کردن لیست از اول
  Future<void> refresh() async {
    setState(() {
      _items.clear();
      _currentPage = widget.initialPage;
      _hasMore = true;
      _hasError = false;
      _isInitialLoad = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    // لودینگ اولیه
    if (_isInitialLoad && _isLoading) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    // خطا در لود اولیه
    if (_isInitialLoad && _hasError) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    // لیست خالی
    if (_items.isEmpty && !_isLoading) {
      return widget.emptyWidget ?? _buildDefaultEmpty();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding ?? const EdgeInsets.all(16),
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasMore ? 1 : 0) + (widget.headerWidget != null ? 1 : 0),
        itemBuilder: (context, index) {
          // هدر
          if (widget.headerWidget != null && index == 0) {
            return widget.headerWidget!;
          }
          
          final itemIndex = widget.headerWidget != null ? index - 1 : index;
          
          // لودینگ انتهای لیست
          if (itemIndex >= _items.length) {
            return _buildLoadingIndicator();
          }

          // آیتم‌ها
          final item = _items[itemIndex];
          if (widget.separatorBuilder != null && itemIndex > 0) {
            return Column(
              children: [
                widget.separatorBuilder!,
                widget.itemBuilder(context, item, itemIndex),
              ],
            );
          }
          return widget.itemBuilder(context, item, itemIndex);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildDefaultEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('موردی یافت نشد', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDefaultError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('خطا در بارگذاری', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }
}
