import '../api_client.dart';

class TurmasApi {
  static Future<List<Map<String, dynamic>>> listar() async {
    final res = await ApiClient.get('/turmas') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> listarConvidado() async {
    final res = await ApiClient.get('/turmas/convidado') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getTurma(String turmaId) async =>
      await ApiClient.get('/turmas/$turmaId') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> create(String nome) async =>
      await ApiClient.post('/turmas', body: {'nome': nome}) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> rename(String id, String nome) async =>
      await ApiClient.patch('/turmas/$id', body: {'nome': nome}) as Map<String, dynamic>;

  static Future<void> delete(String turmaId) => ApiClient.delete('/turmas/$turmaId');

  static Future<List<Map<String, dynamic>>> listarAlunos(String turmaId) async {
    final res = await ApiClient.get('/turmas/$turmaId/alunos') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> toggleAtivoAluno(
    String turmaId,
    String turmaAlunoId,
    bool ativo,
  ) async =>
      await ApiClient.patch('/turmas/$turmaId/alunos/$turmaAlunoId', body: {'ativo': ativo})
          as Map<String, dynamic>;

  /// Convida aluno para a turma. O backend já resolve se o email tem conta,
  /// grava o convite pendente e dispara o e-mail de convite.
  static Future<Map<String, dynamic>> convidarAluno({
    required String turmaId,
    required String email,
    String? nome,
  }) async =>
      await ApiClient.post(
        '/turmas/$turmaId/alunos',
        body: {'email': email, if (nome != null) 'nome': nome},
      ) as Map<String, dynamic>;

  /// Remove aluno da turma. [turmaAlunoId] é o `id` da própria linha (retornado
  /// por [listarAlunos]) — funciona tanto para convites aceitos quanto pendentes.
  static Future<void> removerAluno(String turmaId, String turmaAlunoId) =>
      ApiClient.delete('/turmas/$turmaId/alunos/$turmaAlunoId');

  static Future<List<Map<String, dynamic>>> listarProfessoresConvidados(String turmaId) async {
    final res = await ApiClient.get('/turmas/$turmaId/professores-convidados') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<void> convidarProfessor(String turmaId, String professorId) =>
      ApiClient.post('/turmas/$turmaId/professores-convidados', body: {'professorId': professorId});

  static Future<void> removerConviteProfessor(String turmaId, String professorId) =>
      ApiClient.delete('/turmas/$turmaId/professores-convidados/$professorId');

  static Future<List<Map<String, dynamic>>> listarFormularios(String turmaId) async {
    final res = await ApiClient.get('/turmas/$turmaId/formularios') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<void> atribuirFormulario(String turmaId, String formularioId) =>
      ApiClient.post('/turmas/$turmaId/formularios', body: {'formularioId': formularioId});

  static Future<void> removerFormulario(String turmaId, String formularioId) =>
      ApiClient.delete('/turmas/$turmaId/formularios/$formularioId');
}
