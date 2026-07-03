/// Usuário autenticado. Mantém os getters `uid`/`email` no mesmo formato que o
/// `firebase_auth.User` tinha, para minimizar mudanças nas telas que já os usavam.
class Usuario {
  final String uid;
  final String nome;
  final String email;
  final String tipo;

  Usuario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.tipo,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        uid: json['id'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String,
        tipo: json['tipo'] as String,
      );
}
