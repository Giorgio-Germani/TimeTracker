import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin Dio wrapper around the TimeTracker backend (`/api/v1/*`).
class Api {
  Api._(this._dio, this.baseUrl);
  final Dio _dio;
  final String baseUrl;

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'tt_token';
  static const _kBase = 'tt_base_url';

  static Future<String?> savedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBase);
  }

  static Future<Api?> restore() async {
    final base = await savedBaseUrl();
    final token = await _storage.read(key: _kToken);
    if (base == null || base.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return Api._(_dioFor(base), base).._dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static Dio _dioFor(String base) => Dio(BaseOptions(
        baseUrl: base.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ));

  /// POST /auth/login — tolerant to several token field names.
  ///
  /// If [base] has no scheme, https:// is tried first and http:// is the
  /// fallback, so users can just type `myserver.local:8080`.
  static Future<Api> login(String base, String username, String password) async {
    final clean = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) throw 'Please enter a server address.';
    final candidates = clean.startsWith('http://') || clean.startsWith('https://')
        ? [clean]
        : ['https://$clean', 'http://$clean'];

    Object? lastError;
    for (final candidate in candidates) {
      final dio = _dioFor(candidate);
      try {
        final res = await dio.post('/api/v1/auth/login',
            data: {'username': username, 'password': password});
        final data = res.data;
        final token = data is Map
            ? (data['token'] ?? data['access_token'] ?? data['api_key'] ?? '') as String
            : '';
        if (token.isEmpty) throw 'Login succeeded but no token was returned.';
        await _storage.write(key: _kToken, value: token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kBase, candidate);
        return Api._(dio, candidate)
          .._dio.options.headers['Authorization'] = 'Bearer $token';
      } on DioException catch (e) {
        lastError = e;
        // Wrong credentials would be wrong on every scheme — stop early.
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) throw _friendly(e);
        // Otherwise (unreachable / TLS error) try the next candidate.
      }
    }
    throw lastError is DioException ? _friendly(lastError) : 'Login failed.';
  }

  static String _friendly(DioException e) {
    if (e.type == .connectionError || e.type == .connectionTimeout) {
      return 'Could not reach the server. Check the address and your connection.';
    }
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return 'Wrong username or password.';
    if (code != null && code >= 500) return 'Server error ($code). Try again later.';
    return 'Login failed: ${e.message ?? 'unknown error'}';
  }

  Future<void> logout() async {
    await _storage.delete(key: _kToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBase);
  }

  void close() => _dio.close();

  // ---- Generic tolerant GET returning List<Map<String, dynamic>> ----
  Future<List<Map<String, dynamic>>> getList(String path,
      {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    final d = res.data;
    List raw;
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      raw = (d['items'] ?? d['data'] ?? d['results'] ?? d['time-entries'] ??
              d['time_entries'] ?? d['projects'] ?? d['tasks'] ?? []) as List;
    } else {
      raw = [];
    }
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<Map<String, dynamic>> getMap(String path,
      {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await _dio.put(path, data: body);
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  Future<void> delete(String path) async => _dio.delete(path);

  /// Validates the stored token; throws on 401.
  Future<void> validate() async {
    try {
      await _dio.get('/api/v1/timer/status');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw 'Session expired';
      }
      // Server reachable but endpoint hiccup — allow offline start.
    }
  }
}
