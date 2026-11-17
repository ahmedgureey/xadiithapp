import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio that:
///  * applies the configured base URL and timeouts,
///  * attaches the bearer access token,
///  * transparently refreshes an expired access token once on 401,
///  * converts failures into [ApiException].
class ApiClient {
  ApiClient({required this.tokenStorage, Dio? dio, Dio? refreshDio, String? baseUrl})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: {'Accept': 'application/json'},
            )) {
    // A bare Dio (no interceptors) for token refresh avoids re-entering the
    // queued interceptor, which would deadlock if the refresh itself failed.
    _refreshDio = refreshDio ?? (Dio(this.dio.options.copyWith())..httpClientAdapter = this.dio.httpClientAdapter);
    this.dio.interceptors.add(QueuedInterceptorsWrapper(
          onRequest: _onRequest,
          onError: _onError,
        ));
  }

  final Dio dio;
  late final Dio _refreshDio;
  final TokenStorage tokenStorage;

  /// Called when refresh fails, so the auth layer can sign the user out.
  void Function()? onSessionExpired;

  static const _skipAuthKey = 'skipAuth';
  static const _retriedKey = 'retried';

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_skipAuthKey] != true) {
      final token = await tokenStorage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final canRefresh = err.response?.statusCode == 401 && req.extra[_skipAuthKey] != true && req.extra[_retriedKey] != true;
    if (!canRefresh) return handler.next(err);

    final refreshed = await _refreshTokens();
    if (!refreshed) {
      if (await tokenStorage.readRefreshToken() == null) onSessionExpired?.call();
      return handler.next(err);
    }
    try {
      final token = await tokenStorage.readAccessToken();
      req.headers['Authorization'] = 'Bearer $token';
      req.extra[_retriedKey] = true;
      final response = await dio.fetch<dynamic>(req);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return false;
      await tokenStorage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException catch (e) {
      // Only an explicit rejection invalidates the session; a network blip
      // must not sign the user out.
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) await tokenStorage.clear();
      return false;
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true}) =>
      _send(() => dio.post<dynamic>(path, data: body, options: Options(extra: {_skipAuthKey: !auth})));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) => _send(() => dio.patch<dynamic>(path, data: body));

  Future<Map<String, dynamic>> put(String path, {Object? body}) => _send(() => dio.put<dynamic>(path, data: body));

  Future<void> delete(String path) => _send(() => dio.delete<dynamic>(path));

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.of(q)..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
  }
}
