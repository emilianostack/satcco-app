import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/api/formularios_api.dart';
import '../services/api/respostas_api.dart';
import '../services/api/sessoes_api.dart';

class ResponderFormularioPage extends StatefulWidget {
  /// Token da sessão QR. Nulo quando acedido diretamente pelo card
  /// (ex.: "Minhas Avaliações" do professor convidado).
  final String? sessaoToken;
  final String formularioId;

  /// Quando true, as respostas não são gravadas (modo de pré-visualização).
  final bool modoTeste;

  /// Quando true, o professor está respondendo como participante (respostas são gravadas).
  final bool isProfessor;

  const ResponderFormularioPage({
    super.key,
    this.sessaoToken,
    required this.formularioId,
    this.modoTeste = false,
    this.isProfessor = false,
  });

  @override
  State<ResponderFormularioPage> createState() =>
      _ResponderFormularioPageState();
}

class _ResponderFormularioPageState extends State<ResponderFormularioPage> {
  String _tituloFormulario = '';
  List<Map<String, dynamic>> _perguntas = [];
  final Map<String, dynamic> _respostas = {};
  bool _loading = true;
  bool _jaRespondeu = false;
  bool _enviando = false;
  double? _nota;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      if (!widget.modoTeste) {
        final resposta = await RespostasApi.minhaPorFormulario(widget.formularioId);
        if (resposta != null) {
          final nota =
              resposta['nota'] != null ? double.tryParse(resposta['nota'].toString()) : null;
          if (mounted) {
            setState(() { _jaRespondeu = true; _nota = nota; _loading = false; });
          }
          return;
        }
      }

      Map<String, dynamic> formulario;
      if (widget.sessaoToken != null) {
        // Fluxo QR: usa a mesma consulta pública já validada pelo scanner —
        // funciona mesmo sem o usuário ser o dono do formulário.
        final resultado = await SessoesApi.consultarPorToken(widget.sessaoToken!);
        formulario = Map<String, dynamic>.from(resultado['formulario'] as Map);
        formulario['perguntas'] = resultado['perguntas'];
      } else {
        // Fluxo direto (lista do aluno / "Minhas Avaliações" / testar): endpoint
        // liberado para quem tem acesso, não só o professor dono.
        formulario = await FormulariosApi.getFormularioParaResponder(widget.formularioId);
      }

      _tituloFormulario = formulario['titulo'] as String? ?? 'Avaliação';

      final perguntas =
          ((formulario['perguntas'] as List?) ?? []).cast<Map<String, dynamic>>();

      for (final p in perguntas) {
        final id = p['pergunta_id'] as String;
        final tipo = p['tipo'] as String;
        switch (tipo) {
          case 'escala':
            _respostas[id] = 5.0;
            break;
          case 'sim_nao':
          case 'verdadeiro_falso':
          case 'multipla_escolha':
          case 'texto':
            _respostas[id] = null;
            break;
        }
      }

      if (mounted) {
        setState(() {
          _perguntas = perguntas;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _erro = e.message; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar o formulário. Verifique a conexão.';
          _loading = false;
        });
      }
    }
  }

  /// Usada apenas no modo teste (pré-visualização, nunca persistida) — a nota
  /// de uma submissão real vem sempre calculada pelo backend.
  /// Calcula a nota automática (0–10) com base nos pesos e respostas corretas.
  /// Perguntas do tipo 'texto' e questões sem resposta correta definida não entram no cálculo.
  /// Retorna null quando nenhuma pergunta gera nota (sem avaliação automática).
  double? _calcularNota() {
    double earned = 0;
    double maxPossible = 0;

    for (final p in _perguntas) {
      final id = p['pergunta_id'] as String;
      final tipo = p['tipo'] as String;
      final peso = double.tryParse(p['peso']?.toString() ?? '1') ?? 1.0;
      final valor = _respostas[id];

      if (peso <= 0) continue;

      switch (tipo) {
        case 'escala':
          earned += ((valor as double? ?? 0.0) / 10.0) * peso;
          maxPossible += peso;
          break;

        case 'sim_nao':
        case 'verdadeiro_falso':
          final correta = p['resposta_correta'] as String?;
          if (correta != null && correta.trim().isNotEmpty) {
            if (valor == correta) earned += peso;
            maxPossible += peso;
          }
          break;

        case 'multipla_escolha':
          final correta = p['opcao_correta'];
          if (correta != null && correta != -1) {
            if (valor == correta) earned += peso;
            maxPossible += peso;
          }
          break;

        case 'texto':
          break;
      }
    }

    if (maxPossible == 0) return null;
    return double.parse(((earned / maxPossible) * 10).toStringAsFixed(1));
  }

  Future<void> _enviarRespostas() async {
    for (final p in _perguntas) {
      final id = p['pergunta_id'] as String;
      if (_respostas[id] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Responda a pergunta: "${p['titulo']}"'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _enviando = true);

    if (widget.modoTeste) {
      final nota = _calcularNota();
      if (mounted) {
        setState(() { _jaRespondeu = true; _enviando = false; _nota = nota; });
      }
      return;
    }

    try {
      final listaRespostas = _perguntas.map((p) {
        final id = p['pergunta_id'] as String;
        return {'perguntaId': id, 'valor': _respostas[id].toString()};
      }).toList();

      final resposta = await RespostasApi.submit(
        sessaoToken: widget.sessaoToken,
        formularioId: widget.sessaoToken == null ? widget.formularioId : null,
        respostas: listaRespostas,
      );

      final nota =
          resposta['nota'] != null ? double.tryParse(resposta['nota'].toString()) : null;

      if (mounted) {
        setState(() { _jaRespondeu = true; _enviando = false; _nota = nota; });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.status == 409 ? 'Você já respondeu este formulário.' : e.message),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _enviando = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _erro = null;
                      _loading = true;
                    });
                    _carregarDados();
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_jaRespondeu) return _buildSucesso();

    final corAppBar = widget.modoTeste
        ? Colors.orange
        : widget.isProfessor
            ? Colors.teal
            : Colors.green;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_tituloFormulario, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: corAppBar,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.modoTeste || widget.isProfessor,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            if (widget.modoTeste)
              Container(
                width: double.infinity,
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.science_outlined, size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Modo Teste — as respostas não serão gravadas',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _perguntas.length,
                itemBuilder: (context, index) {
                  final p = _perguntas[index];
                  return _buildPergunta(index + 1, p);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBotaoEnviar(),
    );
  }

  Widget _buildPergunta(int numero, Map<String, dynamic> p) {
    final id = p['pergunta_id'] as String;
    final titulo = p['titulo'] as String;
    final tipo = p['tipo'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.green.shade50,
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput(id, tipo, p),
        ],
      ),
    );
  }

  Widget _buildInput(String id, String tipo, Map<String, dynamic> p) {
    switch (tipo) {
      case 'escala':
        return _buildEscala(id);
      case 'sim_nao':
        return _buildSimNao(id);
      case 'verdadeiro_falso':
        return _buildVerdadeiroFalso(id);
      case 'multipla_escolha':
        return _buildMultiplaEscolha(id, p);
      case 'texto':
        return _buildTexto(id);
      default:
        return const SizedBox();
    }
  }

  Widget _buildEscala(String id) {
    final valor = (_respostas[id] as double?) ?? 5.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0', style: TextStyle(color: Colors.grey)),
            Text(
              valor.round().toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Text('10', style: TextStyle(color: Colors.grey)),
          ],
        ),
        Slider(
          value: valor,
          min: 0,
          max: 10,
          divisions: 10,
          activeColor: Colors.green,
          onChanged: (v) => setState(() => _respostas[id] = v),
        ),
      ],
    );
  }

  Widget _buildSimNao(String id) {
    return Row(
      children: [
        Expanded(child: _opcaoBtn(id, 'Sim', Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _opcaoBtn(id, 'Não', Colors.redAccent)),
      ],
    );
  }

  Widget _buildVerdadeiroFalso(String id) {
    return Row(
      children: [
        Expanded(
            child: _opcaoBtn(id, 'verdadeiro', Colors.green,
                label: 'Verdadeiro')),
        const SizedBox(width: 12),
        Expanded(
            child: _opcaoBtn(id, 'falso', Colors.redAccent, label: 'Falso')),
      ],
    );
  }

  Widget _buildMultiplaEscolha(String id, Map<String, dynamic> p) {
    final opcoes = List<String>.from(p['opcoes'] ?? []);
    return Column(
      children: List.generate(opcoes.length, (i) {
        final selecionado = _respostas[id] == i;
        return GestureDetector(
          onTap: () => setState(() => _respostas[id] = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selecionado ? Colors.green.shade50 : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selecionado ? Colors.green : Colors.grey.shade300,
                width: selecionado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selecionado
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selecionado ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opcoes[i],
                    style: TextStyle(
                      fontWeight: selecionado
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selecionado
                          ? Colors.green.shade800
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTexto(String id) {
    return TextFormField(
      maxLines: 3,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: 'Escreva a sua resposta...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (v) =>
          setState(() => _respostas[id] = v.trim().isEmpty ? null : v.trim()),
    );
  }

  Widget _opcaoBtn(String id, String valor, Color color, {String? label}) {
    final selecionado = _respostas[id] == valor;
    return GestureDetector(
      onTap: () => setState(() => _respostas[id] = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selecionado ? color.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selecionado ? color : Colors.grey.shade300,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label ?? valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selecionado ? color : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoEnviar() {
    final Color cor = widget.modoTeste
        ? Colors.orange
        : widget.isProfessor
            ? Colors.teal
            : Colors.green;
    final String labelEnviando = widget.modoTeste ? 'A calcular...' : 'A enviar...';
    final String label = widget.modoTeste ? 'Ver Resultado' : 'Enviar';
    final IconData icone =
        widget.modoTeste ? Icons.science_outlined : Icons.send_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: cor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _enviando ? null : _enviarRespostas,
          icon: _enviando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(icone),
          label: Text(
            _enviando ? labelEnviando : label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSucesso() {
    final Color cor = widget.modoTeste
        ? Colors.orange
        : widget.isProfessor
            ? Colors.teal
            : Colors.green;
    final IconData icone = widget.modoTeste
        ? Icons.science_outlined
        : widget.isProfessor
            ? Icons.school_outlined
            : Icons.check_circle_rounded;
    final String titulo = widget.modoTeste
        ? 'Resultado do Teste'
        : widget.isProfessor
            ? 'Resposta enviada!'
            : 'Avaliação enviada!';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: cor, size: 80),
              ),
              const SizedBox(height: 28),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (widget.modoTeste)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Nenhuma resposta foi gravada.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              if (_nota != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'A sua nota',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _nota!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              color: _notaColor(_nota!),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              ' / 10',
                              style: TextStyle(
                                  fontSize: 20, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else
                const Text(
                  'As suas respostas foram registadas com sucesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => (widget.modoTeste || widget.isProfessor)
                      ? Navigator.of(context).pop()
                      : Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(
                    widget.modoTeste
                        ? 'Fechar Teste'
                        : widget.isProfessor
                            ? 'Voltar'
                            : 'Voltar ao início',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _notaColor(double nota) {
    if (nota >= 7) return Colors.green;
    if (nota >= 5) return Colors.orange;
    return Colors.red;
  }
}
