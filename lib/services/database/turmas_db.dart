import 'package:cloud_firestore/cloud_firestore.dart';
import '../email/email_service.dart'; // Importação do serviço de e-mail

class TurmasDb {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection('turmas');

  static Stream<QuerySnapshot> watchByProfessor(String professorId) =>
      _col.where('professor_id', isEqualTo: professorId).snapshots();

  static Future<DocumentSnapshot> getTurma(String turmaId) =>
      _col.doc(turmaId).get();

  /// Verifica se já existe turma com este nome para o professor.
  /// Passa [excludeDocId] ao renomear para ignorar a própria turma.
  static Future<bool> nomeJaExiste(
      String professorId,
      String nome, {
        String? excludeDocId,
      }) async {
    final snap = await _col
        .where('professor_id', isEqualTo: professorId)
        .where('nome', isEqualTo: nome)
        .limit(2)
        .get();
    if (excludeDocId == null) return snap.docs.isNotEmpty;
    return snap.docs.any((d) => d.id != excludeDocId);
  }

  /// Verifica se algum formulário da turma já foi respondido.
  static Future<bool> hasRespostas(String turmaId) async {
    final formsSnap = await _col.doc(turmaId).collection('formularios').get();
    for (final formDoc in formsSnap.docs) {
      final respostasSnap = await _db
          .collection('respostas')
          .where('formulario_id', isEqualTo: formDoc.id)
          .limit(1)
          .get();
      if (respostasSnap.docs.isNotEmpty) return true;
    }
    return false;
  }

  static Future<void> create({
    required String nome,
    required String professorId,
  }) =>
      _col.add({
        'nome': nome,
        'professor_id': professorId,
        'criado_em': FieldValue.serverTimestamp(),
      });

  static Future<void> rename(String id, String nome) =>
      _col.doc(id).update({'nome': nome});

  /// Exclui a turma com suas subcoleções de alunos e formulários.
  static Future<void> delete(String turmaId) async {
    final turmaRef = _col.doc(turmaId);
    final batch = _db.batch();

    final alunosSnap = await turmaRef.collection('alunos').get();
    for (final d in alunosSnap.docs) {
      batch.delete(d.reference);
    }

    final formsSnap = await turmaRef.collection('formularios').get();
    for (final d in formsSnap.docs) {
      batch.delete(d.reference);
    }

    batch.delete(turmaRef);
    await batch.commit();
  }

  static Stream<QuerySnapshot> watchAlunos(String turmaId) =>
      _col.doc(turmaId).collection('alunos').snapshots();

  static Future<DocumentSnapshot> getAluno(String turmaId, String email) =>
      _col.doc(turmaId).collection('alunos').doc(email).get();

  static Future<void> toggleAtivoAluno(
      String turmaId, String docId, bool ativo) =>
      _col
          .doc(turmaId)
          .collection('alunos')
          .doc(docId)
          .update({'ativo': ativo});

  /// Convida aluno para a turma.
  /// Se o aluno já tiver conta, vincula direto; caso contrário, cria convite pendente.
  static Future<void> convidarAluno({
    required String turmaId,
    required String email,
    required String? alunoId,
    required String? alunoNome,
  }) async {
    final batch = _db.batch();
    final alunoRef =
    _col.doc(turmaId).collection('alunos').doc(email);

    batch.set(alunoRef, {
      'email': email,
      'aluno_id': alunoId,
      'nome': alunoNome,
      'convidado_em': FieldValue.serverTimestamp(),
    });

    if (alunoId != null) {
      batch.update(_db.collection('usuarios').doc(alunoId), {
        'turmas': FieldValue.arrayUnion([turmaId]),
      });
    } else {
      batch.set(
        _db.collection('convites').doc(email),
        {'turma_ids': FieldValue.arrayUnion([turmaId])},
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Rotina de disparo de e-mail ao salvar o convite no banco
    try {
      final turmaDoc = await getTurma(turmaId);
      final turmaNome = (turmaDoc.data() as Map<String, dynamic>?)?['nome'] as String? ?? 'uma turma';

      await EmailService.enviarEmailConvite(
        destinatario: email,
        turmaNome: turmaNome,
      );
    } catch (e) {
      print('Aviso: Falha ao enviar o e-mail de convite para $email. Erro: $e');
    }
  }

  /// Remove aluno da turma e (se tiver conta) retira o turmaId do seu doc.
  static Future<void> removerAluno({
    required String turmaId,
    required String docId,
    required String? alunoId,
  }) async {
    final batch = _db.batch();
    batch.delete(_col.doc(turmaId).collection('alunos').doc(docId));
    if (alunoId != null) {
      batch.update(_db.collection('usuarios').doc(alunoId), {
        'turmas': FieldValue.arrayRemove([turmaId]),
      });
    }
    await batch.commit();
  }

  static Stream<QuerySnapshot> watchFormularios(String turmaId) =>
      _col.doc(turmaId).collection('formularios').snapshots();

  static Future<QuerySnapshot> getFormularios(String turmaId) =>
      _col.doc(turmaId).collection('formularios').get();

  static Future<void> atribuirFormulario(
      String turmaId, String formularioId, String titulo) =>
      _col.doc(turmaId).collection('formularios').doc(formularioId).set({
        'titulo': titulo,
        'atribuido_em': FieldValue.serverTimestamp(),
      });

  static Future<void> removerFormulario(
      String turmaId, String formularioId) =>
      _col
          .doc(turmaId)
          .collection('formularios')
          .doc(formularioId)
          .delete();
}