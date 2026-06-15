import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/question_type_icon.dart';
import '../services/auth_service.dart';
import '../services/database/formularios_db.dart';
import '../services/database/perguntas_db.dart';
import '../services/database/turmas_db.dart';

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

  List<DocumentSnapshot> _perguntas = [];
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
    final uid = AuthService.currentUser!.uid;

    final perguntas = await PerguntasDb.getByProfessor(uid);

    for (final doc in perguntas) {
      _selecionadas[doc.id] = false;
      _pesos[doc.id] = TextEditingController(text: '1');
    }

    if (_editando) {
      final existentes = await FormulariosDb.getPerguntasSnap(
        widget.formularioId!,
      );

      final Map<String, int> ordemSalva = {};

      for (final doc in existentes.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final pid = data['pergunta_id'] as String? ?? doc.id;
        if (_selecionadas.containsKey(pid)) {
          _selecionadas[pid] = true;
          _pesos[pid]?.text = (data['peso'] ?? 1).toString();
          ordemSalva[pid] = (data['ordem'] as int?) ?? 999;
        }
      }

      perguntas.sort((a, b) {
        final aSelec = _selecionadas[a.id] ?? false;
        final bSelec = _selecionadas[b.id] ?? false;
        if (aSelec && bSelec) {
          return (ordemSalva[a.id] ?? 999).compareTo(ordemSalva[b.id] ?? 999);
        }
        if (aSelec) return -1;
        if (bSelec) return 1;
        return 0;
      });
    }

    setState(() {
      _perguntas = perguntas;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final selecionadas = _perguntas
        .where((doc) => _selecionadas[doc.id] == true)
        .toList();

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
      final uid = AuthService.currentUser!.uid;

      final jaExiste = await FormulariosDb.tituloJaExiste(
        professorId: uid,
        titulo: _tituloController.text.trim(),
        excludeId: widget.formularioId,
      );
      if (jaExiste) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Já existe um formulário com este título.'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _saving = false);
        }
        return;
      }

      final perguntasMaps = selecionadas.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final peso = int.tryParse(_pesos[doc.id]?.text.trim() ?? '1') ?? 1;
        final tipo = data['tipo'] ?? 'escala';
        return {
          'pergunta_id': doc.id,
          'titulo': data['titulo'] ?? '',
          'tipo': tipo,
          'peso': peso < 0 ? 0 : peso,
          if (tipo == 'multipla_escolha' && data['opcoes'] != null)
            'opcoes': data['opcoes'],
          if (tipo == 'multipla_escolha' && data['opcao_correta'] != null)
            'opcao_correta': data['opcao_correta'],
          if (data['resposta_correta'] != null)
            'resposta_correta': data['resposta_correta'],
        };
      }).toList();

      final novoTitulo = _tituloController.text.trim();

      await FormulariosDb.salvar(
        formularioId: widget.formularioId,
        titulo: novoTitulo,
        professorId: uid,
        perguntas: perguntasMaps,
      );

      if (_editando) {
        await TurmasDb.atualizarTituloFormulario(
          formularioId: widget.formularioId!,
          novoTitulo: novoTitulo,
          professorId: uid,
        );
      }

      if (mounted) Navigator.pop(context);
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
                          final data = doc.data() as Map<String, dynamic>;
                          final titulo = data['titulo'] ?? '';
                          final tipo = data['tipo'] ?? 'escala';
                          final selecionada = _selecionadas[doc.id] ?? false;

                          return _buildPerguntaItem(
                            key: ValueKey(doc.id),
                            index: index,
                            doc: doc,
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
    required DocumentSnapshot doc,
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
                      _selecionadas[doc.id] = val ?? false;
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
                        controller: _pesos[doc.id],
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
