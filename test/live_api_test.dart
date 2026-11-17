// Integration test of the real Flutter data layer against a running backend.
//
// Skipped unless XADIIS_LIVE_API is set, e.g.:
//   XADIIS_LIVE_API=http://localhost:3000/api/v1 flutter test test/live_api_test.dart
//
// Use only against a local/test database: it registers throwaway users.
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/core/network/api_client.dart';
import 'package:xadiithapp/core/network/api_exception.dart';
import 'package:xadiithapp/core/storage/token_storage.dart';
import 'package:xadiithapp/data/repositories/hadith_repository.dart';
import 'package:xadiithapp/data/repositories/user_repository.dart';

void main() {
  final baseUrl = Platform.environment['XADIIS_LIVE_API'];
  final skip = baseUrl == null ? 'Set XADIIS_LIVE_API to run against a live API' : null;

  late MemoryTokenStorage tokens;
  late ApiClient api;

  setUp(() {
    tokens = MemoryTokenStorage();
    api = ApiClient(tokenStorage: tokens, baseUrl: baseUrl);
  });

  test('public content endpoints parse into app models', () async {
    final repo = HadithRepository(api);
    final books = await repo.books();
    expect(books.items.map((b) => b.slug), containsAll(['sahih-bukhari', 'sahih-muslim', 'sunan-ibn-majah']));

    final bukhari = await repo.book('sahih-bukhari');
    expect(bukhari.nameArabic, isNotEmpty);
    expect((await repo.chapters(bukhari.id)).items, isA<List>());

    final categories = await repo.categories();
    expect(categories.items, isNotEmpty);

    // Hadith of the day is null until verified content is published.
    final hotd = await repo.hadithOfTheDay();
    expect(hotd == null || hotd.arabicText.isNotEmpty, isTrue);

    final results = await repo.search('salaad');
    expect(results.meta.page, 1);
  }, skip: skip);

  test('register → me → token refresh → logout', () async {
    final auth = AuthRepository(api, tokens);
    final email = 'flutter-live-${DateTime.now().microsecondsSinceEpoch}@example.test';
    final user = await auth.register(email: email, password: 'correct-horse-9', displayName: 'Live Test');
    expect(user.email, email);
    expect(user.displayName, 'Live Test');

    // Force a refresh: corrupt the access token, the client must recover.
    final refreshBefore = tokens.refresh;
    tokens.access = 'invalid';
    final me = await auth.me();
    expect(me.email, email);
    expect(tokens.refresh, isNot(refreshBefore), reason: 'refresh token must rotate');

    final memo = MemorizationRepository(api);
    expect(await memo.all(), isEmpty);
    expect(await BookmarkRepository(api).all(), isEmpty);

    await auth.logout();
    expect(await auth.hasSession(), isFalse);
    await expectLater(auth.me(), throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)));
  }, skip: skip);

  test('duplicate registration surfaces a conflict', () async {
    final auth = AuthRepository(api, tokens);
    final email = 'flutter-dup-${DateTime.now().microsecondsSinceEpoch}@example.test';
    await auth.register(email: email, password: 'correct-horse-9', displayName: 'A');
    await expectLater(
      auth.register(email: email, password: 'correct-horse-9', displayName: 'B'),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.conflict)),
    );
  }, skip: skip);
}
