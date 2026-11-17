import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final recent = ref.watch(recentProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hadithOfTheDayProvider);
          ref.invalidate(booksProvider);
          ref.invalidate(categoriesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(strings: s)),
            SliverToBoxAdapter(child: SectionHeader(title: s.hadithOfTheDay)),
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _HadithOfTheDay()),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: s.popularCollections,
                actionLabel: s.seeAll,
                onAction: () => context.go('/collections'),
              ),
            ),
            const SliverToBoxAdapter(child: _CollectionsStrip()),
            SliverToBoxAdapter(child: SectionHeader(title: s.topics)),
            const SliverToBoxAdapter(child: _Topics()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _MemorizeShortcut(strings: s),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: s.recentlyViewed,
                actionLabel: s.seeAll,
                onAction: recent.isEmpty ? null : () => context.push('/history'),
              ),
            ),
            if (recent.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(s.noRecent, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: recent.length.clamp(0, 5),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => HadithCard(hadith: recent[i]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final user = ref.watch(authProvider).value;
    final name = user?.displayName;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkGreen, AppColors.emerald],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name == null || name.isEmpty ? s.welcome : s.welcomeName(name),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: s.favorites,
                onPressed: () => context.push('/favorites'),
                icon: const Icon(Icons.favorite_border, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(s.welcomeSubtitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: () => context.go('/search'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.darkGreen),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.searchHint, style: const TextStyle(color: Colors.black54))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithOfTheDay extends ConsumerWidget {
  const _HadithOfTheDay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(hadithOfTheDayProvider);
    return Card(
      child: AsyncValueView<Hadith?>(
        value: value,
        onRetry: () => ref.invalidate(hadithOfTheDayProvider),
        data: (h) {
          if (h == null) return EmptyView(message: s.noHadithOfTheDay, icon: Icons.auto_awesome_outlined);
          final somali = h.somali;
          return InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            onTap: () => context.push('/hadith/${h.id}', extra: h),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ArabicText(h.arabicText, baseSize: 21, maxLines: 6),
                  if (somali != null) ...[
                    const Divider(height: 28),
                    SomaliText(somali.text, maxLines: 5),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${s.isSomali ? h.book.nameSomali : h.book.nameEnglish} · ${s.hadithNo(h.hadithNumber)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionsStrip extends ConsumerWidget {
  const _CollectionsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final books = ref.watch(booksProvider);
    final List<BookSummary> items = books.value ?? knownCollections;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = items[i];
          return SizedBox(
            width: 170,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                onTap: () => context.go('/collections/${b.slug}', extra: b),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.auto_stories_outlined, color: Theme.of(context).colorScheme.primary),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(b.nameArabic, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                      ),
                      Text(
                        s.isSomali ? b.nameSomali : b.nameEnglish,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Topics extends ConsumerWidget {
  const _Topics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final cats = ref.watch(categoriesProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AsyncValueView<List<Category>>(
        value: cats,
        onRetry: () => ref.invalidate(categoriesProvider),
        loading: const LoadingView(padding: EdgeInsets.all(12)),
        data: (items) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in items)
              ActionChip(
                avatar: Icon(categoryIcon(c.icon), size: 18),
                label: Text(s.isSomali ? c.nameSomali : (c.nameEnglish ?? c.nameSomali)),
                onPressed: () => context.push('/topics/${c.id}', extra: c),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemorizeShortcut extends StatelessWidget {
  const _MemorizeShortcut({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      onTap: () => context.go('/memorization'),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.memorizeShortcutTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(strings.memorizeShortcutBody, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}
