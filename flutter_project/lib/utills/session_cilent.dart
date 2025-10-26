import 'package:http/http.dart' as http;

/// A singleton HTTP client that automatically manages session cookies
/// for all request types (GET, POST, PUT, DELETE, PATCH).
class SessionHttpClient {
  static final SessionHttpClient _instance = SessionHttpClient._internal();
  factory SessionHttpClient() => _instance;
  SessionHttpClient._internal();

  final http.Client _client = http.Client();
  Map<String, String> _headers = {"Content-Type": "application/json"};

  /// Update cookie from response header if present.
  void _updateCookie(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      final cookie = rawCookie.split(';')[0];
      _headers['cookie'] = cookie;
    }
  }

  /// Merge extra headers if provided.
  Map<String, String> _mergeHeaders([Map<String, String>? extra]) {
    if (extra == null) return _headers;
    final merged = Map<String, String>.from(_headers);
    merged.addAll(extra);
    return merged;
  }

  /// POST request with session persistence
  Future<http.Response> post(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response =
        await _client.post(url, headers: _mergeHeaders(headers), body: body);
    _updateCookie(response);
    return response;
  }

  /// GET request with session persistence
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(url, headers: _mergeHeaders(headers));
    _updateCookie(response);
    return response;
  }

  /// PUT request with session persistence
  Future<http.Response> put(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response =
        await _client.put(url, headers: _mergeHeaders(headers), body: body);
    _updateCookie(response);
    return response;
  }

  /// DELETE request with session persistence
  Future<http.Response> delete(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response =
        await _client.delete(url, headers: _mergeHeaders(headers), body: body);
    _updateCookie(response);
    return response;
  }

  /// PATCH request with session persistence
  Future<http.Response> patch(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response =
        await _client.patch(url, headers: _mergeHeaders(headers), body: body);
    _updateCookie(response);
    return response;
  }

  /// Clear stored session cookies (used on logout)
  void clearCookies() {
    _headers.remove('cookie');
  }

  /// Close client connection
  void close() {
    _client.close();
  }
}
