import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';

class MemorizationScreen extends ConsumerWidget {
  const MemorizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.memorization)),
      body: signedIn
          ? AsyncValueView<List<MemorizationItem>>(
              value: ref.watch(memorizationProvider),
              onRetry: () => ref.invalidate(memorizationProvider),
              data: (items) => _Dashboard(items: items, strings: s),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _GoalCard(strings: s),
                const SizedBox(height: 16),
                MessageView(
                  icon: Icons.lock_outline,
                  message: s.memorizationLoginPrompt,
                  action: () => context.push('/login'),
                  actionLabel: s.login,
                ),
              ],
            ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.items, required this.strings});

  final List<MemorizationItem> items;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final theme = Theme.of(context);
    final due = items.where((m) => m.isDue && m.status != MemorizationStatus.memorized).toList();
    final learned = items.where((m) => m.status == MemorizationStatus.memorized).length;
    final inProgress = items.length - learned;
    final ratio = items.isEmpty ? 0.0 : learned / items.length;

    return RefreshIndicator(
      onRefresh: () => ref.read(memorizationProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.progress, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('${(ratio * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(label: s.learned, value: learned),
                    _Stat(label: s.inProgress, value: inProgress),
                    _Stat(label: s.dueForReview, value: due.length),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GoalCard(strings: s),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(due.isEmpty ? s.nothingDue : '${s.startReview} (${due.length})'),
            onPressed: due.isEmpty ? null : () => context.push('/review'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.quiz_outlined),
            label: Text(s.quiz),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.quizComingSoon))),
          ),
          SectionHeader(title: s.memorization),
          if (items.isEmpty)
            EmptyView(message: s.noMemorization, icon: Icons.psychology_outlined)
          else
            for (final m in items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_statusIcon(m.status), color: theme.colorScheme.primary),
                  title: Text(
                    m.hadith == null
                        ? m.hadithId
                        : '${s.isSomali ? m.hadith!.book.nameSomali : m.hadith!.book.nameEnglish} · ${s.hadithNo(m.hadith!.hadithNumber)}',
                  ),
                  subtitle: m.hadith == null ? null : ArabicText(m.hadith!.arabicText, baseSize: 15, maxLines: 1),
                  trailing: m.isDue && m.status != MemorizationStatus.memorized
                      ? Icon(Icons.schedule, color: theme.colorScheme.tertiary)
                      : null,
                  onTap: m.hadith == null ? null : () => context.push('/hadith/${m.hadithId}', extra: m.hadith),
                ),
              ),
        ],
      ),
    );
  }

  IconData _statusIcon(MemorizationStatus st) => switch (st) {
        MemorizationStatus.memorized => Icons.verified,
        MemorizationStatus.reviewing => Icons.autorenew,
        MemorizationStatus.learning => Icons.school_outlined,
        MemorizationStatus.newItem => Icons.fiber_new_outlined,
      };
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(settingsProvider.select((x) => x.dailyGoal));
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text(strings.dailyGoal),
        subtitle: Text(strings.dailyGoalValue(goal)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: goal > 1 ? () => ref.read(settingsProvider.notifier).setDailyGoal(goal - 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: goal < 20 ? () => ref.read(settingsProvider.notifier).setDailyGoal(goal + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Flashcard-style review: read the Arabic, recall, reveal, self-rate.
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  List<MemorizationItem>? _queue;
  int _index = 0;
  bool _revealed = false;
  bool _busy = false;

  Future<void> _rate(int quality) async {
    final item = _queue![_index];
    setState(() => _busy = true);
    try {
      await ref.read(memorizationProvider.notifier).review(item.id, quality);
      setState(() {
        _index++;
        _revealed = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.isConnectivity ? s.errorNetwork : e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    _queue ??= ref
        .read(memorizationProvider)
        .value
        ?.where((m) => m.isDue && m.status != MemorizationStatus.memorized && m.hadith != null)
        .toList();
    final queue = _queue ?? const [];

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(memorizationProvider);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(queue.isEmpty ? s.reviewSession : '${s.reviewSession} ${_index.clamp(0, queue.length)}/${queue.length}')),
        body: _index >= queue.length
            ? MessageView(icon: Icons.celebration_outlined, message: s.reviewDone, action: () => context.pop(), actionLabel: 'OK')
            : _card(queue[_index].hadith!, s),
      ),
    );
  }

  Widget _card(Hadith h, AppStrings s) {
    final somali = h.somali;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: _queue!.isEmpty ? 0 : _index / _queue!.length),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${s.isSomali ? h.book.nameSomali : h.book.nameEnglish} · ${s.hadithNo(h.hadithNumber)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 12),
                ArabicText(h.arabicText, baseSize: 24),
                if (_revealed) ...[
                  const Divider(height: 32),
                  SomaliText(somali?.text ?? s.noTranslation, baseSize: 17),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!_revealed)
          FilledButton(onPressed: () => setState(() => _revealed = true), child: Text(s.showTranslation))
        else ...[
          Text(s.howWell, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (label, q) in [(s.rateAgain, 1), (s.rateHard, 3), (s.rateGood, 4), (s.rateEasy, 5)])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                      onPressed: _busy ? null : () => _rate(q),
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
