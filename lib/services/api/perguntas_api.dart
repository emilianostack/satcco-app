import '../api_client.dart';

class PerguntasApi {
  static Future<List<Map<String, dynamic>>> listar() async {
    final res = await ApiClient.get('/perguntas') as List;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> add(Map<String, dynamic> dados) async =>
      await ApiClient.post('/perguntas', body: dados) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> update(String id, Map<String, dynamic> dados) async =>
      await ApiClient.patch('/perguntas/$id', body: dados) as Map<String, dynamic>;

  static Future<void> delete(String id) => ApiClient.delete('/perguntas/$id');
}
