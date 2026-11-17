import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

/// Arabic text, always rendered right-to-left with generous line height.
class ArabicText extends ConsumerWidget {
  const ArabicText(this.text, {super.key, this.baseSize = 22, this.maxLines, this.style});

  final String text;
  final double baseSize;
  final int? maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(settingsProvider.select((s) => s.textScale));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: (style ?? const TextStyle()).copyWith(fontSize: baseSize * scale, height: 1.9),
      ),
    );
  }
}

/// Somali / Latin-script text, always left-to-right.
class SomaliText extends ConsumerWidget {
  const SomaliText(this.text, {super.key, this.baseSize = 16, this.maxLines, this.style});

  final String text;
  final double baseSize;
  final int? maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(settingsProvider.select((s) => s.textScale));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: (style ?? const TextStyle()).copyWith(fontSize: baseSize * scale, height: 1.5),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel ?? '')),
        ],
      ),
    );
  }
}

class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Text(grade, style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Compact Hadith preview used in lists.
class HadithCard extends ConsumerWidget {
  const HadithCard({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final isFav = ref.watch(favoritesProvider.select((f) => f.any((h) => h.id == hadith.id)));
    final theme = Theme.of(context);
    final somali = hadith.somali;
    final grade = hadith.gradings.firstOrNull?.grade;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => context.push('/hadith/${hadith.id}', extra: hadith),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.isSomali ? hadith.book.nameSomali : hadith.book.nameEnglish} · ${s.hadithNo(hadith.hadithNumber)}',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (grade != null) GradeBadge(grade),
                  if (isFav) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.favorite, size: 18, color: theme.colorScheme.error)),
                ],
              ),
              const SizedBox(height: 12),
              ArabicText(hadith.arabicText, baseSize: 19, maxLines: 3),
              if (somali != null) ...[
                const SizedBox(height: 8),
                SomaliText(somali.text, baseSize: 14, maxLines: 3, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData categoryIcon(String? key) => switch (key) {
      'favorite' => Icons.favorite_outline,
      'mosque' => Icons.mosque_outlined,
      'nightlight' => Icons.nightlight_outlined,
      'volunteer_activism' => Icons.volunteer_activism_outlined,
      'explore' => Icons.explore_outlined,
      'water_drop' => Icons.water_drop_outlined,
      'emoji_people' => Icons.emoji_people_outlined,
      'menu_book' => Icons.menu_book_outlined,
      'family_restroom' => Icons.family_restroom_outlined,
      'front_hand' => Icons.front_hand_outlined,
      _ => Icons.label_outline,
    };

/// Decorative gradient header used on the home and collection screens.
class GradientCard extends StatelessWidget {
  const GradientCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppTheme.radius + 4),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkGreen, AppColors.emerald],
          ),
        ),
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(20), child: child)),
      ),
    );
  }
}
