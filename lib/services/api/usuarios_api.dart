import '../api_client.dart';

class UsuariosApi {
  /// Retorna o usuário com este email, ou null se não existir conta.
  static Future<Map<String, dynamic>?> buscarPorEmail(String email) async {
    try {
      return await ApiClient.get('/usuarios/buscar?email=${Uri.encodeQueryComponent(email)}')
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }
}
