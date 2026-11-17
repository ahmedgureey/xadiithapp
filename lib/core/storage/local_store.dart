import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/models.dart';

/// Small, synchronous-read key/value store for preferences and offline
/// caches (favorites, recently viewed). Never stores secrets — tokens live in
/// [TokenStorage].
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingDone = 'onboarding_done';
  static const _themeMode = 'theme_mode';
  static const _language = 'language';
  static const _textScale = 'arabic_text_scale';
  static const _favorites = 'favorites_v1';
  static const _recent = 'recent_v1';
  static const _dailyGoal = 'daily_goal';
  static const _notifDaily = 'notif_daily';
  static const _notifReview = 'notif_review';

  static const int maxRecent = 20;

  bool get onboardingDone => _prefs.getBool(_onboardingDone) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingDone, true);

  String get themeMode => _prefs.getString(_themeMode) ?? 'system';
  Future<void> setThemeMode(String v) => _prefs.setString(_themeMode, v);

  String get language => _prefs.getString(_language) ?? 'so';
  Future<void> setLanguage(String v) => _prefs.setString(_language, v);

  double get textScale => _prefs.getDouble(_textScale) ?? 1.0;
  Future<void> setTextScale(double v) => _prefs.setDouble(_textScale, v);

  int get dailyGoal => _prefs.getInt(_dailyGoal) ?? 1;
  Future<void> setDailyGoal(int v) => _prefs.setInt(_dailyGoal, v);

  bool get notifyDailyHadith => _prefs.getBool(_notifDaily) ?? true;
  Future<void> setNotifyDailyHadith(bool v) => _prefs.setBool(_notifDaily, v);

  bool get notifyReviews => _prefs.getBool(_notifReview) ?? true;
  Future<void> setNotifyReviews(bool v) => _prefs.setBool(_notifReview, v);

  List<Hadith> get favorites => _readHadiths(_favorites);
  Future<void> setFavorites(List<Hadith> items) => _writeHadiths(_favorites, items);

  List<Hadith> get recent => _readHadiths(_recent);

  Future<void> pushRecent(Hadith h) {
    final list = [h, ...recent.where((e) => e.id != h.id)].take(maxRecent).toList();
    return _writeHadiths(_recent, list);
  }

  Future<void> clearRecent() => _prefs.remove(_recent);

  List<Hadith> _readHadiths(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Hadith.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeHadiths(String key, List<Hadith> items) =>
      _prefs.setString(key, jsonEncode(items.map((e) => e.toJson()).toList()));
}
