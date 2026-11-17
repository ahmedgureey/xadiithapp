import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';

class HadithDetailScreen extends ConsumerStatefulWidget {
  const HadithDetailScreen({super.key, required this.hadithId, this.initial});

  final String hadithId;
  final Hadith? initial;

  @override
  ConsumerState<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends ConsumerState<HadithDetailScreen> {
  bool _recorded = false;

  void _record(Hadith h) {
    if (_recorded) return;
    _recorded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(recentProvider.notifier).record(h));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(hadithProvider(widget.hadithId));
    // Show the list-item snapshot instantly while the full record loads.
    final hadith = value.value ?? (value.hasError ? null : widget.initial);
    if (value.value != null) _record(value.value!);

    return Scaffold(
      appBar: AppBar(
        title: Text(hadith == null ? s.hadiths : s.hadithNo(hadith.hadithNumber)),
        actions: [
          IconButton(tooltip: s.textSize, icon: const Icon(Icons.format_size), onPressed: () => _showTextSize(context, s)),
          if (hadith != null) ...[
            _FavoriteButton(hadith: hadith),
            IconButton(tooltip: s.share, icon: const Icon(Icons.share_outlined), onPressed: () => _share(hadith, s)),
          ],
        ],
      ),
      body: hadith != null
          ? _HadithBody(hadith: hadith)
          : AsyncValueView<Hadith>(
              value: value,
              onRetry: () => ref.invalidate(hadithProvider(widget.hadithId)),
              data: (h) => _HadithBody(hadith: h),
            ),
    );
  }

  void _share(Hadith h, AppStrings s) {
    final buffer = StringBuffer()..writeln(h.arabicText);
    final so = h.somali;
    if (so != null) {
      buffer
        ..writeln()
        ..writeln(so.text);
    }
    buffer
      ..writeln()
      ..writeln('— ${h.book.nameEnglish}, ${s.hadithNo(h.hadithNumber)}');
    final grade = h.gradings.firstOrNull;
    if (grade != null) buffer.writeln('${s.grading}: ${grade.grade}${grade.gradedBy != null ? ' (${grade.gradedBy})' : ''}');
    buffer.writeln('\n${s.appName}');
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  void _showTextSize(BuildContext context, AppStrings s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final scale = ref.watch(settingsProvider.select((x) => x.textScale));
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.textSize, style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  const Icon(Icons.text_decrease),
                  Expanded(
                    child: Slider(
                      value: scale,
                      min: SettingsNotifier.minScale,
                      max: SettingsNotifier.maxScale,
                      divisions: 10,
                      label: '${(scale * 100).round()}%',
                      onChanged: ref.read(settingsProvider.notifier).setTextScale,
                    ),
                  ),
                  const Icon(Icons.text_increase),
                ],
              ),
              const ArabicText('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
            ],
          ),
        );
      }),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final isFav = ref.watch(favoritesProvider.select((f) => f.any((h) => h.id == hadith.id)));
    return IconButton(
      tooltip: isFav ? s.removeFavorite : s.addFavorite,
      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Theme.of(context).colorScheme.error : null),
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(hadith),
    );
  }
}

class _HadithBody extends ConsumerWidget {
  const _HadithBody({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final h = hadith;
    final somali = h.somali;
    final explanations = h.explanations.where((e) => e.language == 'so' || e.language == s.languageCode).toList();
    final chapter = h.chapter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Reference header
        Text(
          s.isSomali ? h.book.nameSomali : h.book.nameEnglish,
          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        ),
        Directionality(textDirection: TextDirection.rtl, child: Text(h.book.nameArabic, style: theme.textTheme.titleMedium)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(s.hadithNo(h.hadithNumber), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            for (final g in h.gradings) GradeBadge(g.grade),
          ],
        ),
        if (chapter != null) ...[
          const SizedBox(height: 4),
          Text(
            '${s.chapter} ${chapter.number}: ${s.isSomali ? (chapter.titleSomali ?? chapter.titleEnglish ?? '') : (chapter.titleEnglish ?? chapter.titleSomali ?? '')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),

        _Section(
          title: s.arabicText,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (h.narrator != null && h.narrator!.isNotEmpty) ...[
                Text('${s.narrator}: ${h.narrator}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
              ],
              ArabicText(h.arabicText, baseSize: 24),
            ],
          ),
        ),
        _Section(
          title: s.somaliTranslation,
          child: somali == null
              ? Text(s.noTranslation, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SomaliText(somali.text, baseSize: 17),
                    _Attribution(label: s.translator, value: somali.translator),
                    _Attribution(label: s.source, value: somali.source),
                  ],
                ),
        ),
        if (h.gradings.isNotEmpty)
          _Section(
            title: s.grading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in h.gradings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GradeBadge(g.grade),
                        _Attribution(label: s.gradedBy, value: g.gradedBy),
                        _Attribution(label: s.source, value: g.source),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        for (final e in explanations)
          _Section(
            title: s.explanation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SomaliText(e.text),
                _Attribution(label: s.reference, value: e.author),
                _Attribution(label: s.source, value: e.source),
              ],
            ),
          ),
        if (h.sourceReference != null && h.sourceReference!.isNotEmpty)
          _Section(title: s.reference, child: SelectableText(h.sourceReference!)),
        if (h.categories.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in h.categories)
                ActionChip(
                  avatar: Icon(categoryIcon(c.icon), size: 18),
                  label: Text(s.isSomali ? c.nameSomali : (c.nameEnglish ?? c.nameSomali)),
                  onPressed: () => context.push('/topics/${c.id}', extra: c),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _AddToMemorizationButton(hadithId: h.id),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _AddToMemorizationButton extends ConsumerStatefulWidget {
  const _AddToMemorizationButton({required this.hadithId});

  final String hadithId;

  @override
  ConsumerState<_AddToMemorizationButton> createState() => _AddToMemorizationButtonState();
}

class _AddToMemorizationButtonState extends ConsumerState<_AddToMemorizationButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final signedIn = ref.watch(isSignedInProvider);
    final items = ref.watch(memorizationProvider).value ?? const [];
    final added = items.any((m) => m.hadithId == widget.hadithId);

    return OutlinedButton.icon(
      icon: Icon(added ? Icons.check_circle : Icons.psychology_outlined),
      label: Text(added ? s.addedToMemorization : s.addToMemorization),
      onPressed: added || _busy
          ? null
          : () async {
              if (!signedIn) {
                context.push('/login');
                return;
              }
              setState(() => _busy = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(memorizationProvider.notifier).add(widget.hadithId);
                messenger.showSnackBar(SnackBar(content: Text(s.addedToMemorization)));
              } on ApiException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.isConnectivity ? s.errorNetwork : e.message)));
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}
