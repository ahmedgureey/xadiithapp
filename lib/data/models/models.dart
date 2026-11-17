// Data models matching the Xadiis REST API (/api/v1) contract.
//
// Every model round-trips through JSON (fromJson/toJson) so it can be cached
// locally (favorites, recently viewed) as well as parsed from the API.

String? _s(dynamic v) => v?.toString();
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class PageMeta {
  const PageMeta({required this.page, required this.limit, required this.total, required this.totalPages});

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasNext => page < totalPages;

  factory PageMeta.fromJson(Map<String, dynamic>? j, int itemCount) => PageMeta(
        page: _i(j?['page'], 1),
        limit: _i(j?['limit'], itemCount),
        total: _i(j?['total'], itemCount),
        totalPages: _i(j?['totalPages'], 1),
      );
}

class Paginated<T> {
  const Paginated(this.items, this.meta);

  final List<T> items;
  final PageMeta meta;

  factory Paginated.fromJson(Map<String, dynamic> body, T Function(Map<String, dynamic>) parse) {
    final items = _list(body['data']).map(parse).toList();
    return Paginated(items, PageMeta.fromJson(body['meta'] as Map<String, dynamic>?, items.length));
  }
}

class BookSummary {
  const BookSummary({required this.id, required this.slug, required this.nameArabic, required this.nameSomali, required this.nameEnglish});

  final String id;
  final String slug;
  final String nameArabic;
  final String nameSomali;
  final String nameEnglish;

  factory BookSummary.fromJson(Map<String, dynamic> j) => BookSummary(
        id: _s(j['id']) ?? '',
        slug: _s(j['slug']) ?? '',
        nameArabic: _s(j['nameArabic']) ?? '',
        nameSomali: _s(j['nameSomali']) ?? '',
        nameEnglish: _s(j['nameEnglish']) ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'slug': slug, 'nameArabic': nameArabic, 'nameSomali': nameSomali, 'nameEnglish': nameEnglish};
}

class Book extends BookSummary {
  const Book({
    required super.id,
    required super.slug,
    required super.nameArabic,
    required super.nameSomali,
    required super.nameEnglish,
    this.authorName,
    this.descriptionSomali,
    this.hadithCount = 0,
    this.chapterCount = 0,
    this.sortOrder = 0,
  });

  final String? authorName;
  final String? descriptionSomali;
  final int hadithCount;
  final int chapterCount;
  final int sortOrder;

  factory Book.fromJson(Map<String, dynamic> j) {
    final b = BookSummary.fromJson(j);
    return Book(
      id: b.id,
      slug: b.slug,
      nameArabic: b.nameArabic,
      nameSomali: b.nameSomali,
      nameEnglish: b.nameEnglish,
      authorName: _s(j['authorName']),
      descriptionSomali: _s(j['descriptionSomali']),
      hadithCount: _i(j['hadithCount']),
      chapterCount: _i(j['chapterCount']),
      sortOrder: _i(j['sortOrder']),
    );
  }
}

class Chapter {
  const Chapter({required this.id, required this.number, this.bookId, this.titleArabic, this.titleSomali, this.titleEnglish, this.hadithCount = 0});

  final String id;
  final String? bookId;
  final int number;
  final String? titleArabic;
  final String? titleSomali;
  final String? titleEnglish;
  final int hadithCount;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: _s(j['id']) ?? '',
        bookId: _s(j['bookId']),
        number: _i(j['number']),
        titleArabic: _s(j['titleArabic']),
        titleSomali: _s(j['titleSomali']),
        titleEnglish: _s(j['titleEnglish']),
        hadithCount: _i(j['hadithCount']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'number': number,
        'titleArabic': titleArabic,
        'titleSomali': titleSomali,
        'titleEnglish': titleEnglish,
        'hadithCount': hadithCount,
      };
}

class Category {
  const Category({required this.id, required this.slug, required this.nameSomali, this.nameArabic, this.nameEnglish, this.icon, this.hadithCount = 0});

  final String id;
  final String slug;
  final String nameSomali;
  final String? nameArabic;
  final String? nameEnglish;
  final String? icon;
  final int hadithCount;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _s(j['id']) ?? '',
        slug: _s(j['slug']) ?? '',
        nameSomali: _s(j['nameSomali']) ?? '',
        nameArabic: _s(j['nameArabic']),
        nameEnglish: _s(j['nameEnglish']),
        icon: _s(j['icon']),
        hadithCount: _i(j['hadithCount']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'slug': slug, 'nameSomali': nameSomali, 'nameArabic': nameArabic, 'nameEnglish': nameEnglish, 'icon': icon};
}

class Translation {
  const Translation({required this.id, required this.language, required this.text, this.translator, this.source});

  final String id;
  final String language;
  final String text;
  final String? translator;
  final String? source;

  factory Translation.fromJson(Map<String, dynamic> j) => Translation(
        id: _s(j['id']) ?? '',
        language: _s(j['language']) ?? '',
        text: _s(j['text']) ?? '',
        translator: _s(j['translator']),
        source: _s(j['source']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'language': language, 'text': text, 'translator': translator, 'source': source};
}

class Grading {
  const Grading({required this.id, required this.grade, this.gradedBy, this.source});

  final String id;
  final String grade;
  final String? gradedBy;
  final String? source;

  factory Grading.fromJson(Map<String, dynamic> j) =>
      Grading(id: _s(j['id']) ?? '', grade: _s(j['grade']) ?? '', gradedBy: _s(j['gradedBy']), source: _s(j['source']));

  Map<String, dynamic> toJson() => {'id': id, 'grade': grade, 'gradedBy': gradedBy, 'source': source};
}

class Explanation {
  const Explanation({required this.id, required this.language, required this.text, this.author, this.source});

  final String id;
  final String language;
  final String text;
  final String? author;
  final String? source;

  factory Explanation.fromJson(Map<String, dynamic> j) => Explanation(
        id: _s(j['id']) ?? '',
        language: _s(j['language']) ?? '',
        text: _s(j['text']) ?? '',
        author: _s(j['author']),
        source: _s(j['source']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'language': language, 'text': text, 'author': author, 'source': source};
}

class Hadith {
  const Hadith({
    required this.id,
    required this.hadithNumber,
    required this.arabicText,
    required this.book,
    this.narrator,
    this.sourceReference,
    this.chapter,
    this.translations = const [],
    this.gradings = const [],
    this.explanations = const [],
    this.categories = const [],
  });

  final String id;
  final String hadithNumber;
  final String arabicText;
  final String? narrator;
  final String? sourceReference;
  final BookSummary book;
  final Chapter? chapter;
  final List<Translation> translations;
  final List<Grading> gradings;
  final List<Explanation> explanations;
  final List<Category> categories;

  /// The Somali translation, if a published one exists.
  Translation? get somali => translations.where((t) => t.language == 'so').firstOrNull;

  factory Hadith.fromJson(Map<String, dynamic> j) => Hadith(
        id: _s(j['id']) ?? '',
        hadithNumber: _s(j['hadithNumber']) ?? '',
        arabicText: _s(j['arabicText']) ?? '',
        narrator: _s(j['narrator']),
        sourceReference: _s(j['sourceReference']),
        book: BookSummary.fromJson(Map<String, dynamic>.from((j['book'] as Map?) ?? const {})),
        chapter: j['chapter'] is Map ? Chapter.fromJson(Map<String, dynamic>.from(j['chapter'] as Map)) : null,
        translations: _list(j['translations']).map(Translation.fromJson).toList(),
        gradings: _list(j['gradings']).map(Grading.fromJson).toList(),
        explanations: _list(j['explanations']).map(Explanation.fromJson).toList(),
        categories: _list(j['categories']).map(Category.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hadithNumber': hadithNumber,
        'arabicText': arabicText,
        'narrator': narrator,
        'sourceReference': sourceReference,
        'book': book.toJson(),
        'chapter': chapter?.toJson(),
        'translations': translations.map((e) => e.toJson()).toList(),
        'gradings': gradings.map((e) => e.toJson()).toList(),
        'explanations': explanations.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
      };
}

class UserProfile {
  const UserProfile({required this.id, required this.email, required this.role, this.displayName, this.preferredLanguage});

  final String id;
  final String email;
  final String role;
  final String? displayName;
  final String? preferredLanguage;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final p = (j['profile'] as Map?) ?? const {};
    return UserProfile(
      id: _s(j['id']) ?? '',
      email: _s(j['email']) ?? '',
      role: _s(j['role']) ?? 'USER',
      displayName: _s(p['displayName']),
      preferredLanguage: _s(p['preferredLanguage']),
    );
  }
}

class AuthResult {
  const AuthResult({required this.user, required this.accessToken, required this.refreshToken});

  final UserProfile user;
  final String accessToken;
  final String refreshToken;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        user: UserProfile.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}

enum MemorizationStatus { newItem, learning, reviewing, memorized }

MemorizationStatus memorizationStatusFromApi(String? v) => switch (v) {
      'LEARNING' => MemorizationStatus.learning,
      'REVIEWING' => MemorizationStatus.reviewing,
      'MEMORIZED' => MemorizationStatus.memorized,
      _ => MemorizationStatus.newItem,
    };

class MemorizationItem {
  const MemorizationItem({
    required this.id,
    required this.hadithId,
    required this.status,
    required this.repetitions,
    required this.intervalDays,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.hadith,
  });

  final String id;
  final String hadithId;
  final MemorizationStatus status;
  final int repetitions;
  final int intervalDays;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final Hadith? hadith;

  bool get isDue => nextReviewAt == null || !nextReviewAt!.isAfter(DateTime.now());

  factory MemorizationItem.fromJson(Map<String, dynamic> j) => MemorizationItem(
        id: _s(j['id']) ?? '',
        hadithId: _s(j['hadithId']) ?? '',
        status: memorizationStatusFromApi(_s(j['status'])),
        repetitions: _i(j['repetitions']),
        intervalDays: _i(j['intervalDays']),
        nextReviewAt: DateTime.tryParse(_s(j['nextReviewAt']) ?? ''),
        lastReviewedAt: DateTime.tryParse(_s(j['lastReviewedAt']) ?? ''),
        hadith: j['hadith'] is Map ? Hadith.fromJson(Map<String, dynamic>.from(j['hadith'] as Map)) : null,
      );
}

/// The six canonical collections. Used only as a display fallback (names
/// only, no religious text) when the API cannot be reached.
const List<BookSummary> knownCollections = [
  BookSummary(id: 'sahih-bukhari', slug: 'sahih-bukhari', nameArabic: 'صحيح البخاري', nameSomali: 'Saxiix al-Bukhaari', nameEnglish: 'Sahih al-Bukhari'),
  BookSummary(id: 'sahih-muslim', slug: 'sahih-muslim', nameArabic: 'صحيح مسلم', nameSomali: 'Saxiix Muslim', nameEnglish: 'Sahih Muslim'),
  BookSummary(id: 'sunan-abi-dawud', slug: 'sunan-abi-dawud', nameArabic: 'سنن أبي داود', nameSomali: 'Sunan Abii Daawuud', nameEnglish: 'Sunan Abi Dawud'),
  BookSummary(id: 'jami-tirmidhi', slug: 'jami-tirmidhi', nameArabic: 'جامع الترمذي', nameSomali: 'Jaamic at-Tirmidi', nameEnglish: "Jami' at-Tirmidhi"),
  BookSummary(id: 'sunan-nasai', slug: 'sunan-nasai', nameArabic: 'سنن النسائي', nameSomali: "Sunan an-Nasaa'i", nameEnglish: "Sunan an-Nasa'i"),
  BookSummary(id: 'sunan-ibn-majah', slug: 'sunan-ibn-majah', nameArabic: 'سنن ابن ماجه', nameSomali: 'Sunan Ibn Maajah', nameEnglish: 'Sunan Ibn Majah'),
];
