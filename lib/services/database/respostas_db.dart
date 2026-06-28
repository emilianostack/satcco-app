import 'package:cloud_firestore/cloud_firestore.dart';

class RespostasDb {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection('respostas');

  /// Verifica se existe ao menos uma resposta para este formulário.
  static Future<bool> hasRespostas(String formularioId) async {
    final snap = await _col
        .where('formulario_id', isEqualTo: formularioId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Verifica pelo ID determinístico se o aluno já respondeu.
  static Future<bool> jaRespondeuPorId(String docId) async {
    final doc = await _col.doc(docId).get();
    return doc.exists;
  }

  /// Verifica por query se o aluno já respondeu este formulário
  /// (útil para detectar respostas feitas via QR em acessos diretos).
  static Future<bool> jaRespondeuPorQuery({
    required String formularioId,
    required String alunoId,
  }) async {
    final snap = await _col
        .where('formulario_id', isEqualTo: formularioId)
        .where('aluno_id', isEqualTo: alunoId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Retorna todas as respostas de um aluno.
  static Future<QuerySnapshot> getByAluno(String alunoId) =>
      _col.where('aluno_id', isEqualTo: alunoId).get();

  /// Retorna todas as respostas de um formulário.
  static Future<QuerySnapshot> getByFormulario(String formularioId) =>
      _col.where('formulario_id', isEqualTo: formularioId).get();

  /// Busca respostas em lotes de 30 (limite do Firestore whereIn).
  /// Retorna a lista de todos os documentos encontrados.
  static Future<List<DocumentSnapshot>> getByFormularioIds(
    List<String> ids,
  ) async {
    final docs = <DocumentSnapshot>[];
    for (int i = 0; i < ids.length; i += 30) {
      final batch = ids.sublist(i, (i + 30) > ids.length ? ids.length : i + 30);
      final snap = await _col.where('formulario_id', whereIn: batch).get();
      docs.addAll(snap.docs);
    }
    return docs;
  }

  /// Retorna o documento de resposta pelo ID determinístico.
  static Future<DocumentSnapshot> getRespostaById(String docId) =>
      _col.doc(docId).get();

  /// Salva a resposta com ID determinístico para evitar duplicatas.
  /// [isProfessor] marca respostas enviadas pelo próprio professor do formulário.
  static Future<void> submit({
    required String docId,
    String? sessaoId,
    required String formularioId,
    required String alunoId,
    required String alunoNome,
    required String? alunoEmail,
    required List<Map<String, dynamic>> respostas,
    double? nota,
    bool isProfessor = false,
  }) => _col.doc(docId).set({
    'sessao_id': ?sessaoId,
    'formulario_id': formularioId,
    'aluno_id': alunoId,
    'aluno_nome': alunoNome,
    'aluno_email': alunoEmail,
    'respostas': respostas,
    'nota': ?nota,
    'respondido_em': FieldValue.serverTimestamp(),
    if (isProfessor) 'is_professor': true,
  });
}
