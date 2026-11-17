import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

/// Read-only access to public Hadith content.
class HadithRepository {
  HadithRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Book>> books({int page = 1}) async =>
      Paginated.fromJson(await _api.get('/books', query: {'page': page, 'limit': 50}), Book.fromJson);

  Future<Book> book(String idOrSlug) async =>
      Book.fromJson(Map<String, dynamic>.from((await _api.get('/books/$idOrSlug'))['data'] as Map));

  Future<Paginated<Chapter>> chapters(String bookIdOrSlug, {int page = 1}) async => Paginated.fromJson(
        await _api.get('/books/$bookIdOrSlug/chapters', query: {'page': page, 'limit': 100}),
        Chapter.fromJson,
      );

  Future<Paginated<Hadith>> hadiths({String? bookId, String? chapterId, String? categoryId, int page = 1}) async =>
      Paginated.fromJson(
        await _api.get('/hadiths', query: {
          'bookId': bookId,
          'chapterId': chapterId,
          'categoryId': categoryId,
          'page': page,
          'limit': AppConfig.pageSize,
        }),
        Hadith.fromJson,
      );

  Future<Hadith> hadith(String id) async =>
      Hadith.fromJson(Map<String, dynamic>.from((await _api.get('/hadiths/$id'))['data'] as Map));

  Future<Paginated<Category>> categories() async =>
      Paginated.fromJson(await _api.get('/categories', query: {'limit': 100}), Category.fromJson);

  Future<Paginated<Hadith>> search(String q, {String? bookId, String? categoryId, int page = 1}) async =>
      Paginated.fromJson(
        await _api.get('/search', query: {
          'q': q.trim(),
          'bookId': bookId,
          'categoryId': categoryId,
          'page': page,
          'limit': AppConfig.pageSize,
        }),
        Hadith.fromJson,
      );

  Future<Hadith?> hadithOfTheDay() async {
    final data = (await _api.get('/hadith-of-the-day'))['data'];
    return data is Map ? Hadith.fromJson(Map<String, dynamic>.from(data)) : null;
  }
}
