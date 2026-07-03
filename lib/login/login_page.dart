import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'cadastro_page.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Preencha todos os campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'SATCCO',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const Text(
                  'Sistema de Avaliação',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 50),
                CustomTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Senha',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 30),
                CustomButton(
                  text: 'ENTRAR',
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CadastroPage()),
                    );
                  },
                  child: const Text('Ainda não tem conta? Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
