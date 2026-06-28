import 'package:cloud_firestore/cloud_firestore.dart';

class FormulariosDb {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection('formularios');

  static Stream<QuerySnapshot> watchByProfessor(String professorId) =>
      _col
          .where('professor_id', isEqualTo: professorId)
          .snapshots();

  static Future<List<DocumentSnapshot>> getByProfessor(
      String professorId) async {
    final snap = await _col
        .where('professor_id', isEqualTo: professorId)
        .get();
    return snap.docs;
  }

  static Future<DocumentSnapshot> getFormulario(String id) =>
      _col.doc(id).get();

  /// Retorna as perguntas do formulário ordenadas por 'ordem'.
  static Future<List<Map<String, dynamic>>> getPerguntas(
      String formularioId) async {
    final snap = await _col
        .doc(formularioId)
        .collection('perguntas')
        .orderBy('ordem')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Retorna o QuerySnapshot das perguntas (para operações de batch).
  static Future<QuerySnapshot> getPerguntasSnap(String formularioId) =>
      _col.doc(formularioId).collection('perguntas').get();

  /// Cria ou atualiza um formulário junto com a subcoleção de perguntas.
  ///
  /// [formularioId] nulo → cria novo; não nulo → edita existente.
  /// [perguntas] → lista de mapas já formatados com todos os campos necessários.
  static Future<void> salvar({
    String? formularioId,
    required String titulo,
    required String professorId,
    required List<Map<String, dynamic>> perguntas,
  }) async {
    final batch = _db.batch();
    final DocumentReference formRef;

    if (formularioId == null) {
      formRef = _col.doc();
      batch.set(formRef, {
        'titulo': titulo,
        'professor_id': professorId,
        'total_perguntas': perguntas.length,
        'criado_em': FieldValue.serverTimestamp(),
      });
    } else {
      formRef = _col.doc(formularioId);
      batch.update(formRef, {
        'titulo': titulo,
        'total_perguntas': perguntas.length,
      });

      // Sincroniza o novo título com os formulários já atribuídos às turmas
      final turmasSnap = await _db
          .collection('turmas')
          .where('professor_id', isEqualTo: professorId)
          .get();

      for (final turma in turmasSnap.docs) {
        final formTurmaRef = turma.reference.collection('formularios').doc(formularioId);
        final formTurmaSnap = await formTurmaRef.get();
        if (formTurmaSnap.exists) {
          batch.update(formTurmaRef, {'titulo': titulo});
        }
      }

      final existentes = await formRef.collection('perguntas').get();
      for (final doc in existentes.docs) {
        batch.delete(doc.reference);
      }
    }

    for (int i = 0; i < perguntas.length; i++) {
      final p = perguntas[i];
      batch.set(
        formRef.collection('perguntas').doc(p['pergunta_id'] as String),
        {...p, 'ordem': i},
      );
    }

    await batch.commit();
  }

  /// Exclui o formulário e sua subcoleção de perguntas.
  static Future<void> delete(String id) async {
    final formRef = _col.doc(id);
    final pergsSnap = await formRef.collection('perguntas').get();
    final batch = _db.batch();
    for (final doc in pergsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(formRef);
    await batch.commit();
  }

  /// Verifica se o professor já tem um formulário com este título.
  /// [excludeId] é passado na edição para ignorar o próprio documento.
  static Future<bool> tituloJaExiste({
    required String professorId,
    required String titulo,
    String? excludeId,
  }) async {
    final snap = await _col
        .where('professor_id', isEqualTo: professorId)
        .where('titulo', isEqualTo: titulo)
        .limit(2)
        .get();
    if (snap.docs.isEmpty) return false;
    if (excludeId != null) {
      return snap.docs.any((d) => d.id != excludeId);
    }
    return true;
  }

  /// Verifica se algum aluno já respondeu este formulário.
  static Future<bool> hasRespostas(String formularioId) async {
    final snap = await _db
        .collection('respostas')
        .where('formulario_id', isEqualTo: formularioId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Retorna o título do formulário que contém a pergunta, ou null se não encontrada.
  static Future<String?> formularioQueUsaPergunta(
      String professorId, String perguntaId) async {
    final forms =
    await _col.where('professor_id', isEqualTo: professorId).get();
    for (final form in forms.docs) {
      final snap =
      await form.reference.collection('perguntas').doc(perguntaId).get();
      if (snap.exists) {
        return (form.data() as Map<String, dynamic>)['titulo'] as String? ??
            'um formulário';
      }
    }
    return null;
  }

}