import 'package:dio/dio.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, validation, conflict, server, unknown }

/// A normalized error raised by the API layer, so UI code never handles Dio
/// types directly.
class ApiException implements Exception {
  ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(ApiErrorKind.timeout, 'Request timed out');
      case DioExceptionType.connectionError:
        return ApiException(ApiErrorKind.network, 'Could not reach the server');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final message = _extractMessage(e.response?.data) ?? 'Request failed ($status)';
        return ApiException(_kindFor(status), message, statusCode: status);
      default:
        return ApiException(ApiErrorKind.unknown, e.message ?? 'Unexpected error');
    }
  }

  static ApiErrorKind _kindFor(int status) {
    if (status == 400 || status == 422) return ApiErrorKind.validation;
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 404) return ApiErrorKind.notFound;
    if (status == 409) return ApiErrorKind.conflict;
    if (status >= 500) return ApiErrorKind.server;
    return ApiErrorKind.unknown;
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map) {
      final m = data['message'];
      if (m is String) return m;
      if (m is List && m.isNotEmpty) return m.join('\n');
    }
    return null;
  }

  bool get isConnectivity => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
