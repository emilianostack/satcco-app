import 'package:flutter/material.dart';
import 'formularios_page.dart';
import 'historico_page.dart';
import 'perguntas_page.dart';
import 'turmas_page.dart';
import '../services/auth_service.dart';
import '../services/database/usuarios_db.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _nomeProfessor;

  @override
  void initState() {
    super.initState();
    _carregarNome();
  }

  Future<void> _carregarNome() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    final doc = await UsuariosDb.getUsuario(uid);
    final nome = (doc.data() as Map<String, dynamic>?)?['nome'] as String?;
    if (mounted && nome != null) setState(() => _nomeProfessor = nome);
  }

  @override
  Widget build(BuildContext context) {
    final raw = _nomeProfessor ?? AuthService.currentUser?.email ?? 'Usuário';
    final displayName = raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1).toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('SATCCO App'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: AuthService.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bem-vindo,',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuTile(
                    context,
                    title: 'Formulários',
                    icon: Icons.add_task_rounded,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FormulariosPage(),
                      ),
                    ),
                  ),
                  _buildMenuTile(
                    context,
                    title: 'Histórico',
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoricoPage()),
                    ),
                  ),
                  _buildMenuTile(
                    context,
                    title: 'Alunos',
                    icon: Icons.people_alt_outlined,
                    color: Colors.green,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TurmasPage()),
                    ),
                  ),
                  _buildMenuTile(
                    context,
                    title: 'Banco de Questões',
                    icon: Icons.quiz_outlined,
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PergunatasPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
