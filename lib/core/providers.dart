import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';
import '../data/repositories/hadith_repository.dart';
import '../data/repositories/user_repository.dart';
import 'l10n/app_strings.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';
import 'storage/local_store.dart';
import 'storage/token_storage.dart';

// ---------------------------------------------------------------------------
// Infrastructure (overridden in main() and in tests)
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokenStorage: ref.watch(tokenStorageProvider)));

final hadithRepositoryProvider = Provider((ref) => HadithRepository(ref.watch(apiClientProvider)));
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)));
final bookmarkRepositoryProvider = Provider((ref) => BookmarkRepository(ref.watch(apiClientProvider)));
final memorizationRepositoryProvider = Provider((ref) => MemorizationRepository(ref.watch(apiClientProvider)));
final historyRepositoryProvider = Provider((ref) => ReadingHistoryRepository(ref.watch(apiClientProvider)));

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class AppSettings {
  const AppSettings({required this.themeMode, required this.language, required this.textScale, required this.dailyGoal});

  final ThemeMode themeMode;
  final String language;
  final double textScale;
  final int dailyGoal;

  AppSettings copyWith({ThemeMode? themeMode, String? language, double? textScale, int? dailyGoal}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        textScale: textScale ?? this.textScale,
        dailyGoal: dailyGoal ?? this.dailyGoal,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  AppSettings build() {
    final store = ref.watch(localStoreProvider);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == store.themeMode, orElse: () => ThemeMode.system),
      language: store.language,
      textScale: store.textScale,
      dailyGoal: store.dailyGoal,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _store.setThemeMode(mode.name);
  }

  void setLanguage(String code) {
    state = state.copyWith(language: code);
    _store.setLanguage(code);
  }

  static const double minScale = 0.8;
  static const double maxScale = 1.8;

  void setTextScale(double scale) {
    final v = scale.clamp(minScale, maxScale).toDouble();
    state = state.copyWith(textScale: v);
    _store.setTextScale(v);
  }

  void setDailyGoal(int goal) {
    state = state.copyWith(dailyGoal: goal);
    _store.setDailyGoal(goal);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final stringsProvider = Provider<AppStrings>((ref) => AppStrings(ref.watch(settingsProvider.select((s) => s.language))));

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

/// `null` = guest. Reading public Hadiths never requires a session.
class AuthNotifier extends AsyncNotifier<UserProfile?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserProfile?> build() async {
    ref.read(apiClientProvider).onSessionExpired = () => state = const AsyncData(null);
    if (!await _repo.hasSession()) return null;
    try {
      return await _repo.me();
    } on ApiException catch (e) {
      // Offline at startup: keep tokens, behave as guest until next launch.
      if (e.kind == ApiErrorKind.unauthorized) await _repo.logout();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    final user = await _repo.login(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> register(String email, String password, String displayName) async {
    final user = await _repo.register(email: email, password: password, displayName: displayName);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserProfile?>(AuthNotifier.new);

final isSignedInProvider = Provider<bool>((ref) => ref.watch(authProvider).value != null);

// ---------------------------------------------------------------------------
// Favorites (local-first, synced with the API when signed in)
// ---------------------------------------------------------------------------

class FavoritesNotifier extends Notifier<List<Hadith>> {
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  List<Hadith> build() {
    ref.listen<bool>(isSignedInProvider, (prev, signedIn) {
      if (signedIn && prev != true) unawaited(sync());
    });
    return ref.watch(localStoreProvider).favorites;
  }

  bool contains(String hadithId) => state.any((h) => h.id == hadithId);

  Future<void> toggle(Hadith hadith) async {
    final wasFavorite = contains(hadith.id);
    final next = wasFavorite ? state.where((h) => h.id != hadith.id).toList() : [hadith, ...state];
    state = next;
    await _store.setFavorites(next);

    if (!ref.read(isSignedInProvider)) return;
    final repo = ref.read(bookmarkRepositoryProvider);
    try {
      wasFavorite ? await repo.remove(hadith.id) : await repo.add(hadith.id);
    } on ApiException {
      // Kept locally; reconciled on next sync.
    }
  }

  /// Pushes local favorites to the server, then adopts the merged server list.
  Future<void> sync() async {
    final repo = ref.read(bookmarkRepositoryProvider);
    try {
      final remote = await repo.all();
      final remoteIds = remote.map((h) => h.id).toSet();
      for (final local in state.where((h) => !remoteIds.contains(h.id))) {
        try {
          await repo.add(local.id);
        } on ApiException {
          // e.g. Hadith no longer published; skip.
        }
      }
      final merged = await repo.all();
      state = merged;
      await _store.setFavorites(merged);
    } on ApiException {
      // Offline: keep local list.
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<Hadith>>(FavoritesNotifier.new);

// ---------------------------------------------------------------------------
// Recently viewed / reading history
// ---------------------------------------------------------------------------

class RecentNotifier extends Notifier<List<Hadith>> {
  @override
  List<Hadith> build() => ref.watch(localStoreProvider).recent;

  Future<void> record(Hadith hadith) async {
    final store = ref.read(localStoreProvider);
    await store.pushRecent(hadith);
    state = store.recent;
    if (ref.read(isSignedInProvider)) {
      try {
        await ref.read(historyRepositoryProvider).record(hadith.id);
      } on ApiException {
        // Non-critical.
      }
    }
  }

  Future<void> clear() async {
    await ref.read(localStoreProvider).clearRecent();
    state = const [];
  }
}

final recentProvider = NotifierProvider<RecentNotifier, List<Hadith>>(RecentNotifier.new);

// ---------------------------------------------------------------------------
// Public content
// ---------------------------------------------------------------------------

final booksProvider = FutureProvider<List<Book>>((ref) async => (await ref.watch(hadithRepositoryProvider).books()).items);

final categoriesProvider =
    FutureProvider<List<Category>>((ref) async => (await ref.watch(hadithRepositoryProvider).categories()).items);

final hadithOfTheDayProvider = FutureProvider<Hadith?>((ref) => ref.watch(hadithRepositoryProvider).hadithOfTheDay());

final bookProvider = FutureProvider.family<Book, String>((ref, id) => ref.watch(hadithRepositoryProvider).book(id));

final chaptersProvider =
    FutureProvider.family<List<Chapter>, String>((ref, id) async => (await ref.watch(hadithRepositoryProvider).chapters(id)).items);

final hadithProvider = FutureProvider.family<Hadith, String>((ref, id) => ref.watch(hadithRepositoryProvider).hadith(id));

// ---------------------------------------------------------------------------
// Memorization (requires sign-in; progress is stored server-side)
// ---------------------------------------------------------------------------

class MemorizationNotifier extends AsyncNotifier<List<MemorizationItem>> {
  MemorizationRepository get _repo => ref.read(memorizationRepositoryProvider);

  @override
  Future<List<MemorizationItem>> build() async {
    if (!ref.watch(isSignedInProvider)) return const [];
    return _repo.all();
  }

  Future<void> add(String hadithId) async {
    await _repo.add(hadithId);
    ref.invalidateSelf();
  }

  Future<void> review(String id, int quality) async {
    await _repo.review(id, quality);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final memorizationProvider = AsyncNotifierProvider<MemorizationNotifier, List<MemorizationItem>>(MemorizationNotifier.new);
