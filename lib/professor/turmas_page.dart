import 'package:flutter/material.dart';
import 'turma_detail_page.dart';
import '../widgets/empty_state.dart';
import '../services/api_client.dart';
import '../services/api/turmas_api.dart';
import '../services/api/formularios_api.dart';
import '../services/route_observer.dart';

class TurmasPage extends StatefulWidget {
  const TurmasPage({super.key});

  @override
  State<TurmasPage> createState() => _TurmasPageState();
}

class _TurmasPageState extends State<TurmasPage> with RouteAware {
  late Future<List<Map<String, dynamic>>> _future;

  /// Incrementado a cada ação que deveria atualizar `_future` — evita que um
  /// GET mais antigo, ainda em voo, sobrescreva com dados desatualizados o
  /// resultado de uma ação mais recente (ex.: criar/remover).
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _future = TurmasApi.listar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Chamado sempre que a rota empilhada por cima desta é fechada (ex.: o
  /// bottom sheet de nova turma, ou voltar de TurmaDetailPage) — reforça o
  /// recarregamento mesmo que o fluxo específico não dispare corretamente.
  @override
  void didPopNext() => _recarregar();

  /// Busca a lista nova ANTES de trocar `_future` — assim, se o reload falhar
  /// (rede instável), a lista antiga continua na tela em vez de sumir atrás
  /// de um erro.
  Future<void> _recarregar() async {
    final gen = ++_reqGen;
    try {
      final dados = await TurmasApi.listar();
      if (mounted && gen == _reqGen) {
        setState(() {
          _future = Future.value(dados);
        });
      }
    } catch (_) {
      // mantém a lista atual; o usuário pode puxar para atualizar depois.
    }
  }

  Future<bool> _turmaHasRespostas(String turmaId) async {
    final formularios = await TurmasApi.listarFormularios(turmaId);
    for (final f in formularios) {
      final respostas = await FormulariosApi.listarRespostas(f['id'] as String);
      if (respostas.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _mostrarDialogCriar(BuildContext context) async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TurmaSheet(
        controller: controller,
        titulo: 'Nova Turma',
        labelBotao: 'Criar Turma',
        onSalvar: (nome) async {
          try {
            await TurmasApi.create(nome);
            return null;
          } on ApiException catch (e) {
            return e.status == 409 ? 'Já existe uma turma com este nome.' : e.message;
          }
        },
      ),
    );
    _recarregar();
  }

  Future<void> _mostrarDialogRenomear(
      BuildContext context, String turmaId, String nomeAtual) async {
    final controller = TextEditingController(text: nomeAtual);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TurmaSheet(
        controller: controller,
        titulo: 'Renomear Turma',
        labelBotao: 'Salvar',
        onSalvar: (nome) async {
          if (nome == nomeAtual) return null;
          try {
            await TurmasApi.rename(turmaId, nome);
            return null;
          } on ApiException catch (e) {
            return e.status == 409 ? 'Já existe uma turma com este nome.' : e.message;
          }
        },
      ),
    );
    _recarregar();
  }

  Future<void> _confirmarDelete(
      BuildContext context, String turmaId, String nome) async {
    if (await _turmaHasRespostas(turmaId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não é possível remover "$nome": já existem avaliações respondidas nesta turma.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover turma'),
        content: Text(
            'Remover "$nome"?\nOs alunos e formulários atribuídos também serão removidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await TurmasApi.delete(turmaId);
      // Remove da lista já em memória imediatamente, sem esperar um novo GET.
      // Bump do gen ANTES de ler `_future` invalida qualquer reload mais
      // antigo ainda em voo.
      final gen = ++_reqGen;
      final atual = await _future;
      if (mounted && gen == _reqGen) {
        setState(() {
          _future = Future.value(atual.where((t) => t['id'] != turmaId).toList());
        });
      }
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Turmas'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _recarregar(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }

            final turmas = snapshot.data ?? [];

            if (turmas.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.group_outlined,
                    title: 'Nenhuma turma criada.',
                    subtitle: 'Toque em + para criar a primeira turma.',
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: turmas.length,
              itemBuilder: (context, index) {
                final turma = turmas[index];
                final id = turma['id'] as String;
                final nome = (turma['nome'] as String?) ?? 'Turma';

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
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.group, color: Colors.green),
                    ),
                    title: Text(nome,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                      onSelected: (val) {
                        switch (val) {
                          case 'renomear':
                            _mostrarDialogRenomear(context, id, nome);
                          case 'remover':
                            _confirmarDelete(context, id, nome);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'renomear',
                          child: Row(children: [
                            Icon(Icons.edit_outlined,
                                color: Colors.blueAccent, size: 18),
                            SizedBox(width: 10),
                            Text('Renomear'),
                          ]),
                        ),
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
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TurmaDetailPage(turmaId: id, turmaNome: nome),
                        ),
                      );
                      _recarregar();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogCriar(context),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Turma'),
      ),
    );
  }
}

/// [onSalvar] retorna null em caso de sucesso, ou uma mensagem de erro.
class _TurmaSheet extends StatefulWidget {
  final TextEditingController controller;
  final String titulo;
  final String labelBotao;
  final Future<String?> Function(String nome) onSalvar;

  const _TurmaSheet({
    required this.controller,
    required this.titulo,
    required this.labelBotao,
    required this.onSalvar,
  });

  @override
  State<_TurmaSheet> createState() => _TurmaSheetState();
}

class _TurmaSheetState extends State<_TurmaSheet> {
  bool _saving = false;
  String? _erro;

  Future<void> _submit() async {
    final nome = widget.controller.text.trim();
    if (nome.isEmpty) return;
    setState(() {
      _saving = true;
      _erro = null;
    });

    final erro = await widget.onSalvar(nome);

    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _saving = false;
        _erro = erro;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nome da turma',
              prefixIcon:
                  const Icon(Icons.group_outlined, color: Colors.green),
              errorText: _erro,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (_) {
              if (_erro != null) setState(() => _erro = null);
            },
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _submit();
            },
          ),
          const SizedBox(height: 20),
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
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(widget.labelBotao,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
