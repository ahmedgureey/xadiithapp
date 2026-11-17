import 'package:flutter_test/flutter_test.dart';
import 'package:xadiithapp/data/models/models.dart';

import 'helpers/fake_api.dart';

void main() {
  group('Hadith', () {
    test('parses the API contract and exposes the Somali translation', () {
      final h = Hadith.fromJson(testHadithJson());
      expect(h.id, 'h1');
      expect(h.hadithNumber, '7');
      expect(h.book.slug, 'sahih-bukhari');
      expect(h.somali?.text, 'TEST SOMALI TEXT');
      expect(h.gradings.single.grade, 'TEST-GRADE');
      expect(h.chapter, isNull);
    });

    test('round-trips through toJson for local caching', () {
      final original = Hadith.fromJson(testHadithJson());
      final copy = Hadith.fromJson(original.toJson());
      expect(copy.arabicText, original.arabicText);
      expect(copy.somali?.translator, 'Tester');
      expect(copy.gradings.single.source, 'Test source');
      expect(copy.book.nameArabic, original.book.nameArabic);
    });

    test('tolerates missing optional fields', () {
      final h = Hadith.fromJson({'id': 'x', 'hadithNumber': 1, 'arabicText': 'A', 'book': {}});
      expect(h.hadithNumber, '1');
      expect(h.translations, isEmpty);
      expect(h.somali, isNull);
    });
  });

  test('Paginated parses data and meta', () {
    final p = Paginated.fromJson({
      'data': [testBookJson()],
      'meta': {'page': 1, 'limit': 20, 'total': 41, 'totalPages': 3},
    }, Book.fromJson);
    expect(p.items.single.nameEnglish, 'Test Book');
    expect(p.meta.total, 41);
    expect(p.meta.hasNext, isTrue);
  });

  test('MemorizationItem maps status and due date', () {
    final m = MemorizationItem.fromJson({
      'id': 'm1',
      'hadithId': 'h1',
      'status': 'REVIEWING',
      'repetitions': 2,
      'intervalDays': 6,
      'nextReviewAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    });
    expect(m.status, MemorizationStatus.reviewing);
    expect(m.isDue, isTrue);
    expect(memorizationStatusFromApi('MEMORIZED'), MemorizationStatus.memorized);
    expect(memorizationStatusFromApi(null), MemorizationStatus.newItem);
  });

  test('knownCollections lists the six canonical books', () {
    expect(knownCollections, hasLength(6));
    expect(knownCollections.map((b) => b.slug).toSet(), hasLength(6));
  });
}
