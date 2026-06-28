import 'package:flutter/material.dart';
import '../aluno/responder_formulario_page.dart';
import '../widgets/empty_state.dart';
import '../services/auth_service.dart';
import '../services/database/turmas_db.dart';
import '../services/database/respostas_db.dart';

class MinhasAvaliacoesPage extends StatefulWidget {
  const MinhasAvaliacoesPage({super.key});

  @override
  State<MinhasAvaliacoesPage> createState() => _MinhasAvaliacoesPageState();
}

class _MinhasAvaliacoesPageState extends State<MinhasAvaliacoesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<_FormItem>> _future;

  String get _professorId => AuthService.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<_FormItem>> _carregar() async {
    final turmasDocs = await TurmasDb.getTurmasConvidado(_professorId);
    if (turmasDocs.isEmpty) return [];

    final items = <_FormItem>[];
    for (final turmaDoc in turmasDocs) {
      final turmaData = turmaDoc.data() as Map<String, dynamic>;
      final turmaNome = (turmaData['nome'] as String?) ?? 'Turma';

      final formulariosSnap = await TurmasDb.getFormularios(turmaDoc.id);
      for (final formDoc in formulariosSnap.docs) {
        final data = formDoc.data() as Map<String, dynamic>;
        final titulo = (data['titulo'] as String?) ?? 'Sem título';
        final formularioId = formDoc.id;
        final jaRespondeu =
            await RespostasDb.jaRespondeuPorId('${formularioId}_$_professorId');
        items.add(_FormItem(
          id: formularioId,
          titulo: titulo,
          turmaNome: turmaNome,
          jaRespondeu: jaRespondeu,
        ));
      }
    }
    return items;
  }

  void _atualizar() => setState(() => _future = _carregar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Minhas Avaliações'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _atualizar,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pendentes'),
            Tab(text: 'Respondidos'),
          ],
        ),
      ),
      body: FutureBuilder<List<_FormItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            );
          }

          final todos = snapshot.data ?? [];
          final pendentes = todos.where((f) => !f.jaRespondeu).toList();
          final respondidos = todos.where((f) => f.jaRespondeu).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLista(pendentes, respondidos: false),
              _buildLista(respondidos, respondidos: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLista(List<_FormItem> items, {required bool respondidos}) {
    if (items.isEmpty) {
      return EmptyState(
        icon: respondidos
            ? Icons.check_circle_outline
            : Icons.rate_review_outlined,
        title: respondidos
            ? 'Nenhum formulário respondido ainda.'
            : 'Nenhuma avaliação pendente.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _atualizar(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildItem(items[i]),
      ),
    );
  }

  Widget _buildItem(_FormItem item) {
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
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  item.jaRespondeu ? Colors.teal.shade50 : const Color(0xFFE3F2FD),
              child: Icon(
                item.jaRespondeu
                    ? Icons.check_circle_outline
                    : Icons.assignment_outlined,
                color: item.jaRespondeu ? Colors.teal : Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.turmaNome,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            item.jaRespondeu
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      'Respondido',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResponderFormularioPage(
                            formularioId: item.id,
                            isProfessor: true,
                          ),
                        ),
                      );
                      _atualizar();
                    },
                    child: const Text('Responder'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FormItem {
  final String id;
  final String titulo;
  final String turmaNome;
  final bool jaRespondeu;

  const _FormItem({
    required this.id,
    required this.titulo,
    required this.turmaNome,
    required this.jaRespondeu,
  });
}
