import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'qr_code_page.dart';
import '../widgets/empty_state.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/api/turmas_api.dart';
import '../services/api/formularios_api.dart';
import '../services/api/respostas_api.dart';
import '../services/api/usuarios_api.dart';
import '../services/pdf_service.dart';
import '../services/route_observer.dart';

class TurmaDetailPage extends StatefulWidget {
  final String turmaId;
  final String turmaNome;

  const TurmaDetailPage(
      {super.key, required this.turmaId, required this.turmaNome});

  @override
  State<TurmaDetailPage> createState() => _TurmaDetailPageState();
}

class _TurmaDetailPageState extends State<TurmaDetailPage>
    with SingleTickerProviderStateMixin, RouteAware {
  late final TabController _tabController;
  final _alunosTabKey = GlobalKey<_AlunosTabState>();
  final _formulariosTabKey = GlobalKey<_FormulariosTabState>();

  String get _professorId => AuthService.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  /// Chamado sempre que a rota empilhada por cima desta é fechada (convite,
  /// atribuir formulário, QR code, etc.) — reforça o recarregamento das
  /// abas mesmo que o encadeamento manual do Navigator não dispare.
  @override
  void didPopNext() {
    _alunosTabKey.currentState?.reload();
    _formulariosTabKey.currentState?.reload();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
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
    await _alunosTabKey.currentState?.reload();
  }

  Future<void> _atribuirFormulario() async {
    final formularios = await FormulariosApi.listar();

    if (!mounted) return;

    if (formularios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não tem formulários criados.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final assigned = await TurmasApi.listarFormularios(widget.turmaId);
    if (!mounted) return;

    final assignedIds = assigned.map((d) => d['id'] as String).toSet();
    final available =
        formularios.where((d) => !assignedIds.contains(d['id'])).toList();

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
                    final titulo = doc['titulo'] as String? ?? 'Sem título';
                    return ListTile(
                      leading: const Icon(Icons.assignment_outlined,
                          color: Colors.blueAccent),
                      title: Text(titulo),
                      onTap: () async {
                        await TurmasApi.atribuirFormulario(
                            widget.turmaId, doc['id'] as String);
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
    await _formulariosTabKey.currentState?.reload();
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
          _AlunosTab(
              key: _alunosTabKey,
              turmaId: widget.turmaId,
              onConvidar: _convidar),
          _FormulariosTab(
            key: _formulariosTabKey,
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

  const _AlunosTab({super.key, required this.turmaId, required this.onConvidar});

  @override
  State<_AlunosTab> createState() => _AlunosTabState();
}

class _AlunosTabState extends State<_AlunosTab> {
  late Future<List<_ProfConvItem>> _professoresFuture;
  late Future<List<Map<String, dynamic>>> _alunosFuture;

  /// Evita que um reload mais antigo, ainda em voo, sobrescreva com dados
  /// desatualizados o resultado de uma ação mais recente.
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _professoresFuture = _carregarProfessores();
    _alunosFuture = TurmasApi.listarAlunos(widget.turmaId);
  }

  Future<void> reload() async {
    final gen = ++_reqGen;
    try {
      final resultados = await Future.wait([
        _carregarProfessores(),
        TurmasApi.listarAlunos(widget.turmaId),
      ]);
      if (mounted && gen == _reqGen) {
        setState(() {
          _professoresFuture = Future.value(resultados[0] as List<_ProfConvItem>);
          _alunosFuture = Future.value(resultados[1] as List<Map<String, dynamic>>);
        });
      }
    } catch (_) {
      // mantém os dados atuais; o usuário pode puxar para atualizar depois.
    }
  }

  Future<List<_ProfConvItem>> _carregarProfessores() async {
    final profs = await TurmasApi.listarProfessoresConvidados(widget.turmaId);
    return profs
        .map((p) => _ProfConvItem(
              uid: p['id'] as String,
              nome: p['nome'] as String? ?? '—',
              email: p['email'] as String? ?? '—',
            ))
        .toList();
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
      BuildContext context, String turmaAlunoId, bool novoAtivo) async {
    await TurmasApi.toggleAtivoAluno(widget.turmaId, turmaAlunoId, novoAtivo);
    reload();
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

  Future<void> _removerAluno(BuildContext context, String turmaAlunoId,
      String email, String? alunoId) async {
    if (alunoId != null) {
      final formularios = await TurmasApi.listarFormularios(widget.turmaId);
      for (final f in formularios) {
        final respostas = await FormulariosApi.listarRespostas(f['id'] as String);
        final jaRespondeu = respostas.any((r) => r['aluno_id'] == alunoId);
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
      await TurmasApi.removerAluno(widget.turmaId, turmaAlunoId);
      reload();
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
      await TurmasApi.removerConviteProfessor(widget.turmaId, prof.uid);
      if (mounted) reload();
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

  Widget _buildAlunoCard(BuildContext context, Map<String, dynamic> aluno) {
    final turmaAlunoId = aluno['id'] as String;
    final email = (aluno['email'] as String?) ?? turmaAlunoId;
    final nome = aluno['nome'] as String?;
    final alunoId = aluno['aluno_id'] as String?;
    final temConta = alunoId != null;
    final ativo = temConta ? ((aluno['ativo'] as bool?) ?? true) : false;
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
                        _toggleAtivo(context, turmaAlunoId, false);
                      case 'reativar':
                        _toggleAtivo(context, turmaAlunoId, true);
                      case 'remover':
                        _removerAluno(context, turmaAlunoId, email, alunoId);
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
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _alunosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    profSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final alunos = [...(snapshot.data ?? [])]..sort((a, b) {
                    final aKey = ((a['nome'] as String?) ??
                            (a['email'] as String?) ??
                            '')
                        .toLowerCase();
                    final bKey = ((b['nome'] as String?) ??
                            (b['email'] as String?) ??
                            '')
                        .toLowerCase();
                    return aKey.compareTo(bKey);
                  });

                if (alunos.isEmpty && professores.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Nenhum aluno nesta turma.',
                    subtitle: 'Convide alunos pelo email.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      ...professores.map(_buildProfessorCard),
                      ...alunos.map((a) => _buildAlunoCard(context, a)),
                    ],
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

class _FormulariosTab extends StatefulWidget {
  final String turmaId;
  final String turmaNome;
  final VoidCallback onAtribuir;

  const _FormulariosTab({
    super.key,
    required this.turmaId,
    required this.turmaNome,
    required this.onAtribuir,
  });

  @override
  State<_FormulariosTab> createState() => _FormulariosTabState();
}

class _FormulariosTabState extends State<_FormulariosTab> {
  late Future<List<Map<String, dynamic>>> _future;

  /// Evita que um reload mais antigo, ainda em voo, sobrescreva com dados
  /// desatualizados o resultado de uma ação mais recente.
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _future = TurmasApi.listarFormularios(widget.turmaId);
  }

  Future<void> reload() async {
    final gen = ++_reqGen;
    try {
      final dados = await TurmasApi.listarFormularios(widget.turmaId);
      if (mounted && gen == _reqGen) {
        setState(() {
          _future = Future.value(dados);
        });
      }
    } catch (_) {
      // mantém a lista atual; o usuário pode puxar para atualizar depois.
    }
  }

  Future<void> _remover(
      BuildContext context, String formularioId, String titulo) async {
    final respostas = await FormulariosApi.listarRespostas(formularioId);
    if (respostas.isNotEmpty) {
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
      await TurmasApi.removerFormulario(widget.turmaId, formularioId);
      // Remove da lista já em memória imediatamente, sem esperar um novo GET.
      final gen = ++_reqGen;
      final atual = await _future;
      if (mounted && gen == _reqGen) {
        setState(() {
          _future =
              Future.value(atual.where((f) => f['id'] != formularioId).toList());
        });
      }
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data ?? [];

            if (docs.isEmpty) {
              return const EmptyState(
                icon: Icons.add_task_rounded,
                title: 'Nenhum formulário atribuído.',
                subtitle: 'Toque em Atribuir para adicionar.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final id = doc['id'] as String;
                  final titulo = (doc['titulo'] as String?) ?? 'Sem título';

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
                                    turmaId: widget.turmaId,
                                    turmaNome: widget.turmaNome,
                                    formularioId: id,
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
                                      formularioId: id,
                                      formularioTitulo: titulo,
                                      turmaId: widget.turmaId,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                tooltip: 'Remover da turma',
                                onPressed: () =>
                                    _remover(context, id, titulo),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: widget.onAtribuir,
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
    final formulariosList = await TurmasApi.listarFormularios(widget.turmaId);
    final formularios = await Future.wait(formulariosList.map((f) async {
      final respostas = await FormulariosApi.listarRespostas(f['id'] as String);
      return _FormularioInfo(
        id: f['id'] as String,
        titulo: (f['titulo'] as String?) ?? 'Sem título',
        totalRespostas: respostas.length,
      );
    }));

    final alunosList = await TurmasApi.listarAlunos(widget.turmaId);
    final alunos = alunosList.map((a) {
      return _AlunoInfo(
        email: (a['email'] as String?) ?? '',
        nome: a['nome'] as String?,
        alunoId: a['aluno_id'] as String?,
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
            final dados = await _carregarDados();
            if (mounted) {
              setState(() {
                _future = Future.value(dados);
              });
            }
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

  double? _parseNota(dynamic valor) =>
      valor != null ? double.tryParse(valor.toString()) : null;

  /// A nota já vem calculada pelo backend no momento do submit — não é mais
  /// preciso recalcular a partir das respostas individuais aqui.
  Future<void> _carregar() async {
    if (_loaded) return;
    setState(() => _loading = true);

    try {
      final respostas =
          await FormulariosApi.listarRespostas(widget.formulario.id);
      final respostasByAluno = <String, Map<String, dynamic>>{
        for (final r in respostas)
          if (r['aluno_id'] != null) r['aluno_id'] as String: r,
      };

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

        notas.add(_AlunoNota(
          aluno: aluno,
          nota: _parseNota(resposta['nota']),
          semConta: false,
          respondeu: true,
        ));
      }

      // Respostas de professores convidados (is_professor == true, fora da lista de alunos)
      final processedIds = widget.alunos
          .where((a) => a.alunoId != null)
          .map((a) => a.alunoId!)
          .toSet();

      for (final entry in respostasByAluno.entries) {
        if (processedIds.contains(entry.key)) continue;
        final resposta = entry.value;
        if ((resposta['is_professor'] as bool?) != true) continue;

        notas.insert(
          0,
          _AlunoNota(
            aluno: _AlunoInfo(
              email: (resposta['aluno_email'] as String?) ?? '',
              nome: (resposta['aluno_nome'] as String?) ?? 'Professor',
              alunoId: entry.key,
            ),
            nota: _parseNota(resposta['nota']),
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

String _formatarValor(String tipo, dynamic valor, Map<String, dynamic>? perg) {
  switch (tipo) {
    case 'escala':
      final n = double.tryParse(valor?.toString() ?? '');
      return n != null ? '${n.round()} / 10' : '—';
    case 'sim_nao':
      return valor?.toString() ?? '—';
    case 'verdadeiro_falso':
      return valor == 'verdadeiro'
          ? 'Verdadeiro'
          : valor == 'falso'
              ? 'Falso'
              : '—';
    case 'multipla_escolha':
      final opcoes = List<String>.from(perg?['opcoes'] ?? []);
      final idx = int.tryParse(valor?.toString() ?? '');
      return (idx != null && idx >= 0 && idx < opcoes.length)
          ? opcoes[idx]
          : '—';
    default:
      return valor?.toString() ?? '—';
  }
}

/// Retorna dados do relatório incluindo respostas formatadas por aluno.
/// Cada mapa tem: nome, email, nota, data, respostas (List ou null), is_professor (bool).
/// A nota vem pronta do backend (calculada no submit); aqui só formatamos os
/// valores individuais de cada pergunta para exibição no PDF.
Future<Map<String, dynamic>> _carregarNotasRelatorio({
  required String turmaId,
  required String formularioId,
}) async {
  final formularioDetalhe = await FormulariosApi.getFormulario(formularioId);
  final perguntasOrdenadas =
      ((formularioDetalhe['perguntas'] as List?) ?? []).cast<Map<String, dynamic>>();
  final perguntas = <String, Map<String, dynamic>>{
    for (final p in perguntasOrdenadas) p['pergunta_id'] as String: p,
  };

  final alunosTurma = await TurmasApi.listarAlunos(turmaId);
  final respostasResumo = await FormulariosApi.listarRespostas(formularioId);
  final respostasByAlunoId = <String, Map<String, dynamic>>{
    for (final r in respostasResumo)
      if (r['aluno_id'] != null) r['aluno_id'] as String: r,
  };

  Future<List<Map<String, dynamic>>> formatarItens(String respostaId) async {
    final detalhe = await RespostasApi.getRespostaById(respostaId);
    final itens = ((detalhe['itens'] as List?) ?? []).cast<Map<String, dynamic>>();
    return itens.map((item) {
      final perg = perguntas[item['pergunta_id']];
      final tipo = perg?['tipo'] as String? ?? '';
      final titulo = perg?['titulo'] as String? ?? '—';
      return {
        'titulo': titulo,
        'tipo': tipo,
        'valor_formatado': _formatarValor(tipo, item['valor'], perg),
      };
    }).toList();
  }

  final alunos = <Map<String, dynamic>>[];
  for (final a in alunosTurma) {
    final email = (a['email'] as String?) ?? '';
    final nomeBase = a['nome'] as String?;
    final alunoId = a['aluno_id'] as String?;

    final resumo = alunoId != null ? respostasByAlunoId[alunoId] : null;
    if (resumo == null) {
      alunos.add({
        'nome': nomeBase ?? email,
        'email': email,
        'nota': null,
        'data': null,
        'respostas': null,
      });
      continue;
    }

    alunos.add({
      'nome': (resumo['aluno_nome'] as String?) ?? nomeBase ?? email,
      'email': email,
      'nota': resumo['nota'] != null ? double.tryParse(resumo['nota'].toString()) : null,
      'data': resumo['respondido_em'] != null
          ? DateTime.parse(resumo['respondido_em'] as String)
          : null,
      'respostas': await formatarItens(resumo['resposta_id'] as String),
    });
  }

  // Respostas de professores convidados (is_professor == true, fora da lista de alunos)
  final alunoIdSet =
      alunosTurma.map((a) => a['aluno_id'] as String?).whereType<String>().toSet();

  for (final entry in respostasByAlunoId.entries) {
    if (alunoIdSet.contains(entry.key)) continue;
    final resumo = entry.value;
    if ((resumo['is_professor'] as bool?) != true) continue;

    alunos.insert(0, {
      'nome': (resumo['aluno_nome'] as String?) ?? 'Professor',
      'email': (resumo['aluno_email'] as String?) ?? '',
      'nota': resumo['nota'] != null ? double.tryParse(resumo['nota'].toString()) : null,
      'data': resumo['respondido_em'] != null
          ? DateTime.parse(resumo['respondido_em'] as String)
          : null,
      'respostas': await formatarItens(resumo['resposta_id'] as String),
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
  bool _loadingCompartilhar = false;

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

  Future<void> _compartilhar() async {
    setState(() => _loadingCompartilhar = true);
    try {
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

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${widget.tituloFormulario}.pdf',
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao compartilhar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCompartilhar = false);
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
              child: _loadingCompartilhar
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.share_outlined, color: Colors.blue.shade700),
            ),
            title: const Text('Compartilhar'),
            subtitle: const Text('Enviar o PDF por email, WhatsApp, etc.'),
            onTap: _loadingCompartilhar ? null : _compartilhar,
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
  String? _sucesso;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _convidar() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() {
        _erro = 'Informe um e-mail válido.';
        _sucesso = null;
      });
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      // O backend resolve se o email já tem conta, grava o convite e envia
      // o e-mail de convite — é seguro chamar de novo para o mesmo email.
      await TurmasApi.convidarAluno(turmaId: widget.turmaId, email: email);

      if (mounted) {
        _emailCtrl.clear();
        setState(() {
          _carregando = false;
          _sucesso = 'Convite enviado! O aluno receberá um e-mail.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.message;
          _sucesso = null;
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
              if (_erro != null || _sucesso != null) {
                setState(() {
                  _erro = null;
                  _sucesso = null;
                });
              }
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
          if (_sucesso != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _sucesso!,
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
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
      final profs = await TurmasApi.listarProfessoresConvidados(widget.turmaId);
      if (mounted) {
        setState(() {
          _convidados = profs
              .map((p) => _ProfConvItem(
                    uid: p['id'] as String,
                    nome: p['nome'] as String? ?? '—',
                    email: p['email'] as String? ?? '—',
                  ))
              .toList();
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

    final currentEmail = AuthService.currentUser?.email.toLowerCase() ?? '';
    if (email == currentEmail) {
      setState(() => _erro = 'Você não pode se convidar para sua própria turma.');
      return;
    }

    setState(() {
      _adicionando = true;
      _erro = null;
    });
    try {
      final usuario = await UsuariosApi.buscarPorEmail(email);
      if (usuario == null) {
        setState(() {
          _erro = 'Nenhum usuário encontrado com este email.';
          _adicionando = false;
        });
        return;
      }
      if (usuario['id'] == widget.professorDonoId) {
        setState(() {
          _erro = 'Você não pode se convidar para sua própria turma.';
          _adicionando = false;
        });
        return;
      }
      final tipo = usuario['tipo'] as String? ?? '';
      if (tipo != 'professor') {
        setState(() {
          _erro = 'Este usuário não é um professor.';
          _adicionando = false;
        });
        return;
      }
      if (_convidados.any((c) => c.uid == usuario['id'])) {
        setState(() {
          _erro = 'Este professor já foi convidado.';
          _adicionando = false;
        });
        return;
      }
      await TurmasApi.convidarProfessor(widget.turmaId, usuario['id'] as String);
      _emailCtrl.clear();
      await _carregar();
      if (mounted) setState(() => _adicionando = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.message;
          _adicionando = false;
        });
      }
    }
  }

  Future<void> _remover(String uid) async {
    await TurmasApi.removerConviteProfessor(widget.turmaId, uid);
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
