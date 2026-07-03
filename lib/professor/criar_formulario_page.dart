import 'package:flutter/material.dart';
import '../widgets/question_type_icon.dart';
import '../services/api_client.dart';
import '../services/api/formularios_api.dart';
import '../services/api/perguntas_api.dart';

class CriarFormularioPage extends StatefulWidget {
  final String? formularioId;
  final String? tituloInicial;

  const CriarFormularioPage({super.key, this.formularioId, this.tituloInicial});

  @override
  State<CriarFormularioPage> createState() => _CriarFormularioPageState();
}

class _CriarFormularioPageState extends State<CriarFormularioPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();

  List<Map<String, dynamic>> _perguntas = [];
  final Map<String, bool> _selecionadas = {};
  final Map<String, TextEditingController> _pesos = {};

  bool _loading = true;
  bool _saving = false;

  bool get _editando => widget.formularioId != null;

  @override
  void initState() {
    super.initState();
    if (widget.tituloInicial != null) {
      _tituloController.text = widget.tituloInicial!;
    }
    _carregarDados();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    for (final c in _pesos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final perguntas = await PerguntasApi.listar();

    for (final p in perguntas) {
      final id = p['id'] as String;
      _selecionadas[id] = false;
      _pesos[id] = TextEditingController(text: '1');
    }

    if (_editando) {
      final detalhe = await FormulariosApi.getFormulario(widget.formularioId!);
      final existentes =
          ((detalhe['perguntas'] as List?) ?? []).cast<Map<String, dynamic>>();

      final Map<String, int> ordemSalva = {};

      for (final assoc in existentes) {
        final pid = assoc['pergunta_id'] as String;
        if (_selecionadas.containsKey(pid)) {
          _selecionadas[pid] = true;
          final peso = double.tryParse(assoc['peso'].toString())?.round() ?? 1;
          _pesos[pid]?.text = peso.toString();
          ordemSalva[pid] = (assoc['ordem'] as int?) ?? 999;
        }
      }

      perguntas.sort((a, b) {
        final aId = a['id'] as String;
        final bId = b['id'] as String;
        final aSelec = _selecionadas[aId] ?? false;
        final bSelec = _selecionadas[bId] ?? false;
        if (aSelec && bSelec) {
          return (ordemSalva[aId] ?? 999).compareTo(ordemSalva[bId] ?? 999);
        }
        if (aSelec) return -1;
        if (bSelec) return 1;
        return 0;
      });
    }

    if (!mounted) return;
    setState(() {
      _perguntas = perguntas;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final selecionadas =
        _perguntas.where((p) => _selecionadas[p['id']] == true).toList();

    if (selecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos uma pergunta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final novoTitulo = _tituloController.text.trim();

      final perguntasBody = <Map<String, dynamic>>[];
      for (var i = 0; i < selecionadas.length; i++) {
        final id = selecionadas[i]['id'] as String;
        final peso = int.tryParse(_pesos[id]?.text.trim() ?? '1') ?? 1;
        perguntasBody.add({
          'pergunta_id': id,
          'peso': peso < 0 ? 0 : peso,
          'ordem': i,
        });
      }

      String formularioId;
      if (_editando) {
        await FormulariosApi.update(widget.formularioId!, novoTitulo);
        formularioId = widget.formularioId!;
      } else {
        final criado = await FormulariosApi.create(novoTitulo);
        formularioId = criado['id'] as String;
      }

      await FormulariosApi.salvarPerguntas(formularioId, perguntasBody);

      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.status == 409 ? 'Já existe um formulário com este título.' : e.message,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_editando ? 'Editar Formulário' : 'Novo Formulário'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _loading ? null : _salvar,
              child: const Text(
                'SALVAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextFormField(
                            controller: _tituloController,
                            decoration: InputDecoration(
                              labelText: 'Título do formulário',
                              hintText: 'Ex: Avaliação teste',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe um título'
                                : null,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            _perguntas.isEmpty
                                ? 'Nenhuma pergunta criada ainda.'
                                : 'Selecione, defina os pesos e arraste para ordenar:',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),

                        if (_perguntas.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drag_handle,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Segure e arraste para reordenar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_perguntas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Vá ao Banco de Questões e crie\nperguntas primeiro.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),

                  if (_perguntas.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverReorderableList(
                        itemCount: _perguntas.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _perguntas.removeAt(oldIndex);
                            _perguntas.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final doc = _perguntas[index];
                          final id = doc['id'] as String;
                          final titulo = doc['titulo'] ?? '';
                          final tipo = doc['tipo'] ?? 'escala';
                          final selecionada = _selecionadas[id] ?? false;

                          return _buildPerguntaItem(
                            key: ValueKey(id),
                            index: index,
                            id: id,
                            titulo: titulo,
                            tipo: tipo,
                            selecionada: selecionada,
                          );
                        },
                      ),
                    ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildPerguntaItem({
    required Key key,
    required int index,
    required String id,
    required String titulo,
    required String tipo,
    required bool selecionada,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: selecionada
              ? Border.all(color: Colors.blueAccent, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 16,
                    ),
                    child: Icon(
                      Icons.drag_handle,
                      color: selecionada
                          ? Colors.blueAccent
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                Checkbox(
                  value: selecionada,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    setState(() {
                      _selecionadas[id] = val ?? false;
                    });
                  },
                ),
                QuestionTypeIcon(tipo: tipo, radius: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        questionTypeLabel(tipo),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (selecionada)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    const Text(
                      'Peso:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _pesos[id],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (v) {
                          if (!selecionada) return null;
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Min: 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '(inteiro ≥ 0)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
