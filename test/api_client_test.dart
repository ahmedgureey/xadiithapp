import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/network/api_client.dart';
import 'package:xadiithapp/core/network/api_exception.dart';
import 'package:xadiithapp/core/storage/token_storage.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';

import 'helpers/fake_api.dart';

/// Builds a client whose base Dio and refresh Dio share one fake adapter.
ApiClient _client(FakeAdapter adapter, MemoryTokenStorage tokens) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))..httpClientAdapter = adapter;
  return ApiClient(tokenStorage: tokens, dio: dio);
}

void main() {
  test('attaches the bearer token', () async {
    final tokens = MemoryTokenStorage()..access = 'A1';
    final adapter = FakeAdapter((o) => (200, {'data': {}}));
    await _client(adapter, tokens).get('/me');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer A1');
  });

  test('maps error responses to ApiException with the server message', () async {
    final adapter = FakeAdapter((o) => (409, {'statusCode': 409, 'message': 'Email already registered'}));
    final client = _client(adapter, MemoryTokenStorage());
    await expectLater(
      client.post('/auth/register', body: {}, auth: false),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
          .having((e) => e.message, 'message', 'Email already registered')),
    );
  });

  test('joins validation message arrays', () async {
    final adapter = FakeAdapter((o) => (400, {'statusCode': 400, 'message': ['email must be an email', 'password too short']}));
    final client = _client(adapter, MemoryTokenStorage());
    await expectLater(
      client.post('/auth/login', body: {}, auth: false),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('password too short'))),
    );
  });

  test('refreshes once on 401, rotates tokens and retries the request', () async {
    final tokens = MemoryTokenStorage()
      ..access = 'expired'
      ..refresh = 'R1';
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        final ok = (o.data as Map)['refreshToken'] == 'R1';
        return ok
            ? (200, {'data': {'accessToken': 'fresh', 'refreshToken': 'R2', 'user': {'id': 'u', 'email': 'e'}}})
            : (401, {'message': 'Invalid refresh token'});
      }
      if (o.path == '/me') {
        return o.headers['Authorization'] == 'Bearer fresh' ? (200, {'data': {'ok': true}}) : (401, {'message': 'Unauthorized'});
      }
      return (404, null);
    });

    final res = await _client(adapter, tokens).get('/me');
    expect(res['data'], {'ok': true});
    expect(tokens.access, 'fresh');
    expect(tokens.refresh, 'R2');
    expect(adapter.requests.map((r) => r.path), ['/me', '/auth/refresh', '/me']);
  });

  test('a rejected refresh clears the session and reports expiry', () async {
    final tokens = MemoryTokenStorage()
      ..access = 'expired'
      ..refresh = 'stale';
    final adapter = FakeAdapter((o) => (401, {'message': 'Unauthorized'}));
    final client = _client(adapter, tokens);
    var expired = false;
    client.onSessionExpired = () => expired = true;

    await expectLater(client.get('/me'), throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)));
    expect(tokens.refresh, isNull);
    expect(expired, isTrue);
  });

  test('a network failure during refresh keeps the session', () async {
    final tokens = MemoryTokenStorage()
      ..access = 'expired'
      ..refresh = 'R1';
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') throw DioException.connectionError(requestOptions: o, reason: 'offline');
      return (401, {'message': 'Unauthorized'});
    });
    await expectLater(_client(adapter, tokens).get('/me'), throwsA(isA<ApiException>()));
    expect(tokens.refresh, 'R1');
  });

  test('HadithRepository.hadithOfTheDay returns null when none published', () async {
    final repo = HadithRepository(fakeApiClient());
    expect(await repo.hadithOfTheDay(), isNull);
  });

  test('HadithRepository.search sends trimmed query and parses results', () async {
    final adapter = FakeAdapter((o) => (200, listBody([testHadithJson()])));
    final repo = HadithRepository(fakeApiClient(adapter: adapter));
    final page = await repo.search('  salaad  ');
    expect(adapter.requests.single.queryParameters['q'], 'salaad');
    expect(page.items.single.arabicText, 'TEST ARABIC TEXT');
  });
}
