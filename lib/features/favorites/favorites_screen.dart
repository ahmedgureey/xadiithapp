import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final items = ref.watch(favoritesProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.favorites)),
      body: RefreshIndicator(
        onRefresh: () async {
          if (signedIn) await ref.read(favoritesProvider.notifier).sync();
        },
        child: items.isEmpty
            ? ListView(children: [EmptyView(message: s.noFavorites, icon: Icons.favorite_border)])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final h = items[i];
                  return Dismissible(
                    key: ValueKey(h.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                    ),
                    onDismissed: (_) => ref.read(favoritesProvider.notifier).toggle(h),
                    child: HadithCard(hadith: h),
                  );
                },
              ),
      ),
    );
  }
}
