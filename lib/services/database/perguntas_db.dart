import 'package:cloud_firestore/cloud_firestore.dart';

class PerguntasDb {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection('perguntas');

  static Stream<QuerySnapshot> watchByProfessor(String professorId) =>
      _col
          .where('professor_id', isEqualTo: professorId)
          .orderBy('criado_em', descending: true) // Ordenação adicionada aqui
          .snapshots();

  static Future<List<DocumentSnapshot>> getByProfessor(
      String professorId) async {
    final snap = await _col
        .where('professor_id', isEqualTo: professorId)
        .orderBy('criado_em', descending: true) // Ordenação adicionada aqui
        .get();
    return snap.docs;
  }

  /// Cria uma nova pergunta.
  static Future<void> add(
      String professorId, Map<String, dynamic> dados) =>
      _col.add({
        ...dados,
        'professor_id': professorId,
        'criado_em': FieldValue.serverTimestamp(),
      });

  /// Atualiza uma pergunta existente.
  /// [dados] pode incluir FieldValue.delete() para remover campos obsoletos.
  static Future<void> update(String id, Map<String, dynamic> dados) =>
      _col.doc(id).update(dados);

  static Future<void> delete(String id) => _col.doc(id).delete();
}