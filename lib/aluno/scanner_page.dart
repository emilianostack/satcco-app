import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'responder_formulario_page.dart';
import '../services/api_client.dart';
import '../services/api/sessoes_api.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processando) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _processando = true);
    await _controller.stop();

    try {
      final resultado = await SessoesApi.consultarPorToken(rawValue);
      final sessao = resultado['sessao'] as Map<String, dynamic>;
      final formularioId = sessao['formulario_id'] as String;

      if (!mounted) return;
      // Empilha (não substitui) e só fecha o scanner depois que a página de
      // resposta for encerrada — usar pushReplacement aqui completaria a
      // promise do push original (aguardada por quem abriu o scanner) no
      // momento da troca de tela, antes do aluno responder, fazendo o
      // recarregamento da lista acontecer cedo demais (ainda como pendente).
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResponderFormularioPage(
            sessaoToken: rawValue,
            formularioId: formularioId,
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      _mostrarErro(e.status == 404
          ? 'QR Code inválido ou sessão encerrada.'
          : e.message);
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao validar sessão. Tente novamente.');
    }
  }

  void _mostrarErro(String msg) {
    setState(() => _processando = false);
    _controller.start();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR Code'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Lanterna',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  _Corner(top: true, left: true),
                  _Corner(top: true, left: false),
                  _Corner(top: false, left: true),
                  _Corner(top: false, left: false),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_processando)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  const Icon(Icons.qr_code_scanner,
                      color: Colors.white70, size: 32),
                const SizedBox(height: 12),
                Text(
                  _processando
                      ? 'A validar sessão...'
                      : 'Aponte para o QR Code do professor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;

  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(12) : Radius.zero,
            topRight: top && !left ? const Radius.circular(12) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(12) : Radius.zero,
            bottomRight:
                !top && !left ? const Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
