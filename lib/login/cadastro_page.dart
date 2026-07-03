import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  String? _tipo;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipo == null) {
      _showError('Selecione o seu perfil (Professor ou Aluno).');
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();

    try {
      await AuthService.solicitarCodigo(email);
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
      return;
    } catch (e) {
      _showError(
          'Não foi possível enviar o e-mail de verificação. Verifique a conexão.');
      setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;

    final confirmado = await _mostrarDialogoVerificacao(email);
    if (!confirmado) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.createUser(
        nome: _nomeController.text.trim(),
        email: email,
        senha: _senhaController.text.trim(),
        tipo: _tipo!,
      );
      await AuthService.signOut();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Conta criada com sucesso! Faça login para continuar.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Mostra o diálogo de inserção do código.
  /// Retorna true se o utilizador verificou com sucesso.
  Future<bool> _mostrarDialogoVerificacao(String email) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerificacaoDialog(email: email),
    );
    return result == true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.blueAccent,
        title: const Text(
          'Criar Conta',
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                const Text(
                  'Qual é o seu perfil?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _PerfilCard(
                        label: 'Professor',
                        icon: Icons.school_outlined,
                        color: Colors.blueAccent,
                        selected: _tipo == 'professor',
                        onTap: () => setState(() => _tipo = 'professor'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _PerfilCard(
                        label: 'Aluno',
                        icon: Icons.person_outlined,
                        color: Colors.green,
                        selected: _tipo == 'aluno',
                        onTap: () => setState(() => _tipo = 'aluno'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'Dados pessoais',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: Colors.blueAccent),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o seu nome'
                      : null,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _senhaController,
                  label: 'Senha',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: Colors.blueAccent),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme a senha';
                    if (v != _senhaController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                CustomButton(
                  text: 'CRIAR CONTA',
                  isLoading: _isLoading,
                  onPressed: _cadastrar,
                ),

                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Já tem conta? Entrar',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificacaoDialog extends StatefulWidget {
  final String email;

  const _VerificacaoDialog({required this.email});

  @override
  State<_VerificacaoDialog> createState() => _VerificacaoDialogState();
}

class _VerificacaoDialogState extends State<_VerificacaoDialog> {
  final _codigoController = TextEditingController();
  bool _verificando = false;
  String? _erro;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    final codigo = _codigoController.text.trim();
    if (codigo.length != 6) {
      setState(() => _erro = 'O código tem 6 dígitos.');
      return;
    }

    setState(() {
      _verificando = true;
      _erro = null;
    });

    bool valido;
    try {
      valido = await AuthService.verificarCodigo(widget.email, codigo);
    } catch (e) {
      valido = false;
    }

    if (!mounted) return;

    if (valido) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _verificando = false;
        _erro = 'Código inválido ou expirado. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Column(
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 48, color: Colors.blueAccent),
          SizedBox(height: 8),
          Text(
            'Verificar e-mail',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enviámos um código de 6 dígitos para\n${widget.email}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codigoController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: const TextStyle(
                  color: Colors.grey, letterSpacing: 8, fontSize: 28),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
              errorText: _erro,
            ),
            onSubmitted: (_) => _verificar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _verificando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _verificando ? null : _verificar,
          style: FilledButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: _verificando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _PerfilCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PerfilCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 36, color: selected ? color : Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: selected ? color : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
