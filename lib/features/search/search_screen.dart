import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/paged_hadith_list.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';

/// Searches Arabic text, Somali translation, collection name, Hadith number,
/// and (via the filters) topic.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  late String _query = (widget.initialQuery ?? '').trim();
  String? _bookId;
  String? _categoryId;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final repo = ref.read(hadithRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.search)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: s.searchByHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          if (books.isNotEmpty || categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final b in books)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.isSomali ? b.nameSomali : b.nameEnglish),
                        selected: _bookId == b.id,
                        onSelected: (sel) => setState(() => _bookId = sel ? b.id : null),
                      ),
                    ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.isSomali ? c.nameSomali : (c.nameEnglish ?? c.nameSomali)),
                        selected: _categoryId == c.id,
                        onSelected: (sel) => setState(() => _categoryId = sel ? c.id : null),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _query.isEmpty
                ? EmptyView(message: s.searchEmptyPrompt, icon: Icons.manage_search_rounded)
                : PagedHadithList(
                    key: ValueKey('$_query|$_bookId|$_categoryId'),
                    emptyMessage: s.noResults,
                    loader: (page) => repo.search(_query, bookId: _bookId, categoryId: _categoryId, page: page),
                  ),
          ),
        ],
      ),
    );
  }
}
