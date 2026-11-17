import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final user = ref.watch(authProvider).value;
    final theme = Theme.of(context);
    final memorized = ref.watch(memorizationProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (user?.displayName?.isNotEmpty ?? false) ? user!.displayName![0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 24, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? s.guest, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? s.guestBody, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (user == null)
            Row(
              children: [
                Expanded(child: FilledButton(onPressed: () => context.push('/login'), child: Text(s.login))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: () => context.push('/register'), child: Text(s.register))),
              ],
            ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: Text(s.favorites),
                  trailing: Text('${ref.watch(favoritesProvider).length}'),
                  onTap: () => context.push('/favorites'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(s.readingHistory),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/history'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.psychology_outlined),
                  title: Text(s.memorization),
                  trailing: Text(user == null ? '' : '${memorized.length}'),
                  onTap: () => context.go('/memorization'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(s.settings),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(s.about),
              subtitle: Text(s.contentNotice),
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(s.logout),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final store = ref.read(localStoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SectionHeader(title: s.language),
          RadioGroup<String>(
            groupValue: settings.language,
            onChanged: (v) => notifier.setLanguage(v!),
            child: const Column(
              children: [
                RadioListTile(value: 'so', title: Text('Soomaali')),
                RadioListTile(value: 'en', title: Text('English')),
              ],
            ),
          ),
          SectionHeader(title: s.theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(s.themeSystem), icon: const Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text(s.themeLight), icon: const Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text(s.themeDark), icon: const Icon(Icons.dark_mode_outlined)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => notifier.setThemeMode(v.first),
            ),
          ),
          SectionHeader(title: s.textSize),
          Slider(
            value: settings.textScale,
            min: 0.8,
            max: 1.8,
            divisions: 10,
            label: '${(settings.textScale * 100).round()}%',
            onChanged: notifier.setTextScale,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ArabicText('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
          ),
          SectionHeader(title: s.notifications),
          SwitchListTile(
            title: Text(s.notifyDaily),
            value: store.notifyDailyHadith,
            onChanged: (v) async {
              await store.setNotifyDailyHadith(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(s.notifyReviews),
            value: store.notifyReviews,
            onChanged: (v) async {
              await store.setNotifyReviews(v);
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(s.notificationsNote, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (AppConfig.isDevelopmentDefault) ...[
            const SectionHeader(title: 'Developer'),
            ListTile(dense: true, title: const Text('API base URL'), subtitle: Text(AppConfig.apiBaseUrl)),
          ],
        ],
      ),
    );
  }
}

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final items = ref.watch(recentProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.readingHistory),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: s.clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(recentProvider.notifier).clear(),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyView(message: s.noRecent, icon: Icons.history)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => HadithCard(hadith: items[i]),
            ),
    );
  }
}
