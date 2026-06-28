import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qr_code_page.dart';
import '../widgets/empty_state.dart';
import '../services/auth_service.dart';
import '../services/database/turmas_db.dart';
import '../services/database/formularios_db.dart';
import '../services/database/respostas_db.dart';
import '../services/database/usuarios_db.dart';
import '../services/pdf_service.dart';
import '../services/email/email_service.dart';

class TurmaDetailPage extends StatefulWidget {
  final String turmaId;
  final String turmaNome;

  const TurmaDetailPage(
      {super.key, required this.turmaId, required this.turmaNome});

  @override
  State<TurmaDetailPage> createState() => _TurmaDetailPageState();
}

class _TurmaDetailPageState extends State<TurmaDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String get _professorId => AuthService.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _convidar() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConvidarSheet(
        turmaId: widget.turmaId,
        turmaNome: widget.turmaNome,
        professorDonoId: _professorId,
      ),
    );
  }

  Future<void> _atribuirFormulario() async {
    final formulariosSnap =
        await FormulariosDb.getByProfessor(_professorId);

    if (!mounted) return;

    if (formulariosSnap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não tem formulários criados.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final assignedSnap = await TurmasDb.getFormularios(widget.turmaId);
    if (!mounted) return;

    final assignedIds = assignedSnap.docs.map((d) => d.id).toSet();
    final available =
        formulariosSnap.where((d) => !assignedIds.contains(d.id)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Atribuir Formulário',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Todos os formulários já foram atribuídos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: available.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) {
                    final doc = available[i];
                    final titulo = (doc.data() as Map<String, dynamic>)[
                            'titulo'] as String? ??
                        'Sem título';
                    return ListTile(
                      leading: const Icon(Icons.assignment_outlined,
                          color: Colors.blueAccent),
                      title: Text(titulo),
                      onTap: () async {
                        await TurmasDb.atribuirFormulario(
                            widget.turmaId, doc.id, titulo);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.turmaNome),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Alunos'),
            Tab(icon: Icon(Icons.assignment_outlined), text: 'Formulários'),
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Notas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AlunosTab(turmaId: widget.turmaId, onConvidar: _convidar),
          _FormulariosTab(
            turmaId: widget.turmaId,
            turmaNome: widget.turmaNome,
            onAtribuir: _atribuirFormulario,
          ),
          _NotasTab(
            turmaId: widget.turmaId,
          ),
        ],
      ),
    );
  }
}

class _AlunosTab extends StatefulWidget {
  final String turmaId;
  final VoidCallback onConvidar;

  const _AlunosTab({required this.turmaId, required this.onConvidar});

  @override
  State<_AlunosTab> createState() => _AlunosTabState();
}

class _AlunosTabState extends State<_AlunosTab> {
  late Future<List<_ProfConvItem>> _professoresFuture;

  @override
  void initState() {
    super.initState();
    _professoresFuture = _carregarProfessores();
  }

  Future<List<_ProfConvItem>> _carregarProfessores() async {
    final uids = await TurmasDb.getProfessoresConvidados(widget.turmaId);
    if (uids.isEmpty) return [];
    final items = await Future.wait(uids.map((uid) async {
      final doc = await UsuariosDb.getUsuario(uid);
      final data = doc.data() as Map<String, dynamic>?;
      return _ProfConvItem(
        uid: uid,
        nome: data?['nome'] as String? ?? '—',
        email: data?['email'] as String? ?? '—',
      );
    }));
    return items.toList();
  }

  Color _statusColor(bool temConta, bool ativo) {
    if (!temConta) return Colors.orange;
    if (ativo) return Colors.green;
    return Colors.grey.shade600;
  }

  String _statusLabel(bool temConta, bool ativo) {
    if (!temConta) return 'Pendente';
    if (ativo) return 'Ativo';
    return 'Inativo';
  }

  Future<void> _toggleAtivo(
      BuildContext context, String docId, bool novoAtivo) async {
    await TurmasDb.toggleAtivoAluno(widget.turmaId, docId, novoAtivo);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(novoAtivo
              ? 'Aluno reativado com sucesso.'
              : 'Aluno inativado com sucesso.'),
          backgroundColor: novoAtivo ? Colors.green : Colors.grey.shade700,
        ),
      );
    }
  }

  Future<void> _removerAluno(
      BuildContext context, String docId, String email, String? alunoId) async {
    if (alunoId != null) {
      final formsSnap = await TurmasDb.getFormularios(widget.turmaId);
      for (final formDoc in formsSnap.docs) {
        final jaRespondeu =
            await RespostasDb.jaRespondeuPorId('${formDoc.id}_$alunoId');
        if (jaRespondeu) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Este aluno já respondeu avaliações nesta turma e não pode ser removido. Use a opção Inativar.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }
    }

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover aluno'),
        content: Text('Remover "$email" da turma?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await TurmasDb.removerAluno(
          turmaId: widget.turmaId, docId: docId, alunoId: alunoId);
    }
  }

  Future<void> _removerProfessor(
      BuildContext context, _ProfConvItem prof) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover professor'),
        content: Text('Remover "${prof.nome}" dos convidados desta turma?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await TurmasDb.removerConviteProfessor(widget.turmaId, prof.uid);
      if (mounted) {
        setState(() => _professoresFuture = _carregarProfessores());
      }
    }
  }

  Widget _buildProfessorCard(_ProfConvItem prof) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  child: const Icon(Icons.school, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prof.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        prof.email,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (ctx) => PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                    onSelected: (val) {
                      if (val == 'remover') _removerProfessor(ctx, prof);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'remover',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          SizedBox(width: 10),
                          Text('Remover',
                              style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Professor',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.teal,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlunoCard(
      BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final email = (data['email'] as String?) ?? doc.id;
    final nome = data['nome'] as String?;
    final alunoId = data['aluno_id'] as String?;
    final temConta = alunoId != null;
    final ativo = temConta ? ((data['ativo'] as bool?) ?? true) : false;
    final statusColor = _statusColor(temConta, ativo);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nome != null)
                        Text(
                          nome,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: (!temConta || ativo)
                                ? Colors.black87
                                : Colors.grey.shade500,
                          ),
                        ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: nome != null ? 12 : 15,
                          fontWeight: nome != null
                              ? FontWeight.normal
                              : FontWeight.w600,
                          color: nome != null
                              ? Colors.grey
                              : ((!temConta || ativo)
                                  ? Colors.black87
                                  : Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                  onSelected: (val) {
                    switch (val) {
                      case 'inativar':
                        _toggleAtivo(context, doc.id, false);
                      case 'reativar':
                        _toggleAtivo(context, doc.id, true);
                      case 'remover':
                        _removerAluno(context, doc.id, email, alunoId);
                    }
                  },
                  itemBuilder: (_) => [
                    if (temConta && ativo)
                      const PopupMenuItem(
                        value: 'inativar',
                        child: Row(children: [
                          Icon(Icons.block, color: Colors.orange, size: 18),
                          SizedBox(width: 10),
                          Text('Inativar'),
                        ]),
                      ),
                    if (temConta && !ativo)
                      const PopupMenuItem(
                        value: 'reativar',
                        child: Row(children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 18),
                          SizedBox(width: 10),
                          Text('Reativar'),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: 'remover',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 10),
                        Text('Remover',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(temConta, ativo),
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<_ProfConvItem>>(
          future: _professoresFuture,
          builder: (context, profSnap) {
            final professores = profSnap.data ?? [];
            return StreamBuilder<QuerySnapshot>(
              stream: TurmasDb.watchAlunos(widget.turmaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    profSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...(snapshot.data?.docs ?? [])]..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aKey = ((aData['nome'] as String?) ??
                            (aData['email'] as String?) ??
                            '')
                        .toLowerCase();
                    final bKey = ((bData['nome'] as String?) ??
                            (bData['email'] as String?) ??
                            '')
                        .toLowerCase();
                    return aKey.compareTo(bKey);
                  });

                if (docs.isEmpty && professores.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Nenhum aluno nesta turma.',
                    subtitle: 'Convide alunos pelo email.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    ...professores.map(_buildProfessorCard),
                    ...docs.map((doc) => _buildAlunoCard(context, doc)),
                  ],
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: widget.onConvidar,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add),
            label: const Text('Convidar'),
          ),
        ),
      ],
    );
  }
}

class _FormulariosTab extends StatelessWidget {
  final String turmaId;
  final String turmaNome;
  final VoidCallback onAtribuir;

  const _FormulariosTab({
    required this.turmaId,
    required this.turmaNome,
    required this.onAtribuir,
  });

  Future<void> _remover(
      BuildContext context, String formularioId, String titulo) async {
    if (await RespostasDb.hasRespostas(formularioId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não é possível remover "$titulo": existem avaliações respondidas por alunos.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover formulário'),
        content: Text('Remover "$titulo" desta turma?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await TurmasDb.removerFormulario(turmaId, formularioId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: TurmasDb.watchFormularios(turmaId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const EmptyState(
                icon: Icons.add_task_rounded,
                title: 'Nenhum formulário atribuído.',
                subtitle: 'Toque em Atribuir para adicionar.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final titulo = (data['titulo'] as String?) ?? 'Sem título';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
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
                              child: Text(
                                titulo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined,
                                  color: Colors.green),
                              tooltip: 'Relatório de Notas',
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (_) => _RelatorioSheet(
                                  turmaId: turmaId,
                                  turmaNome: turmaNome,
                                  formularioId: doc.id,
                                  tituloFormulario: titulo,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code,
                                  color: Colors.blueAccent),
                              tooltip: 'Gerar QR Code',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QrCodePage(
                                    formularioId: doc.id,
                                    formularioTitulo: titulo,
                                    turmaId: turmaId,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: 'Remover da turma',
                              onPressed: () =>
                                  _remover(context, doc.id, titulo),
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
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: onAtribuir,
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Atribuir'),
          ),
        ),
      ],
    );
  }
}

class _NotasTab extends StatefulWidget {
  final String turmaId;

  const _NotasTab({
    required this.turmaId,
  });

  @override
  State<_NotasTab> createState() => _NotasTabState();
}

class _NotasTabState extends State<_NotasTab> {
  late Future<_NotasTabData> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregarDados();
  }

  Future<_NotasTabData> _carregarDados() async {
    final formulariosSnap = await TurmasDb.getFormularios(widget.turmaId);
    final formularios = await Future.wait(formulariosSnap.docs.map((d) async {
      final data = d.data() as Map<String, dynamic>;
      final respostasSnap = await RespostasDb.getByFormulario(d.id);
      return _FormularioInfo(
        id: d.id,
        titulo: (data['titulo'] as String?) ?? 'Sem título',
        totalRespostas: respostasSnap.docs.length,
      );
    }));

    final alunosSnap = await TurmasDb.watchAlunos(widget.turmaId).first;
    final alunos = alunosSnap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return _AlunoInfo(
        email: (data['email'] as String?) ?? d.id,
        nome: data['nome'] as String?,
        alunoId: data['aluno_id'] as String?,
      );
    }).toList();

    return _NotasTabData(formularios: formularios, alunos: alunos);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_NotasTabData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }

        final data = snapshot.data!;

        if (data.formularios.isEmpty) {
          return const EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'Nenhum formulário atribuído.',
            subtitle: 'Atribua formulários na aba Formulários.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = _carregarDados());
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.formularios.length,
            itemBuilder: (context, i) {
              return _FormularioNotasCard(
                formulario: data.formularios[i],
                alunos: data.alunos,
              );
            },
          ),
        );
      },
    );
  }
}

class _NotasTabData {
  final List<_FormularioInfo> formularios;
  final List<_AlunoInfo> alunos;
  _NotasTabData({required this.formularios, required this.alunos});
}

class _FormularioInfo {
  final String id;
  final String titulo;
  final int totalRespostas;
  _FormularioInfo(
      {required this.id, required this.titulo, required this.totalRespostas});
}

class _AlunoInfo {
  final String email;
  final String? nome;
  final String? alunoId;
  _AlunoInfo({required this.email, this.nome, this.alunoId});
}

class _AlunoNota {
  final _AlunoInfo aluno;
  final double? nota;
  final bool semConta;
  final bool respondeu;
  final bool isProfessor;
  _AlunoNota({
    required this.aluno,
    this.nota,
    required this.semConta,
    required this.respondeu,
    this.isProfessor = false,
  });
}

class _FormularioNotasCard extends StatefulWidget {
  final _FormularioInfo formulario;
  final List<_AlunoInfo> alunos;

  const _FormularioNotasCard({
    required this.formulario,
    required this.alunos,
  });

  @override
  State<_FormularioNotasCard> createState() => _FormularioNotasCardState();
}

class _FormularioNotasCardState extends State<_FormularioNotasCard> {
  bool _loading = false;
  bool _loaded = false;
  List<_AlunoNota> _notas = [];

  Future<void> _carregar() async {
    if (_loaded) return;
    setState(() => _loading = true);

    try {
      final pergsSnap =
          await FormulariosDb.getPerguntasSnap(widget.formulario.id);
      final perguntas = <String, Map<String, dynamic>>{};
      for (final d in pergsSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final pid = data['pergunta_id'] as String?;
        if (pid != null) perguntas[pid] = data;
      }

      final respostasSnap =
          await RespostasDb.getByFormulario(widget.formulario.id);
      final respostasByAluno = <String, Map<String, dynamic>>{};
      for (final d in respostasSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final alunoId = data['aluno_id'] as String?;
        if (alunoId != null) respostasByAluno[alunoId] = data;
      }

      final notas = <_AlunoNota>[];
      for (final aluno in widget.alunos) {
        if (aluno.alunoId == null) {
          notas.add(_AlunoNota(aluno: aluno, semConta: true, respondeu: false));
          continue;
        }

        final resposta = respostasByAluno[aluno.alunoId];
        if (resposta == null) {
          notas.add(
              _AlunoNota(aluno: aluno, semConta: false, respondeu: false));
          continue;
        }

        final respostas =
            List<Map<String, dynamic>>.from(resposta['respostas'] ?? []);
        double totalPeso = 0;
        double totalNota = 0;

        for (final r in respostas) {
          final pergId = r['pergunta_id'] as String?;
          final tipo = (r['tipo'] as String?) ?? '';
          final peso = (r['peso'] as num?)?.toDouble() ?? 1.0;
          final valor = r['valor'];
          final perg = pergId != null ? perguntas[pergId] : null;

          switch (tipo) {
            case 'escala':
              totalPeso += peso;
              totalNota += ((valor as num?)?.toDouble() ?? 0) * peso;
            case 'sim_nao':
            case 'verdadeiro_falso':
              final correta = perg?['resposta_correta'] as String?;
              if (correta == null) break;
              totalPeso += peso;
              totalNota += (valor == correta) ? peso * 10.0 : 0;
            case 'multipla_escolha':
              final correta = perg?['opcao_correta'];
              if (correta == null) break;
              totalPeso += peso;
              totalNota += (valor == correta) ? peso * 10.0 : 0;
            default:
              break;
          }
        }

        final media = totalPeso > 0 ? totalNota / totalPeso : null;
        notas.add(_AlunoNota(
            aluno: aluno, nota: media, semConta: false, respondeu: true));
      }

      // Encontra respostas de professores convidados (is_professor == true, fora da lista de alunos)
      final processedIds = widget.alunos
          .where((a) => a.alunoId != null)
          .map((a) => a.alunoId!)
          .toSet();

      for (final entry in respostasByAluno.entries) {
        if (processedIds.contains(entry.key)) continue;
        final profData = entry.value;
        if ((profData['is_professor'] as bool?) != true) continue;

        double pTotalPeso = 0;
        double pTotalNota = 0;
        final profRespostas =
            List<Map<String, dynamic>>.from(profData['respostas'] ?? []);
        for (final r in profRespostas) {
          final pergId = r['pergunta_id'] as String?;
          final tipo = (r['tipo'] as String?) ?? '';
          final peso = (r['peso'] as num?)?.toDouble() ?? 1.0;
          final valor = r['valor'];
          final perg = pergId != null ? perguntas[pergId] : null;
          switch (tipo) {
            case 'escala':
              pTotalPeso += peso;
              pTotalNota += ((valor as num?)?.toDouble() ?? 0) * peso;
            case 'sim_nao':
            case 'verdadeiro_falso':
              final correta = perg?['resposta_correta'] as String?;
              if (correta == null) break;
              pTotalPeso += peso;
              pTotalNota += (valor == correta) ? peso * 10.0 : 0;
            case 'multipla_escolha':
              final correta = perg?['opcao_correta'];
              if (correta == null) break;
              pTotalPeso += peso;
              pTotalNota += (valor == correta) ? peso * 10.0 : 0;
            default:
              break;
          }
        }
        final profMedia = pTotalPeso > 0 ? pTotalNota / pTotalPeso : null;
        notas.insert(
          0,
          _AlunoNota(
            aluno: _AlunoInfo(
              email: (profData['aluno_email'] as String?) ?? '',
              nome: (profData['aluno_nome'] as String?) ?? 'Professor',
              alunoId: entry.key,
            ),
            nota: profMedia,
            semConta: false,
            respondeu: true,
            isProfessor: true,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _notas = notas;
          _loading = false;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.assignment_outlined, color: Colors.blueAccent),
          ),
          title: Text(widget.formulario.titulo,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${widget.formulario.totalRespostas} pessoa${widget.formulario.totalRespostas == 1 ? '' : 's'} respondeu',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onExpansionChanged: (expanded) {
            if (expanded) _carregar();
          },
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              ..._notas.map((n) {
                final nome = n.aluno.nome ?? n.aluno.email;
                final email = n.aluno.email;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: n.isProfessor
                        ? Colors.teal.shade50
                        : n.respondeu
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                    child: Icon(
                      n.isProfessor ? Icons.school : Icons.person,
                      size: 18,
                      color: n.isProfessor
                          ? Colors.teal
                          : n.respondeu
                              ? Colors.blueAccent
                              : Colors.grey,
                    ),
                  ),
                  title: Text(nome,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: (n.aluno.nome != null && !n.isProfessor)
                      ? Text(email,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey))
                      : null,
                  trailing: n.isProfessor
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _InfoBadge(label: 'Professor', color: Colors.teal),
                            if (n.nota != null) ...[
                              const SizedBox(width: 6),
                              _NotaBadge(nota: n.nota!),
                            ],
                          ],
                        )
                      : n.semConta
                          ? _InfoBadge(label: 'Sem conta', color: Colors.orange)
                          : !n.respondeu
                              ? _InfoBadge(
                                  label: 'Não respondeu', color: Colors.grey)
                              : n.nota != null
                                  ? _NotaBadge(nota: n.nota!)
                                  : _InfoBadge(
                                      label: 'S/ nota auto.',
                                      color: Colors.blueGrey),
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NotaBadge extends StatelessWidget {
  final double nota;
  const _NotaBadge({required this.nota});

  @override
  Widget build(BuildContext context) {
    final color =
        nota >= 7 ? Colors.green : nota >= 5 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        nota.toStringAsFixed(1),
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

/// Retorna dados do relatório incluindo respostas formatadas por aluno.
/// Cada mapa tem: nome, email, nota, data, respostas (List ou null), is_professor (bool).
Future<Map<String, dynamic>> _carregarNotasRelatorio({
  required String turmaId,
  required String formularioId,
}) async {
  final perguntasOrdenadas = await FormulariosDb.getPerguntas(formularioId);
  final perguntas = <String, Map<String, dynamic>>{};
  for (final p in perguntasOrdenadas) {
    final pid = p['pergunta_id'] as String?;
    if (pid != null) perguntas[pid] = p;
  }

  final alunosSnap = await TurmasDb.watchAlunos(turmaId).first;
  final respostasSnap = await RespostasDb.getByFormulario(formularioId);
  final respostasByAluno = <String, Map<String, dynamic>>{};
  for (final d in respostasSnap.docs) {
    final data = d.data() as Map<String, dynamic>;
    final alunoId = data['aluno_id'] as String?;
    if (alunoId != null) respostasByAluno[alunoId] = data;
  }

  final alunos = <Map<String, dynamic>>[];
  for (final alunoDoc in alunosSnap.docs) {
    final alunoData = alunoDoc.data() as Map<String, dynamic>;
    final email = (alunoData['email'] as String?) ?? alunoDoc.id;
    final nomeBase = alunoData['nome'] as String?;
    final alunoId = alunoData['aluno_id'] as String?;

    if (alunoId == null) {
      alunos.add({'nome': nomeBase ?? email, 'email': email, 'nota': null, 'data': null, 'respostas': null});
      continue;
    }

    final resposta = respostasByAluno[alunoId];
    if (resposta == null) {
      alunos.add({'nome': nomeBase ?? email, 'email': email, 'nota': null, 'data': null, 'respostas': null});
      continue;
    }

    final nome = (resposta['aluno_nome'] as String?) ?? nomeBase ?? email;
    final respostas =
        List<Map<String, dynamic>>.from(resposta['respostas'] ?? []);

    double totalPeso = 0;
    double totalNota = 0;

    final respostasFormatadas = <Map<String, dynamic>>[];
    for (final r in respostas) {
      final pergId = r['pergunta_id'] as String?;
      final tipo = (r['tipo'] as String?) ?? '';
      final peso = (r['peso'] as num?)?.toDouble() ?? 1.0;
      final valor = r['valor'];
      final perg = pergId != null ? perguntas[pergId] : null;
      final titulo = (r['titulo'] as String?) ?? (perg?['titulo'] as String?) ?? '—';

      String valorFmt;
      switch (tipo) {
        case 'escala':
          totalPeso += peso;
          totalNota += ((valor as num?)?.toDouble() ?? 0) * peso;
          valorFmt = '${(valor as num).round()} / 10';
        case 'sim_nao':
          final correta = perg?['resposta_correta'] as String?;
          if (correta != null) {
            totalPeso += peso;
            totalNota += (valor == correta) ? peso * 10.0 : 0;
          }
          valorFmt = valor?.toString() ?? '—';
        case 'verdadeiro_falso':
          final correta = perg?['resposta_correta'] as String?;
          if (correta != null) {
            totalPeso += peso;
            totalNota += (valor == correta) ? peso * 10.0 : 0;
          }
          valorFmt = valor == 'verdadeiro'
              ? 'Verdadeiro'
              : valor == 'falso'
                  ? 'Falso'
                  : '—';
        case 'multipla_escolha':
          final correta = perg?['opcao_correta'];
          if (correta != null) {
            totalPeso += peso;
            totalNota += (valor == correta) ? peso * 10.0 : 0;
          }
          final opcoes = List<String>.from(perg?['opcoes'] ?? []);
          final idx = valor is int ? valor : int.tryParse(valor?.toString() ?? '');
          valorFmt = (idx != null && idx >= 0 && idx < opcoes.length)
              ? opcoes[idx]
              : '—';
        default:
          valorFmt = valor?.toString() ?? '—';
      }

      respostasFormatadas.add({'titulo': titulo, 'tipo': tipo, 'valor_formatado': valorFmt});
    }

    final media = totalPeso > 0 ? totalNota / totalPeso : null;
    final respondidoEm =
        (resposta['respondido_em'] as Timestamp?)?.toDate();
    alunos.add({
      'nome': nome,
      'email': email,
      'nota': media,
      'data': respondidoEm,
      'respostas': respostasFormatadas,
    });
  }

  // Respostas de professores convidados (is_professor == true, fora da lista de alunos)
  final alunoIdSet = alunosSnap.docs
      .map((d) => (d.data() as Map<String, dynamic>)['aluno_id'] as String?)
      .whereType<String>()
      .toSet();

  for (final entry in respostasByAluno.entries) {
    if (alunoIdSet.contains(entry.key)) continue;
    final profRespData = entry.value;
    if ((profRespData['is_professor'] as bool?) != true) continue;

    final profNome = (profRespData['aluno_nome'] as String?) ?? 'Professor';
    final profEmail = (profRespData['aluno_email'] as String?) ?? '';
    final profRespostas =
        List<Map<String, dynamic>>.from(profRespData['respostas'] ?? []);

    double pTotalPeso = 0;
    double pTotalNota = 0;
    final profRespostasFormatadas = <Map<String, dynamic>>[];

    for (final r in profRespostas) {
      final pergId = r['pergunta_id'] as String?;
      final tipo = (r['tipo'] as String?) ?? '';
      final peso = (r['peso'] as num?)?.toDouble() ?? 1.0;
      final valor = r['valor'];
      final perg = pergId != null ? perguntas[pergId] : null;
      final titulo =
          (r['titulo'] as String?) ?? (perg?['titulo'] as String?) ?? '—';

      String valorFmt;
      switch (tipo) {
        case 'escala':
          pTotalPeso += peso;
          pTotalNota += ((valor as num?)?.toDouble() ?? 0) * peso;
          valorFmt = '${(valor as num).round()} / 10';
        case 'sim_nao':
          final correta = perg?['resposta_correta'] as String?;
          if (correta != null) {
            pTotalPeso += peso;
            pTotalNota += (valor == correta) ? peso * 10.0 : 0;
          }
          valorFmt = valor?.toString() ?? '—';
        case 'verdadeiro_falso':
          final correta = perg?['resposta_correta'] as String?;
          if (correta != null) {
            pTotalPeso += peso;
            pTotalNota += (valor == correta) ? peso * 10.0 : 0;
          }
          valorFmt = valor == 'verdadeiro'
              ? 'Verdadeiro'
              : valor == 'falso'
                  ? 'Falso'
                  : '—';
        case 'multipla_escolha':
          final correta = perg?['opcao_correta'];
          if (correta != null) {
            pTotalPeso += peso;
            pTotalNota += (valor == correta) ? peso * 10.0 : 0;
          }
          final opcoes = List<String>.from(perg?['opcoes'] ?? []);
          final idx =
              valor is int ? valor : int.tryParse(valor?.toString() ?? '');
          valorFmt = (idx != null && idx >= 0 && idx < opcoes.length)
              ? opcoes[idx]
              : '—';
        default:
          valorFmt = valor?.toString() ?? '—';
      }
      profRespostasFormatadas
          .add({'titulo': titulo, 'tipo': tipo, 'valor_formatado': valorFmt});
    }

    final profMedia = pTotalPeso > 0 ? pTotalNota / pTotalPeso : null;
    final profRespondidoEm =
        (profRespData['respondido_em'] as Timestamp?)?.toDate();
    alunos.insert(0, {
      'nome': profNome,
      'email': profEmail,
      'nota': profMedia,
      'data': profRespondidoEm,
      'respostas': profRespostasFormatadas,
      'is_professor': true,
    });
  }

  return {
    'perguntas': perguntasOrdenadas,
    'alunos': alunos,
  };
}

class _RelatorioSheet extends StatefulWidget {
  final String turmaId;
  final String turmaNome;
  final String formularioId;
  final String tituloFormulario;

  const _RelatorioSheet({
    required this.turmaId,
    required this.turmaNome,
    required this.formularioId,
    required this.tituloFormulario,
  });

  @override
  State<_RelatorioSheet> createState() => _RelatorioSheetState();
}

class _RelatorioSheetState extends State<_RelatorioSheet> {
  bool _loadingPdf = false;
  bool _loadingEmail = false;

  Future<void> _gerarPdf() async {
    setState(() => _loadingPdf = true);
    try {
      final relatorio = await _carregarNotasRelatorio(
        turmaId: widget.turmaId,
        formularioId: widget.formularioId,
      );
      final perguntas =
          List<Map<String, dynamic>>.from(relatorio['perguntas'] as List);
      final alunos =
          List<Map<String, dynamic>>.from(relatorio['alunos'] as List);
      await PdfService.gerarNotasFormulario(
        tituloFormulario: widget.tituloFormulario,
        turmaNome: widget.turmaNome,
        perguntas: perguntas,
        alunos: alunos,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao gerar PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _enviarEmail() async {
    setState(() => _loadingEmail = true);
    try {
      final profEmail = AuthService.currentUser?.email ?? '';
      if (profEmail.isEmpty) throw Exception('E-mail não encontrado.');

      final relatorio = await _carregarNotasRelatorio(
        turmaId: widget.turmaId,
        formularioId: widget.formularioId,
      );
      final perguntas =
          List<Map<String, dynamic>>.from(relatorio['perguntas'] as List);
      final alunos =
          List<Map<String, dynamic>>.from(relatorio['alunos'] as List);

      final pdfBytes = await PdfService.gerarNotasFormularioBytes(
        tituloFormulario: widget.tituloFormulario,
        turmaNome: widget.turmaNome,
        perguntas: perguntas,
        alunos: alunos,
      );

      await EmailService.enviarRelatorioFormulario(
        destinatario: profEmail,
        tituloFormulario: widget.tituloFormulario,
        turmaNome: widget.turmaNome,
        totalAlunos: alunos.length,
        pdfBytes: pdfBytes,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relatório enviado para $profEmail'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao enviar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.tituloFormulario,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            widget.turmaNome,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: _loadingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.picture_as_pdf_outlined,
                      color: Colors.green.shade700),
            ),
            title: const Text('Gerar PDF'),
            subtitle: const Text('Abrir / imprimir o relatório de notas'),
            onTap: _loadingPdf ? null : _gerarPdf,
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: _loadingEmail
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.email_outlined, color: Colors.blue.shade700),
            ),
            title: const Text('Enviar por Email'),
            subtitle: const Text('Enviar relatório ao seu e-mail'),
            onTap: _loadingEmail ? null : _enviarEmail,
          ),
        ],
      ),
    );
  }
}

class _ConvidarSheet extends StatelessWidget {
  final String turmaId;
  final String turmaNome;
  final String professorDonoId;

  const _ConvidarSheet({
    required this.turmaId,
    required this.turmaNome,
    required this.professorDonoId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      children: const [
                        Icon(Icons.person, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Convidar Aluno',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  _AlunoTabContent(turmaId: turmaId, turmaNome: turmaNome),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      children: const [
                        Icon(Icons.school, color: Colors.teal, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Professores Convidados',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                  _ProfessorTabContent(
                    turmaId: turmaId,
                    turmaNome: turmaNome,
                    professorDonoId: professorDonoId,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlunoTabContent extends StatefulWidget {
  final String turmaId;
  final String turmaNome;

  const _AlunoTabContent({required this.turmaId, required this.turmaNome});

  @override
  State<_AlunoTabContent> createState() => _AlunoTabContentState();
}

class _AlunoTabContentState extends State<_AlunoTabContent> {
  final _emailCtrl = TextEditingController();
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _convidar() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _erro = 'Informe um e-mail válido.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final existing = await TurmasDb.getAluno(widget.turmaId, email);
      if (existing.exists) {
        setState(() {
          _erro = 'Este aluno já foi convidado.';
          _carregando = false;
        });
        return;
      }

      final usuariosSnap = await UsuariosDb.findByEmail(email);
      String? alunoId;
      String? alunoNome;
      if (usuariosSnap.docs.isNotEmpty) {
        final userDoc = usuariosSnap.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['tipo'] == 'aluno') {
          alunoId = userDoc.id;
          alunoNome = userData['nome'] as String?;
        }
      }

      await TurmasDb.convidarAluno(
        turmaId: widget.turmaId,
        email: email,
        alunoId: alunoId,
        alunoNome: alunoNome,
      );

      EmailService.enviarConviteAluno(
        destinatario: email,
        turmaNome: widget.turmaNome,
      ).catchError((_) {});

      if (mounted) {
        _emailCtrl.clear();
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alunoId != null
                ? 'Aluno adicionado! Email de convite enviado.'
                : 'Convite registado. Email enviado ao aluno.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _convidar(),
            onChanged: (_) {
              if (_erro != null) setState(() => _erro = null);
            },
            decoration: InputDecoration(
              hintText: 'email@exemplo.com',
              prefixIcon:
                  const Icon(Icons.email_outlined, color: Colors.green),
              errorText: _erro,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _carregando ? null : _convidar,
              child: _carregando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Convidar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessorTabContent extends StatefulWidget {
  final String turmaId;
  final String turmaNome;
  final String professorDonoId;

  const _ProfessorTabContent({
    required this.turmaId,
    required this.turmaNome,
    required this.professorDonoId,
  });

  @override
  State<_ProfessorTabContent> createState() => _ProfessorTabContentState();
}

class _ProfessorTabContentState extends State<_ProfessorTabContent> {
  final _emailCtrl = TextEditingController();
  bool _carregando = true;
  bool _adicionando = false;
  List<_ProfConvItem> _convidados = [];
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final uids = await TurmasDb.getProfessoresConvidados(widget.turmaId);
      final items = await Future.wait(uids.map((uid) async {
        final doc = await UsuariosDb.getUsuario(uid);
        final data = doc.data() as Map<String, dynamic>?;
        return _ProfConvItem(
          uid: uid,
          nome: data?['nome'] as String? ?? '—',
          email: data?['email'] as String? ?? '—',
        );
      }));
      if (mounted) {
        setState(() {
          _convidados = items.toList();
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _carregando = false;
        });
      }
    }
  }

  Future<void> _adicionar() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erro = 'Informe um email válido.');
      return;
    }

    final currentEmail = AuthService.currentUser?.email?.toLowerCase() ?? '';
    if (email == currentEmail) {
      setState(() => _erro = 'Você não pode se convidar para sua própria turma.');
      return;
    }

    setState(() {
      _adicionando = true;
      _erro = null;
    });
    try {
      final snap = await UsuariosDb.findByEmail(email);
      if (snap.docs.isEmpty) {
        setState(() {
          _erro = 'Nenhum usuário encontrado com este email.';
          _adicionando = false;
        });
        return;
      }
      final userDoc = snap.docs.first;
      if (userDoc.id == widget.professorDonoId) {
        setState(() {
          _erro = 'Você não pode se convidar para sua própria turma.';
          _adicionando = false;
        });
        return;
      }
      final tipo = (userDoc.data() as Map<String, dynamic>)['tipo'] as String? ?? '';
      if (tipo != 'professor') {
        setState(() {
          _erro = 'Este usuário não é um professor.';
          _adicionando = false;
        });
        return;
      }
      if (_convidados.any((c) => c.uid == userDoc.id)) {
        setState(() {
          _erro = 'Este professor já foi convidado.';
          _adicionando = false;
        });
        return;
      }
      await TurmasDb.convidarProfessor(widget.turmaId, userDoc.id);
      EmailService.enviarConviteProfessor(
        destinatario: email,
        turmaNome: widget.turmaNome,
      ).catchError((_) {});
      _emailCtrl.clear();
      await _carregar();
      if (mounted) setState(() => _adicionando = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _adicionando = false;
        });
      }
    }
  }

  Future<void> _remover(String uid) async {
    await TurmasDb.removerConviteProfessor(widget.turmaId, uid);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_carregando)
            const Center(child: CircularProgressIndicator())
          else if (_convidados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum professor convidado ainda.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ..._convidados.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.school, color: Colors.teal),
                ),
                title: Text(p.nome,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(p.email,
                    style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.redAccent),
                  tooltip: 'Remover convite',
                  onPressed: () => _remover(p.uid),
                ),
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _adicionar(),
                  decoration: InputDecoration(
                    hintText: 'Email do professor',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: Colors.teal, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _adicionando
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : ElevatedButton(
                      onPressed: _adicionar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Convidar'),
                    ),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _ProfConvItem {
  final String uid;
  final String nome;
  final String email;
  const _ProfConvItem(
      {required this.uid, required this.nome, required this.email});
}
