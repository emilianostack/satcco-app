import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste o JWT entre execuções do app (login mantém a sessão após fechar).
class TokenStore {
  static const _key = 'jwt_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> salvar(String token) => _storage.write(key: _key, value: token);

  static Future<String?> ler() => _storage.read(key: _key);

  static Future<void> limpar() => _storage.delete(key: _key);
}
