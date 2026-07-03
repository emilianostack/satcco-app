import 'package:flutter/material.dart';
import 'criar_formulario_page.dart';
import '../widgets/empty_state.dart';
import '../services/api/formularios_api.dart';
import '../services/route_observer.dart';
import '../aluno/responder_formulario_page.dart';

class FormulariosPage extends StatefulWidget {
  const FormulariosPage({super.key});

  @override
  State<FormulariosPage> createState() => _FormulariosPageState();
}

class _FormulariosPageState extends State<FormulariosPage> with RouteAware {
  late Future<List<Map<String, dynamic>>> _future;

  /// Incrementado a cada ação que deveria atualizar `_future` — como agora
  /// existem vários gatilhos de recarregamento (ação explícita, didPopNext,
  /// pull-to-refresh), pode haver mais de um GET em voo ao mesmo tempo; sem
  /// isso, uma resposta mais antiga que chega depois de uma mais nova
  /// sobrescreveria o estado correto com dados desatualizados.
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
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

  /// Chamado sempre que a rota empilhada por cima desta é fechada (ex.:
  /// voltar de "Novo Formulário") — garante que a lista recarregue mesmo se
  /// a tela filha usar pushReplacement/popUntil, o que quebraria um simples
  /// `Navigator.push(...).then(...)`.
  @override
  void didPopNext() => _recarregar();

  Future<List<Map<String, dynamic>>> _carregar() async {
    final formularios = await FormulariosApi.listar();
    formularios.sort((a, b) =>
        (a['criado_em'] as String).compareTo(b['criado_em'] as String));
    return formularios;
  }

  /// Busca a lista nova ANTES de trocar `_future` — assim, se o reload falhar
  /// (rede instável), a lista antiga continua na tela em vez de sumir atrás
  /// de um erro.
  Future<void> _recarregar() async {
    final gen = ++_reqGen;
    try {
      final dados = await _carregar();
      if (mounted && gen == _reqGen) {
        setState(() {
          _future = Future.value(dados);
        });
      }
    } catch (_) {
      // mantém a lista atual; o usuário pode puxar para atualizar depois.
    }
  }

  Future<void> _confirmarDelecao(
      BuildContext context, String id, String titulo) async {
    final respostas = await FormulariosApi.listarRespostas(id);
    if (respostas.isNotEmpty) {
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

    if (confirmar == true) {
      await FormulariosApi.delete(id);
      // Remove da lista já em memória imediatamente, sem esperar um novo GET.
      // Bump do gen ANTES de ler `_future` invalida qualquer reload mais
      // antigo que ainda esteja em voo, evitando que ele chegue depois e
      // sobrescreva esta remoção com dados desatualizados.
      final gen = ++_reqGen;
      final atual = await _future;
      if (mounted && gen == _reqGen) {
        setState(() {
          _future = Future.value(atual.where((f) => f['id'] != id).toList());
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
        title: const Text('Formulários de Avaliação'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
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

            final docs = snapshot.data ?? [];

            if (docs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'Nenhum formulário ainda.',
                    subtitle: 'Toque em + para criar o primeiro.',
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final id = doc['id'] as String;
                final titulo = doc['titulo'] ?? 'Sem título';
                final totalPerguntas = doc['total_perguntas'] ?? 0;

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
                                      formularioId: id,
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
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CriarFormularioPage(
                                      formularioId: id,
                                      tituloInicial: titulo,
                                    ),
                                  ),
                                );
                                _recarregar();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: 'Remover',
                              onPressed: () =>
                                  _confirmarDelecao(context, id, titulo),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CriarFormularioPage(),
            ),
          );
          _recarregar();
        },
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Formulário'),
      ),
    );
  }
}
