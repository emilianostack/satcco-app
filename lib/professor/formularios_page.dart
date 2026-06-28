import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'criar_formulario_page.dart';
import '../widgets/empty_state.dart';
import '../services/auth_service.dart';
import '../services/database/formularios_db.dart';
import '../aluno/responder_formulario_page.dart';

class FormulariosPage extends StatelessWidget {
  const FormulariosPage({super.key});

  String get _professorId => AuthService.currentUser!.uid;

  Future<void> _confirmarDelecao(
      BuildContext context, String docId, String titulo) async {
    if (await FormulariosDb.hasRespostas(docId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não é possível remover "$titulo": existem avaliações respondidas por alunos.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover formulário'),
        content: Text(
            'Deseja remover "$titulo"?\nTodas as perguntas vinculadas serão desassociadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar == true) await FormulariosDb.delete(docId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Formulários de Avaliação'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FormulariosDb.watchByProfessor(_professorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final rawDocs = snapshot.data?.docs ?? [];
          final docs = [...rawDocs]..sort((a, b) {
              final aTs = ((a.data() as Map)['criado_em'] as Timestamp?)
                  ?.microsecondsSinceEpoch ?? 0;
              final bTs = ((b.data() as Map)['criado_em'] as Timestamp?)
                  ?.microsecondsSinceEpoch ?? 0;
              return aTs.compareTo(bTs);
            });

          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Nenhum formulário ainda.',
              subtitle: 'Toque em + para criar o primeiro.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final titulo = data['titulo'] ?? 'Sem título';
              final totalPerguntas = data['total_perguntas'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.assignment_outlined,
                                color: Colors.blueAccent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                                Text(
                                  '$totalPerguntas pergunta${totalPerguntas == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.science_outlined,
                                color: Colors.orange),
                            tooltip: 'Testar',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ResponderFormularioPage(
                                    formularioId: doc.id,
                                    modoTeste: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.blueAccent),
                            tooltip: 'Editar',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CriarFormularioPage(
                                    formularioId: doc.id,
                                    tituloInicial: titulo,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            tooltip: 'Remover',
                            onPressed: () =>
                                _confirmarDelecao(context, doc.id, titulo),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CriarFormularioPage(),
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Formulário'),
      ),
    );
  }
}

