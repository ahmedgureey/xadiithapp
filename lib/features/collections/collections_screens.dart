import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/paged_hadith_list.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final books = ref.watch(booksProvider);

    Widget list(List<BookSummary> items, {bool offline = false}) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (offline)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MaterialBanner(
                  content: Text(s.offlineCollections),
                  leading: const Icon(Icons.wifi_off_rounded),
                  actions: [TextButton(onPressed: () => ref.invalidate(booksProvider), child: Text(s.retry))],
                ),
              ),
            for (final b in items) ...[_BookTile(book: b, strings: s), const SizedBox(height: 12)],
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.collections)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(booksProvider),
        child: books.when(
          data: (items) => list(items),
          loading: () => const LoadingView(),
          // The six collection names are static facts; show them even offline.
          error: (_, _) => list(knownCollections, offline: true),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.strings});

  final BookSummary book;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = book;
    final count = b is Book && b.hadithCount > 0 ? '${b.hadithCount} ${strings.hadiths.toLowerCase()}' : null;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.auto_stories, color: theme.colorScheme.primary),
        ),
        title: Text(strings.isSomali ? b.nameSomali : b.nameEnglish, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(textDirection: TextDirection.rtl, child: Text(b.nameArabic, style: const TextStyle(fontSize: 16))),
            if (b is Book && b.authorName != null) Text(b.authorName!, style: theme.textTheme.bodySmall),
            if (count != null) Text(count, style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/collections/${b.slug}', extra: b),
      ),
    );
  }
}

/// A single collection: its chapters, or the full Hadith list when no
/// chapters exist.
class BookScreen extends ConsumerWidget {
  const BookScreen({super.key, required this.bookId, this.initial});

  final String bookId;
  final BookSummary? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final book = ref.watch(bookProvider(bookId));
    final title = book.value ?? initial;

    return Scaffold(
      appBar: AppBar(title: Text(title == null ? s.collections : (s.isSomali ? title.nameSomali : title.nameEnglish))),
      body: AsyncValueView<Book>(
        value: book,
        onRetry: () => ref.invalidate(bookProvider(bookId)),
        data: (b) => _BookBody(book: b),
      ),
    );
  }
}

class _BookBody extends ConsumerWidget {
  const _BookBody({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chapters = ref.watch(chaptersProvider(book.id));
    final repo = ref.read(hadithRepositoryProvider);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(book.nameArabic, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text(s.isSomali ? book.nameSomali : book.nameEnglish,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            if (book.authorName != null) Text(book.authorName!, style: const TextStyle(color: Colors.white70)),
            if (book.descriptionSomali != null && s.isSomali) ...[
              const SizedBox(height: 8),
              Text(book.descriptionSomali!, style: const TextStyle(color: Colors.white)),
            ],
          ],
        ),
      ),
    );

    return chapters.when(
      loading: () => ListView(children: [header, const LoadingView()]),
      error: (e, _) => ListView(children: [header, ErrorView(error: e, onRetry: () => ref.invalidate(chaptersProvider(book.id)))]),
      data: (items) {
        if (items.isEmpty) {
          // No verified chapter structure yet: list the collection's Hadiths.
          return PagedHadithList(
            header: header,
            emptyMessage: s.noHadiths,
            loader: (page) => repo.hadiths(bookId: book.id, page: page),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            header,
            SectionHeader(title: s.chapters),
            for (final c in items)
              ListTile(
                leading: CircleAvatar(radius: 16, child: Text('${c.number}', style: const TextStyle(fontSize: 12))),
                title: Text(s.isSomali ? (c.titleSomali ?? c.titleEnglish ?? '') : (c.titleEnglish ?? c.titleSomali ?? '')),
                subtitle: c.titleArabic == null
                    ? null
                    : Directionality(textDirection: TextDirection.rtl, child: Text(c.titleArabic!, textAlign: TextAlign.right)),
                trailing: c.hadithCount > 0 ? Text('${c.hadithCount}') : const Icon(Icons.chevron_right),
                onTap: () => context.go('/collections/${book.slug}/chapters/${c.id}', extra: c),
              ),
          ],
        );
      },
    );
  }
}

class ChapterHadithsScreen extends ConsumerWidget {
  const ChapterHadithsScreen({super.key, required this.bookId, required this.chapterId, this.chapter});

  final String bookId;
  final String chapterId;
  final Chapter? chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final repo = ref.read(hadithRepositoryProvider);
    final c = chapter;
    final title = c == null ? s.chapter : '${c.number}. ${s.isSomali ? (c.titleSomali ?? c.titleEnglish ?? '') : (c.titleEnglish ?? c.titleSomali ?? '')}';
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: PagedHadithList(emptyMessage: s.noHadiths, loader: (page) => repo.hadiths(chapterId: chapterId, page: page)),
    );
  }
}

class TopicHadithsScreen extends ConsumerWidget {
  const TopicHadithsScreen({super.key, required this.categoryId, this.category});

  final String categoryId;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final repo = ref.read(hadithRepositoryProvider);
    final c = category;
    return Scaffold(
      appBar: AppBar(title: Text(c == null ? s.topics : (s.isSomali ? c.nameSomali : (c.nameEnglish ?? c.nameSomali)))),
      body: PagedHadithList(emptyMessage: s.noHadiths, loader: (page) => repo.hadiths(categoryId: categoryId, page: page)),
    );
  }
}
