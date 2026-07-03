import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'token_store.dart';

/// Erro retornado pela API (formato `{ "error": "..." }`, opcionalmente com `detalhes`).
class ApiException implements Exception {
  final int status;
  final String message;

  ApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// Cliente HTTP único para toda a API REST do SATCCO — monta a URL, injeta o
/// JWT salvo (quando houver) e normaliza erros em [ApiException].
class ApiClient {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000/api/v1';

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    // Evita que o iOS (NSURLCache) sirva uma resposta em cache para o mesmo
    // GET repetido logo após um POST/PATCH/DELETE — a API é sempre dinâmica.
    final headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
    };
    if (auth) {
      final token = await TokenStore.ler();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _decode(http.Response res) {
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static dynamic _tratar(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    final corpo = _decode(res);
    final mensagem =
        (corpo is Map && corpo['error'] is String) ? corpo['error'] as String : 'erro inesperado';
    throw ApiException(res.statusCode, mensagem);
  }

  static Future<dynamic> get(String path, {bool auth = true}) async {
    final res = await http.get(Uri.parse('$_baseUrl$path'), headers: await _headers(auth: auth));
    return _tratar(res);
  }

  static Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _tratar(res);
  }

  static Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    final res = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _tratar(res);
  }

  static Future<dynamic> patch(String path, {Object? body, bool auth = true}) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _tratar(res);
  }

  static Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await http.delete(Uri.parse('$_baseUrl$path'), headers: await _headers(auth: auth));
    return _tratar(res);
  }
}
