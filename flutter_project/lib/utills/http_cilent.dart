import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HttpClient {
  static final http.Client client = http.Client();
  static const FlutterSecureStorage storage = FlutterSecureStorage();

  // Adds JWT header automatically
  static Future<Map<String, String>> headers() async {
    final token = await storage.read(key: 'token');   // อ่าน token

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',  
    };
  }

  static Future<http.Response> get(Uri url) async {
    return client.get(url, headers: await headers());
  }

  static Future<http.Response> post(Uri url, {Object? body}) async {
    return client.post(url, headers: await headers(), body: body);
  }

  static Future<http.Response> put(Uri url, {Object? body}) async {
    return client.put(url, headers: await headers(), body: body);
  }

  static Future<http.Response> delete(Uri url) async {
    return client.delete(url, headers: await headers());
  }
}
