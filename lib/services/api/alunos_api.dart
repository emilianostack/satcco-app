import '../api_client.dart';

class AlunosApi {
  /// Turmas do aluno logado, já com professor e formulários (respondido/nota) —
  /// substitui o fan-out N+1 que existia com Firestore.
  static Future<List<Map<String, dynamic>>> minhasTurmas() async {
    final res = await ApiClient.get('/alunos/me/turmas') as List;
    return res.cast<Map<String, dynamic>>();
  }
}
