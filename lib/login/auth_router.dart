import 'package:flutter/material.dart';
import '../professor/home_page.dart';
import '../aluno/home_aluno_page.dart';
import '../services/usuario.dart';

class AuthRouter extends StatelessWidget {
  final Usuario user;

  const AuthRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.tipo == 'aluno') return const HomeAlunoPage();
    return const HomePage();
  }
}
