import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api/sessoes_api.dart';

class QrCodePage extends StatefulWidget {
  final String formularioId;
  final String formularioTitulo;
  final String? turmaId;

  const QrCodePage({
    super.key,
    required this.formularioId,
    required this.formularioTitulo,
    this.turmaId,
  });

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  String? _sessaoId;
  String? _sessaoToken;
  String _status = 'ativa';
  bool _loading = true;
  bool _encerrando = false;

  @override
  void initState() {
    super.initState();
    _criarSessao();
  }

  Future<void> _criarSessao() async {
    setState(() {
      _loading = true;
      _status = 'ativa';
    });

    final sessao = await SessoesApi.criar(
      formularioId: widget.formularioId,
      turmaId: widget.turmaId,
    );

    if (mounted) {
      setState(() {
        _sessaoId = sessao['id'] as String;
        _sessaoToken = sessao['token'] as String;
        _loading = false;
      });
    }
  }

  Future<void> _encerrarSessao() async {
    if (_sessaoId == null) return;
    setState(() => _encerrando = true);

    await SessoesApi.encerrar(_sessaoId!);

    if (mounted) {
      setState(() {
        _status = 'encerrada';
        _encerrando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('QR Code da Sessão'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_outlined,
                            color: Colors.blueAccent, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          widget.formularioTitulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _StatusBadge(status: _status),
                        const SizedBox(height: 24),

                        if (_status == 'ativa')
                          QrImageView(
                            data: _sessaoToken!,
                            version: QrVersions.auto,
                            size: 240,
                            backgroundColor: Colors.white,
                          )
                        else
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: 0.2,
                                child: QrImageView(
                                  data: _sessaoToken!,
                                  version: QrVersions.auto,
                                  size: 240,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.redAccent, width: 1.5),
                                ),
                                child: const Text(
                                  'SESSÃO ENCERRADA',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        Text(
                          'ID: ${_sessaoId?.substring(0, 8).toUpperCase()}...',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),

                        if (_status == 'ativa') ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Mostre este código para os alunos escanearem',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_status == 'ativa')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _encerrando ? null : _encerrarSessao,
                        icon: _encerrando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.stop_circle_outlined),
                        label: const Text('Encerrar Sessão',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),

                  if (_status == 'encerrada') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _criarSessao,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Nova Sessão',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar aos Formulários',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final ativa = status == 'ativa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: ativa ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ativa ? Colors.green : Colors.redAccent,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ativa ? Colors.green : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ativa ? 'Sessão Ativa' : 'Sessão Encerrada',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: ativa ? Colors.green.shade700 : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
