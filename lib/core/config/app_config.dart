import 'package:flutter/foundation.dart';

/// Environment-specific configuration.
///
/// The API base URL is injected at build time, never hardcoded for
/// production:
///
///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
///
/// When not provided, a local development default is used (the Android
/// emulator reaches the host machine through 10.0.2.2).
class AppConfig {
  AppConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  /// True when no API_BASE_URL was supplied (local development defaults).
  static bool get isDevelopmentDefault => _definedBaseUrl.isEmpty;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const int pageSize = 20;
}
