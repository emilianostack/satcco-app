import 'package:flutter/material.dart';
import '../widgets/question_type_icon.dart';
import '../widgets/empty_state.dart';
import '../services/api_client.dart';
import '../services/api/perguntas_api.dart';
import '../services/route_observer.dart';

class PergunatasPage extends StatefulWidget {
  const PergunatasPage({super.key});

  @override
  State<PergunatasPage> createState() => _PergunatasPageState();
}

class _PergunatasPageState extends State<PergunatasPage> with RouteAware {
  final _tituloController = TextEditingController();
  String _tipoSelecionado = 'escala';

  List<TextEditingController> _opcoesControllers = [];
  int? _opcaoCorretaIndex;
  static const int _maxOpcoes = 10;

  String? _respostaCorretaVF;

  String? _respostaCorretaSN;

  late Future<List<Map<String, dynamic>>> _future;

  /// Incrementado a cada ação que deveria atualizar `_future` — evita que um
  /// GET mais antigo, ainda em voo, sobrescreva com dados desatualizados o
  /// resultado de uma ação mais recente (ex.: criar/remover).
  int _reqGen = 0;

  final Map<String, String> _tiposLabel = {
    'escala': 'Escala (0 a 10)',
    'sim_nao': 'Sim / Não',
    'verdadeiro_falso': 'Verdadeiro ou Falso',
    'multipla_escolha': 'Múltipla Escolha',
    'texto': 'Texto livre',
  };

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

  /// Chamado sempre que a rota empilhada por cima desta é fechada (ex.: o
  /// bottom sheet de nova/editar pergunta) — reforça o recarregamento mesmo
  /// que o fluxo de salvar não dispare corretamente.
  @override
  void didPopNext() => _recarregar();

  Future<List<Map<String, dynamic>>> _carregar() async {
    final perguntas = await PerguntasApi.listar();
    perguntas.sort((a, b) =>
        (a['criado_em'] as String).compareTo(b['criado_em'] as String));
    return perguntas;
  }

  /// Busca a lista nova ANTES de trocar `_future` — assim, se o reload falhar
  /// (rede instável), a lista antiga continua na tela em vez de sumir atrás
  /// de um erro. A ação que disparou o reload (criar/editar/remover) já
  /// terá sido concluída com sucesso nesse ponto.
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

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _tituloController.dispose();
    for (final c in _opcoesControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _inicializarOpcoes({List<String>? existentes, int? opcaoCorreta}) {
    for (final c in _opcoesControllers) {
      c.dispose();
    }
    _opcoesControllers = existentes != null && existentes.isNotEmpty
        ? existentes.map((o) => TextEditingController(text: o)).toList()
        : [TextEditingController(), TextEditingController()];
    _opcaoCorretaIndex = opcaoCorreta;
  }

  Future<void> _salvarPergunta({String? id}) async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) return;

    final Map<String, dynamic> body = {
      'titulo': titulo,
      'tipo': _tipoSelecionado,
    };

    switch (_tipoSelecionado) {
      case 'multipla_escolha':
        final opcoes = _opcoesControllers
            .map((c) => c.text.trim())
            .where((o) => o.isNotEmpty)
            .toList();
        if (opcoes.length < 2) return;
        body['opcoes'] = opcoes;
        body['opcaoCorreta'] = _opcaoCorretaIndex;
        body['respostaCorreta'] = null;
        break;

      case 'verdadeiro_falso':
        body['respostaCorreta'] = _respostaCorretaVF;
        body['opcoes'] = null;
        body['opcaoCorreta'] = null;
        break;

      case 'sim_nao':
        body['respostaCorreta'] = _respostaCorretaSN;
        body['opcoes'] = null;
        body['opcaoCorreta'] = null;
        break;

      default:
        body['opcoes'] = null;
        body['opcaoCorreta'] = null;
        body['respostaCorreta'] = null;
    }

    if (id == null) {
      final createBody = {...body}..removeWhere((_, v) => v == null);
      await PerguntasApi.add(createBody);
    } else {
      await PerguntasApi.update(id, body);
    }
    await _recarregar();
  }

  Future<void> _confirmarDelecao(String id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover pergunta'),
        content: Text('Deseja remover "$titulo"?'),
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

    if (confirmar != true) return;

    try {
      await PerguntasApi.delete(id);
      // Remove da lista já em memória imediatamente, sem esperar um novo GET
      // — evita qualquer atraso/inconsistência de rede fazendo o item
      // removido parecer "ainda estar lá". Bump do gen ANTES de ler `_future`
      // invalida qualquer reload mais antigo ainda em voo.
      final gen = ++_reqGen;
      final atual = await _future;
      if (mounted && gen == _reqGen) {
        setState(() {
          _future = Future.value(atual.where((p) => p['id'] != id).toList());
        });
      }
      _recarregar();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Pergunta em uso'),
              ],
            ),
            content: const Text(
              'Esta pergunta está sendo usada em um ou mais formulários.\n\n'
              'Remova-a do(s) formulário(s) antes de excluí-la.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirBottomSheet({Map<String, dynamic>? doc}) {
    if (doc != null) {
      _tituloController.text = doc['titulo'] ?? '';
      _tipoSelecionado = doc['tipo'] ?? 'escala';

      if (_tipoSelecionado == 'multipla_escolha') {
        _inicializarOpcoes(
          existentes: List<String>.from(doc['opcoes'] ?? []),
          opcaoCorreta: doc['opcao_correta'] as int?,
        );
        _respostaCorretaVF = null;
        _respostaCorretaSN = null;
      } else if (_tipoSelecionado == 'verdadeiro_falso') {
        _respostaCorretaVF = doc['resposta_correta'] as String?;
        _respostaCorretaSN = null;
        _inicializarOpcoes();
      } else if (_tipoSelecionado == 'sim_nao') {
        _respostaCorretaSN = doc['resposta_correta'] as String?;
        _respostaCorretaVF = null;
        _inicializarOpcoes();
      } else {
        _inicializarOpcoes();
        _respostaCorretaVF = null;
        _respostaCorretaSN = null;
      }
    } else {
      _tituloController.clear();
      _tipoSelecionado = 'escala';
      _inicializarOpcoes();
      _respostaCorretaVF = null;
      _respostaCorretaSN = null;
    }

    var salvando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc == null ? 'Nova Pergunta' : 'Editar Pergunta',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _tituloController,
                          autofocus: true,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Enunciado da pergunta',
                            hintText: 'Insira sua pergunta aqui',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          key: ValueKey(_tipoSelecionado),
                          initialValue: _tipoSelecionado,
                          decoration: InputDecoration(
                            labelText: 'Tipo de resposta',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: _tiposLabel.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                _tipoSelecionado = val;
                                _respostaCorretaVF = null;
                                _respostaCorretaSN = null;
                                if (val == 'multipla_escolha') {
                                  _inicializarOpcoes();
                                }
                              });
                              setState(() {
                                _tipoSelecionado = val;
                                _respostaCorretaSN = null;
                              });
                            }
                          },
                        ),

                        if (_tipoSelecionado == 'sim_nao') ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Resposta correta (opcional):',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Deixe em branco para questão subjetiva (sem nota automática).',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _vfCard(
                                  label: 'Sim',
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                  selected: _respostaCorretaSN == 'Sim',
                                  onTap: () => setModalState(() {
                                    _respostaCorretaSN =
                                        _respostaCorretaSN == 'Sim'
                                        ? null
                                        : 'Sim';
                                    setState(
                                      () => _respostaCorretaSN =
                                          _respostaCorretaSN,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _vfCard(
                                  label: 'Não',
                                  icon: Icons.cancel_outlined,
                                  color: Colors.redAccent,
                                  selected: _respostaCorretaSN == 'Não',
                                  onTap: () => setModalState(() {
                                    _respostaCorretaSN =
                                        _respostaCorretaSN == 'Não'
                                        ? null
                                        : 'Não';
                                    setState(
                                      () => _respostaCorretaSN =
                                          _respostaCorretaSN,
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (_tipoSelecionado == 'verdadeiro_falso') ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Resposta correta (opcional):',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Deixe em branco para questão subjetiva (sem nota automática).',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _vfCard(
                                  label: 'Verdadeiro',
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                  selected: _respostaCorretaVF == 'verdadeiro',
                                  onTap: () => setModalState(() {
                                    _respostaCorretaVF =
                                        _respostaCorretaVF == 'verdadeiro'
                                            ? null
                                            : 'verdadeiro';
                                    setState(
                                      () => _respostaCorretaVF =
                                          _respostaCorretaVF,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _vfCard(
                                  label: 'Falso',
                                  icon: Icons.cancel_outlined,
                                  color: Colors.redAccent,
                                  selected: _respostaCorretaVF == 'falso',
                                  onTap: () => setModalState(() {
                                    _respostaCorretaVF =
                                        _respostaCorretaVF == 'falso'
                                            ? null
                                            : 'falso';
                                    setState(
                                      () => _respostaCorretaVF =
                                          _respostaCorretaVF,
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (_tipoSelecionado == 'multipla_escolha') ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                'Opções de resposta',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_opcoesControllers.length}/$_maxOpcoes',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.radio_button_checked,
                                size: 13,
                                color: _opcaoCorretaIndex != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _opcaoCorretaIndex != null
                                    ? 'Opção ${_opcaoCorretaIndex! + 1} marcada como correta'
                                    : 'Toque no ○ para marcar a correta (opcional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _opcaoCorretaIndex != null
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RadioGroup<int>(
                            groupValue: _opcaoCorretaIndex,
                            onChanged: (val) {
                              setModalState(() => _opcaoCorretaIndex = val);
                              setState(() => _opcaoCorretaIndex = val);
                            },
                            child: Column(
                              children: List.generate(
                                _opcoesControllers.length,
                                (i) {
                                  final isCorreta = _opcaoCorretaIndex == i;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Radio<int>(value: i),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _opcoesControllers[i],
                                            decoration: InputDecoration(
                                              hintText: 'Opção ${i + 1}',
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: isCorreta
                                                    ? const BorderSide(
                                                        color: Colors.green,
                                                        width: 1.5,
                                                      )
                                                    : const BorderSide(
                                                        color: Colors.grey,
                                                      ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: isCorreta
                                                    ? const BorderSide(
                                                        color: Colors.green,
                                                        width: 1.5,
                                                      )
                                                    : BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                              ),
                                              filled: true,
                                              fillColor: isCorreta
                                                  ? Colors.green.shade50
                                                  : Colors.grey[50],
                                              suffixIcon: isCorreta
                                                  ? const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 18,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (_opcoesControllers.length > 2)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle,
                                              color: Colors.redAccent,
                                              size: 22,
                                            ),
                                            onPressed: () {
                                              setModalState(() {
                                                _opcoesControllers[i].dispose();
                                                _opcoesControllers.removeAt(i);
                                                if (_opcaoCorretaIndex == i) {
                                                  _opcaoCorretaIndex = null;
                                                } else if (_opcaoCorretaIndex !=
                                                        null &&
                                                    _opcaoCorretaIndex! > i) {
                                                  _opcaoCorretaIndex =
                                                      _opcaoCorretaIndex! - 1;
                                                }
                                              });
                                              setState(() {});
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_opcoesControllers.length < _maxOpcoes)
                            TextButton.icon(
                              onPressed: () => setModalState(
                                () => _opcoesControllers.add(
                                  TextEditingController(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.deepPurple,
                              ),
                              label: const Text(
                                'Adicionar opção',
                                style: TextStyle(color: Colors.deepPurple),
                              ),
                            ),
                          if (_opcoesControllers.length >= _maxOpcoes)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Limite de 10 opções atingido.',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: salvando
                        ? null
                        : () async {
                            setModalState(() => salvando = true);
                            try {
                              await _salvarPergunta(id: doc?['id'] as String?);
                              if (context.mounted) Navigator.pop(context);
                            } on ApiException catch (e) {
                              setModalState(() => salvando = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.message),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => salvando = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Não foi possível salvar. Verifique a conexão.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    child: salvando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            doc == null ? 'ADICIONAR' : 'SALVAR',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Banco de Questões'),
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
                    icon: Icons.quiz_outlined,
                    title: 'Nenhuma pergunta ainda.',
                    subtitle: 'Toque em + para adicionar.',
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
                final titulo = doc['titulo'] ?? '';
                final tipo = doc['tipo'] ?? 'escala';

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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: QuestionTypeIcon(tipo: tipo),
                    title: Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: _buildSubtitle(doc),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blueAccent,
                          ),
                          tooltip: 'Editar',
                          onPressed: () => _abrirBottomSheet(doc: doc),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Remover',
                          onPressed: () => _confirmarDelecao(id, titulo),
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
        onPressed: () => _abrirBottomSheet(),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Pergunta'),
      ),
    );
  }

  Widget _vfCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(Map<String, dynamic> data) {
    final tipo = data['tipo'] as String? ?? 'escala';

    if (tipo == 'multipla_escolha') {
      final opcoes = List<String>.from(data['opcoes'] ?? []);
      final correta = data['opcao_correta'] as int?;
      final label = '${questionTypeLabel(tipo)} • ${opcoes.length} opções';

      if (correta != null && correta < opcoes.length) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 12, color: Colors.green),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'Correta: "${opcoes[correta]}"',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );
      }
      return Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    if (tipo == 'sim_nao') {
      final resposta = data['resposta_correta'] as String?;
      if (resposta == null) {
        return Text(
          questionTypeLabel(tipo),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTypeLabel(tipo),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Row(
            children: [
              Icon(
                resposta == 'Sim' ? Icons.check_circle : Icons.cancel,
                size: 12,
                color: resposta == 'Sim' ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(width: 3),
              Text(
                'Correta: $resposta',
                style: TextStyle(
                  fontSize: 12,
                  color: resposta == 'Sim' ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (tipo == 'verdadeiro_falso') {
      final resposta = data['resposta_correta'] as String?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTypeLabel(tipo),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (resposta != null)
            Row(
              children: [
                Icon(
                  resposta == 'verdadeiro' ? Icons.check_circle : Icons.cancel,
                  size: 12,
                  color: resposta == 'verdadeiro'
                      ? Colors.green
                      : Colors.redAccent,
                ),
                const SizedBox(width: 3),
                Text(
                  'Correta: ${resposta == 'verdadeiro' ? 'Verdadeiro' : 'Falso'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: resposta == 'verdadeiro'
                        ? Colors.green
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Text(
      questionTypeLabel(tipo),
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}
