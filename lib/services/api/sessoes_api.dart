import '../api_client.dart';

class SessoesApi {
  /// Abre uma sessão QR para o formulário e retorna o mapa da sessão
  /// (inclui `token`, que é o valor codificado no QR Code).
  static Future<Map<String, dynamic>> criar({
    required String formularioId,
    String? turmaId,
  }) async =>
      await ApiClient.post('/sessoes-qrcode', body: {
        'formularioId': formularioId,
        if (turmaId != null) 'turmaId': turmaId,
      }) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> encerrar(String sessaoId) async =>
      await ApiClient.post('/sessoes-qrcode/$sessaoId/encerrar') as Map<String, dynamic>;

  /// Consulta pública (sem auth) usada ao ler o QR: retorna
  /// `{sessao, formulario, perguntas}`.
  static Future<Map<String, dynamic>> consultarPorToken(String token) async =>
      await ApiClient.get('/sessoes-qrcode/$token', auth: false) as Map<String, dynamic>;
}
