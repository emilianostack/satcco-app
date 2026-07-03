import 'dart:async';
import 'api_client.dart';
import 'token_store.dart';
import 'usuario.dart';

class AuthService {
  static Usuario? _usuario;
  static final _controller = StreamController<Usuario?>.broadcast();

  static Usuario? get currentUser => _usuario;

  static Stream<Usuario?> get authStateChanges => _controller.stream;

  /// Lê o token salvo (se houver) e valida contra a API antes de emitir o
  /// primeiro estado. Chamado uma vez em `main()`, antes de `runApp`.
  static Future<void> bootstrap() async {
    final token = await TokenStore.ler();
    if (token == null) {
      _usuario = null;
      _controller.add(null);
      return;
    }
    try {
      final json = await ApiClient.get('/auth/me') as Map<String, dynamic>;
      _usuario = Usuario.fromJson(json);
    } catch (_) {
      await TokenStore.limpar();
      _usuario = null;
    }
    _controller.add(_usuario);
  }

  static Future<void> signIn(String email, String senha) async {
    final res = await ApiClient.post(
      '/auth/login',
      auth: false,
      body: {'email': email, 'senha': senha},
    ) as Map<String, dynamic>;
    await TokenStore.salvar(res['token'] as String);
    _usuario = Usuario.fromJson(res['usuario'] as Map<String, dynamic>);
    _controller.add(_usuario);
  }

  static Future<void> solicitarCodigo(String email) async {
    await ApiClient.post(
      '/auth/solicitar-codigo',
      auth: false,
      body: {'email': email},
    );
  }

  static Future<bool> verificarCodigo(String email, String codigo) async {
    final res = await ApiClient.post(
      '/auth/verificar-codigo',
      auth: false,
      body: {'email': email, 'codigo': codigo},
    ) as Map<String, dynamic>;
    return res['valido'] as bool;
  }

  static Future<void> createUser({
    required String nome,
    required String email,
    required String senha,
    required String tipo,
  }) async {
    final res = await ApiClient.post(
      '/auth/registro',
      auth: false,
      body: {'nome': nome, 'email': email, 'senha': senha, 'tipo': tipo},
    ) as Map<String, dynamic>;
    await TokenStore.salvar(res['token'] as String);
    _usuario = Usuario.fromJson(res['usuario'] as Map<String, dynamic>);
    _controller.add(_usuario);
  }

  static Future<void> signOut() async {
    await TokenStore.limpar();
    _usuario = null;
    _controller.add(null);
  }
}
