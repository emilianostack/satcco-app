import '../api_client.dart';

class FormulariosApi {
  static Future<List<Map<String, dynamic>>> listar() async {
    final res = await ApiClient.get('/formularios') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> create(String titulo) async =>
      await ApiClient.post('/formularios', body: {'titulo': titulo}) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> update(String id, String titulo) async =>
      await ApiClient.patch('/formularios/$id', body: {'titulo': titulo}) as Map<String, dynamic>;

  /// Detalhe do formulário, incluindo `perguntas` (lista com pergunta_id, titulo,
  /// tipo, peso, ordem, opcoes, opcao_correta, resposta_correta — snapshot).
  /// Restrito ao professor dono (usado nas telas de edição/gestão).
  static Future<Map<String, dynamic>> getFormulario(String id) async =>
      await ApiClient.get('/formularios/$id') as Map<String, dynamic>;

  /// Mesmo detalhe acima, mas liberado para quem vai responder: aluno
  /// matriculado numa turma com o formulário atribuído, professor convidado,
  /// ou o próprio dono (modo teste).
  static Future<Map<String, dynamic>> getFormularioParaResponder(String id) async =>
      await ApiClient.get('/formularios/$id/responder') as Map<String, dynamic>;

  /// Substitui o conjunto de perguntas do formulário. [perguntas] é uma lista de
  /// mapas `{pergunta_id, peso, ordem}` — o backend congela (snapshot) o
  /// título/tipo/opções da pergunta neste momento.
  static Future<Map<String, dynamic>> salvarPerguntas(
    String formularioId,
    List<Map<String, dynamic>> perguntas,
  ) async =>
      await ApiClient.put('/formularios/$formularioId/perguntas', body: {'perguntas': perguntas})
          as Map<String, dynamic>;

  static Future<void> delete(String id) => ApiClient.delete('/formularios/$id');

  static Future<List<Map<String, dynamic>>> listarRespostas(String formularioId) async {
    final res = await ApiClient.get('/formularios/$formularioId/respostas') as List;
    return res.cast<Map<String, dynamic>>();
  }
}
