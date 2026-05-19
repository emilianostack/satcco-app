import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/question_type_icon.dart';
import '../widgets/empty_state.dart';
import '../services/auth_service.dart';
import '../services/database/perguntas_db.dart';
import '../services/database/formularios_db.dart';

class PergunatasPage extends StatefulWidget {
  const PergunatasPage({super.key});

  @override
  State<PergunatasPage> createState() => _PergunatasPageState();
}

class _PergunatasPageState extends State<PergunatasPage> {
  final _tituloController = TextEditingController();
  String _tipoSelecionado = 'escala';

  List<TextEditingController> _opcoesControllers = [];
  int? _opcaoCorretaIndex;
  static const int _maxOpcoes = 10;

  String? _respostaCorretaVF;

  String? _respostaCorretaSN;

  final Map<String, String> _tiposLabel = {
    'escala': 'Escala (0 a 10)',
    'sim_nao': 'Sim / Não',
    'verdadeiro_falso': 'Verdadeiro ou Falso',
    'multipla_escolha': 'Múltipla Escolha',
    'texto': 'Texto livre',
  };

  @override
  void dispose() {
    _tituloController.dispose();
    for (final c in _opcoesControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _professorId => AuthService.currentUser!.uid;

  void _inicializarOpcoes({List<String>? existentes, int? opcaoCorreta}) {
    for (final c in _opcoesControllers) {
      c.dispose();
    }
    _opcoesControllers = existentes != null && existentes.isNotEmpty
        ? existentes.map((o) => TextEditingController(text: o)).toList()
        : [TextEditingController(), TextEditingController()];
    _opcaoCorretaIndex = opcaoCorreta;
  }

  Future<void> _salvarPergunta({String? docId}) async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) return;

    final Map<String, dynamic> dadosValidos = {
      'titulo': titulo,
      'tipo': _tipoSelecionado,
    };

    final Map<String, dynamic> dadosParaRemover = {};

    switch (_tipoSelecionado) {
      case 'multipla_escolha':
        final opcoes = _opcoesControllers
            .map((c) => c.text.trim())
            .where((o) => o.isNotEmpty)
            .toList();
        if (opcoes.length < 2) return;
        dadosValidos['opcoes'] = opcoes;
        if (_opcaoCorretaIndex != null) {
          dadosValidos['opcao_correta'] = _opcaoCorretaIndex;
        } else {
          dadosParaRemover['opcao_correta'] = FieldValue.delete();
        }
        dadosParaRemover['resposta_correta'] = FieldValue.delete();
        break;

      case 'verdadeiro_falso':
        if (_respostaCorretaVF != null) {
          dadosValidos['resposta_correta'] = _respostaCorretaVF;
        } else {
          dadosParaRemover['resposta_correta'] = FieldValue.delete();
        }
        dadosParaRemover['opcoes'] = FieldValue.delete();
        dadosParaRemover['opcao_correta'] = FieldValue.delete();
        break;

      case 'sim_nao':
        if (_respostaCorretaSN != null) {
          dadosValidos['resposta_correta'] = _respostaCorretaSN;
        } else {
          dadosParaRemover['resposta_correta'] = FieldValue.delete();
        }
        dadosParaRemover['opcoes'] = FieldValue.delete();
        dadosParaRemover['opcao_correta'] = FieldValue.delete();
        break;

      default:
        dadosParaRemover['opcoes'] = FieldValue.delete();
        dadosParaRemover['opcao_correta'] = FieldValue.delete();
        dadosParaRemover['resposta_correta'] = FieldValue.delete();
    }

    if (docId == null) {
      await PerguntasDb.add(_professorId, dadosValidos);
    } else {
      await PerguntasDb.update(docId, {...dadosValidos, ...dadosParaRemover});
    }
  }

  Future<void> _confirmarDelecao(String docId, String titulo) async {
    final nomeFormulario = await FormulariosDb.formularioQueUsaPergunta(
      _professorId,
      docId,
    );
    if (!mounted) return;

    if (nomeFormulario != null) {
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
          content: Text(
            'Esta pergunta está sendo usada no formulário '
            '"$nomeFormulario".\n\n'
            'Remova-a do formulário antes de excluí-la.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

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

    if (confirmar == true) await PerguntasDb.delete(docId);
  }

  void _abrirBottomSheet({DocumentSnapshot? doc}) {
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _tituloController.text = data['titulo'] ?? '';
      _tipoSelecionado = data['tipo'] ?? 'escala';

      if (_tipoSelecionado == 'multipla_escolha') {
        _inicializarOpcoes(
          existentes: List<String>.from(data['opcoes'] ?? []),
          opcaoCorreta: data['opcao_correta'] as int?,
        );
        _respostaCorretaVF = null;
        _respostaCorretaSN = null;
      } else if (_tipoSelecionado == 'verdadeiro_falso') {
        _respostaCorretaVF = data['resposta_correta'] as String?;
        _respostaCorretaSN = null;
        _inicializarOpcoes();
      } else if (_tipoSelecionado == 'sim_nao') {
        _respostaCorretaSN = data['resposta_correta'] as String?;
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
                    onPressed: () async {
                      await _salvarPergunta(docId: doc?.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(
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
      body: StreamBuilder<QuerySnapshot>(
        stream: PerguntasDb.watchByProfessor(_professorId),
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
              icon: Icons.quiz_outlined,
              title: 'Nenhuma pergunta ainda.',
              subtitle: 'Toque em + para adicionar.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final titulo = data['titulo'] ?? '';
              final tipo = data['tipo'] ?? 'escala';

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
                  subtitle: _buildSubtitle(data),
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
                        onPressed: () => _confirmarDelecao(doc.id, titulo),
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
