import 'package:flutter/material.dart';
import 'scanner_page.dart';
import 'responder_formulario_page.dart';
import '../services/auth_service.dart';
import '../services/database/usuarios_db.dart';
import '../services/database/turmas_db.dart';
import '../services/database/respostas_db.dart';

class HomeAlunoPage extends StatefulWidget {
  const HomeAlunoPage({super.key});

  @override
  State<HomeAlunoPage> createState() => _HomeAlunoPageState();
}

class _HomeAlunoPageState extends State<HomeAlunoPage> {
  late Future<List<_TurmaInfo>> _futureTurmas;
  String? _nomeAluno;

  @override
  void initState() {
    super.initState();
    _futureTurmas = _carregarTurmas();
  }

  Future<List<_TurmaInfo>> _carregarTurmas() async {
    final uid = AuthService.currentUser!.uid;
    final userEmail = (AuthService.currentUser?.email ?? '').toLowerCase();

    final usuarioDoc = await UsuariosDb.processarConvitesLogin(
      uid: uid,
      email: userEmail,
    );

    final userData = usuarioDoc.data() as Map<String, dynamic>?;

    final nome = userData?['nome'] as String?;
    if (mounted && nome != null) setState(() => _nomeAluno = nome);

    final turmaIds = List<String>.from(userData?['turmas'] as List? ?? []);

    if (turmaIds.isEmpty) return [];

    final respostasSnap = await RespostasDb.getByAluno(uid);
    final respondidoIds = <String>{};
    final notasMap = <String, double?>{};
    for (final doc in respostasSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fId = data['formulario_id'] as String? ?? '';
      if (fId.isNotEmpty) {
        respondidoIds.add(fId);
        notasMap[fId] = (data['nota'] as num?)?.toDouble();
      }
    }

    final turmas = <_TurmaInfo>[];

    await Future.wait(
      turmaIds.map((turmaId) async {
        final turmaDoc = await TurmasDb.getTurma(turmaId);
        if (!turmaDoc.exists) return;

        final turmaData = turmaDoc.data() as Map<String, dynamic>?;
        final turmaNome = turmaData?['nome'] as String? ?? 'Turma';
        final professorId = turmaData?['professor_id'] as String? ?? '';

        if (userEmail.isNotEmpty) {
          final alunoDoc = await TurmasDb.getAluno(turmaId, userEmail);
          if (alunoDoc.exists &&
              (alunoDoc.data() as Map<String, dynamic>?)?['ativo'] == false) {
            return;
          }
        }

        String nomeProfessor = '';
        if (professorId.isNotEmpty) {
          final profDoc = await UsuariosDb.getUsuario(professorId);
          nomeProfessor =
              (profDoc.data() as Map<String, dynamic>?)?['nome'] as String? ??
                  '';
        }

        final formsSnap = await TurmasDb.getFormularios(turmaId);

        final forms = formsSnap.docs.map((f) {
          final data = f.data() as Map<String, dynamic>;
          return _FormInfo(
            id: f.id,
            titulo: (data['titulo'] as String?) ?? 'Avaliação',
            respondido: respondidoIds.contains(f.id),
            nota: notasMap[f.id],
          );
        }).toList();

        turmas.add(_TurmaInfo(
          id: turmaId,
          nome: turmaNome,
          nomeProfessor: nomeProfessor,
          forms: forms,
        ));
      }),
    );

    turmas.sort((a, b) => a.nome.compareTo(b.nome));
    return turmas;
  }

  void _atualizar() {
    setState(() => _futureTurmas = _carregarTurmas());
  }

  @override
  Widget build(BuildContext context) {
    final raw = _nomeAluno ?? AuthService.currentUser?.email ?? 'Aluno';
    final displayName = raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1).toLowerCase();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text('SATCCO App'),
          centerTitle: true,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _atualizar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            ),
            IconButton(
              onPressed: AuthService.signOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 24),
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Olá,',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ScannerPage()),
                      ).then((_) => _atualizar());
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 24, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Escanear QR Code',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Colors.green,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green,
                indicatorWeight: 3,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(text: 'Pendentes'),
                  Tab(text: 'Respondidos'),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<List<_TurmaInfo>>(
                future: _futureTurmas,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Erro ao carregar: ${snapshot.error}',
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final turmas = snapshot.data ?? [];

                  if (turmas.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.school_outlined,
                                color: Colors.grey, size: 28),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Ainda não pertences a nenhuma turma.\nAguarda o convite do professor.',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return TabBarView(
                    children: [
                      _buildTab(turmas, pendentes: true),
                      _buildTab(turmas, pendentes: false),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(List<_TurmaInfo> turmas, {required bool pendentes}) {
    final filtered = turmas
        .map((t) => _TurmaInfo(
              id: t.id,
              nome: t.nome,
              nomeProfessor: t.nomeProfessor,
              forms: t.forms
                  .where((f) => pendentes ? !f.respondido : f.respondido)
                  .toList(),
            ))
        .where((t) => t.forms.isNotEmpty)
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pendentes
                  ? Icons.check_circle_outline
                  : Icons.assignment_outlined,
              size: 52,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              pendentes
                  ? 'Nenhuma avaliação pendente.'
                  : 'Nenhuma avaliação respondida ainda.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _atualizar(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _buildTurmaSection(filtered[i]),
      ),
    );
  }

  Widget _buildTurmaSection(_TurmaInfo turma) {
    final label = turma.nomeProfessor.isNotEmpty
        ? '${turma.nome} — ${turma.nomeProfessor}'
        : turma.nome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school, size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...turma.forms.map((f) => _buildFormCard(f)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormCard(_FormInfo form) {
    final isDone = form.respondido;

    return GestureDetector(
      onTap: isDone
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ResponderFormularioPage(formularioId: form.id),
                ),
              ).then((_) => _atualizar()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isDone
              ? Border.all(color: Colors.green.shade200, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDone
                    ? Icons.check_circle_outline
                    : Icons.assignment_outlined,
                color: isDone ? Colors.green : Colors.orange.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                form.titulo,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDone ? Colors.black54 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            isDone ? _buildNotaBadge(form.nota) : _buildPendenteBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotaBadge(double? nota) {
    if (nota == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: const Text(
          'Concluído',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }

    final color = nota >= 7
        ? Colors.green
        : nota >= 5
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${nota.toStringAsFixed(1)} / 10',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPendenteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Text(
        'Pendente',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _TurmaInfo {
  final String id;
  final String nome;
  final String nomeProfessor;
  final List<_FormInfo> forms;

  const _TurmaInfo({
    required this.id,
    required this.nome,
    required this.nomeProfessor,
    required this.forms,
  });
}

class _FormInfo {
  final String id;
  final String titulo;
  final bool respondido;
  final double? nota;

  const _FormInfo({
    required this.id,
    required this.titulo,
    required this.respondido,
    this.nota,
  });
}
