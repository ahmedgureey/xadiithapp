import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/models.dart';

/// Authentication and the signed-in user's private data.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<bool> hasSession() async => (await _tokens.readRefreshToken()) != null;

  Future<UserProfile> register({required String email, required String password, required String displayName}) =>
      _authenticate('/auth/register', {'email': email, 'password': password, 'displayName': displayName});

  Future<UserProfile> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  Future<UserProfile> _authenticate(String path, Map<String, dynamic> body) async {
    final res = await _api.post(path, body: body, auth: false);
    final result = AuthResult.fromJson(Map<String, dynamic>.from(res['data'] as Map));
    await _tokens.save(accessToken: result.accessToken, refreshToken: result.refreshToken);
    return result.user;
  }

  Future<UserProfile> me() async => UserProfile.fromJson(Map<String, dynamic>.from((await _api.get('/me'))['data'] as Map));

  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    try {
      if (refresh != null) await _api.post('/auth/logout', body: {'refreshToken': refresh}, auth: false);
    } catch (_) {
      // Logging out locally must always succeed even if the server is down.
    } finally {
      await _tokens.clear();
    }
  }
}

class BookmarkRepository {
  BookmarkRepository(this._api);

  final ApiClient _api;

  Future<List<Hadith>> all() async {
    final res = await _api.get('/bookmarks', query: {'limit': 100});
    return Paginated.fromJson(res, (j) => j)
        .items
        .where((j) => j['hadith'] is Map)
        .map((j) => Hadith.fromJson(Map<String, dynamic>.from(j['hadith'] as Map)))
        .toList();
  }

  Future<void> add(String hadithId) => _api.post('/bookmarks', body: {'hadithId': hadithId});

  /// The API deletes by hadith id, not bookmark id.
  Future<void> remove(String hadithId) => _api.delete('/bookmarks/$hadithId');
}

class MemorizationRepository {
  MemorizationRepository(this._api);

  final ApiClient _api;

  Future<List<MemorizationItem>> all() async =>
      Paginated.fromJson(await _api.get('/memorization', query: {'limit': 100}), MemorizationItem.fromJson).items;

  Future<void> add(String hadithId) => _api.post('/memorization', body: {'hadithId': hadithId});

  /// [quality] is the SM-2 self-assessment score from 0 (forgot) to 5 (perfect).
  Future<void> review(String id, int quality) => _api.patch('/memorization/$id', body: {'quality': quality});

  Future<void> remove(String id) => _api.delete('/memorization/$id');
}

class ReadingHistoryRepository {
  ReadingHistoryRepository(this._api);

  final ApiClient _api;

  Future<void> record(String hadithId) => _api.post('/reading-history', body: {'hadithId': hadithId});
}
