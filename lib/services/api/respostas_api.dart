import '../api_client.dart';

class RespostasApi {
  /// Submete respostas de um formulário. [respostas] é uma lista de mapas
  /// `{perguntaId, valor}` (valor sempre como String — o backend converte
  /// conforme o tipo da pergunta ao calcular a nota).
  ///
  /// Informe [sessaoToken] no fluxo normal (QR Code, permite resposta anônima)
  /// ou [formularioId] no fluxo direto sem QR (exige usuário autenticado — usado
  /// por professores convidados respondendo pela lista "Minhas Avaliações").
  static Future<Map<String, dynamic>> submit({
    String? sessaoToken,
    String? formularioId,
    String? alunoNome,
    String? alunoEmail,
    required List<Map<String, dynamic>> respostas,
  }) async =>
      await ApiClient.post('/respostas', body: {
        if (sessaoToken != null) 'sessaoToken': sessaoToken,
        if (formularioId != null) 'formularioId': formularioId,
        if (alunoNome != null) 'alunoNome': alunoNome,
        if (alunoEmail != null) 'alunoEmail': alunoEmail,
        'respostas': respostas,
      }) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getRespostaById(String id) async =>
      await ApiClient.get('/respostas/$id') as Map<String, dynamic>;

  /// Retorna a resposta do usuário logado para este formulário, ou null se
  /// ele ainda não respondeu.
  static Future<Map<String, dynamic>?> minhaPorFormulario(String formularioId) async {
    try {
      return await ApiClient.get('/respostas/me?formularioId=$formularioId') as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Todas as respostas do usuário logado.
  static Future<List<Map<String, dynamic>>> minhas() async {
    final res = await ApiClient.get('/respostas/minhas') as List;
    return res.cast<Map<String, dynamic>>();
  }
}
