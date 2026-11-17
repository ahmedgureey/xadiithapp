import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:xadiithapp/core/network/api_client.dart';
import 'package:xadiithapp/core/storage/token_storage.dart';

typedef FakeHandler = (int, Object?) Function(RequestOptions options);

/// Dio adapter that answers requests from an in-memory route table, so tests
/// never touch the network. Fixture text is deliberately obvious test data,
/// not religious content.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> testBookJson({String id = 'b1', String slug = 'sahih-bukhari'}) => {
      'id': id,
      'slug': slug,
      'nameArabic': 'TEST-AR-BOOK',
      'nameSomali': 'Test Kitaab',
      'nameEnglish': 'Test Book',
      'authorName': 'Test Author',
      'hadithCount': 0,
      'chapterCount': 0,
      'sortOrder': 1,
    };

Map<String, dynamic> testHadithJson({String id = 'h1'}) => {
      'id': id,
      'hadithNumber': '7',
      'arabicText': 'TEST ARABIC TEXT',
      'narrator': null,
      'sourceReference': 'Test reference',
      'book': testBookJson(),
      'chapter': null,
      'translations': [
        {'id': 't1', 'language': 'so', 'text': 'TEST SOMALI TEXT', 'translator': 'Tester', 'source': 'Test source'},
      ],
      'gradings': [
        {'id': 'g1', 'grade': 'TEST-GRADE', 'gradedBy': 'Tester', 'source': 'Test source'},
      ],
      'explanations': [],
      'categories': [],
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

Map<String, dynamic> listBody(List<Map<String, dynamic>> items) => {
      'data': items,
      'meta': {'page': 1, 'limit': 20, 'total': items.length, 'totalPages': 1},
    };

/// Default routes for a working, mostly empty API.
(int, Object?) defaultRoutes(RequestOptions o) {
  return switch (o.path) {
    '/books' => (200, listBody([testBookJson()])),
    '/categories' => (200, listBody([])),
    '/hadith-of-the-day' => (200, {'data': null}),
    _ => (404, {'statusCode': 404, 'error': 'Not Found', 'message': 'Not found'}),
  };
}

ApiClient fakeApiClient({FakeHandler handler = defaultRoutes, TokenStorage? tokens, FakeAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = adapter ?? FakeAdapter(handler);
  return ApiClient(tokenStorage: tokens ?? MemoryTokenStorage(), dio: dio);
}
