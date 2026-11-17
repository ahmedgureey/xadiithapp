import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import 'common.dart';
import 'state_views.dart';

typedef HadithPageLoader = Future<Paginated<Hadith>> Function(int page);

/// Infinite-scrolling list of Hadiths backed by a paginated API call.
///
/// The list loads once per element; give it a new [Key] (e.g. the search
/// query) to restart from page 1.
class PagedHadithList extends StatefulWidget {
  const PagedHadithList({super.key, required this.loader, required this.emptyMessage, this.header});

  final HadithPageLoader loader;
  final String emptyMessage;
  final Widget? header;

  @override
  State<PagedHadithList> createState() => _PagedHadithListState();
}

class _PagedHadithListState extends State<PagedHadithList> {
  final _items = <Hadith>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  void _reset() {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loader(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.meta.page;
        _hasMore = result.meta.hasNext && result.items.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      final Widget body;
      if (_error != null) {
        body = ErrorView(error: _error!, onRetry: _loadMore);
      } else if (_loading) {
        body = const LoadingView();
      } else {
        body = EmptyView(message: widget.emptyMessage, icon: Icons.menu_book_outlined);
      }
      return ListView(children: [?widget.header, body]);
    }

    final headerCount = widget.header == null ? 0 : 1;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async => _reset(),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: headerCount + _items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (headerCount == 1 && i == 0) return widget.header!;
            final idx = i - headerCount;
            if (idx < _items.length) return HadithCard(hadith: _items[idx]);
            if (_error != null) return ErrorView(error: _error!, onRetry: _loadMore);
            return _hasMore ? const LoadingView(padding: EdgeInsets.all(16)) : const SizedBox(height: 16);
          },
        ),
      ),
    );
  }
}
