import 'package:flutter/material.dart';
import '../services/api/formularios_api.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  late Future<List<_FormularioGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<void> _recarregar() async {
    final dados = await _carregar();
    if (mounted) {
      setState(() {
        _future = Future.value(dados);
      });
    }
  }

  Future<List<_FormularioGroup>> _carregar() async {
    final formularios = await FormulariosApi.listar();
    if (formularios.isEmpty) return [];

    final grupos = await Future.wait(formularios.map((f) async {
      final id = f['id'] as String;
      final titulo = f['titulo'] as String? ?? 'Sem título';
      final respostas = await FormulariosApi.listarRespostas(id);

      final logs = respostas.map((r) {
        return _RespostaLog(
          alunoNome: (r['aluno_nome'] as String?) ??
              (r['aluno_email'] as String?) ??
              'Aluno',
          alunoEmail: r['aluno_email'] as String?,
          nota: r['nota'] != null ? double.tryParse(r['nota'].toString()) : null,
          respondidoEm: r['respondido_em'] != null
              ? DateTime.parse(r['respondido_em'] as String)
              : null,
        );
      }).toList()
        ..sort((a, b) => a.alunoNome.compareTo(b.alunoNome));

      return _FormularioGroup(id: id, titulo: titulo, respostas: logs);
    }));

    grupos.sort((a, b) => a.titulo.compareTo(b.titulo));
    return grupos;
  }

  String _formatarData(DateTime dt) {
    final d = dt.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year}  ${pad(d.hour)}:${pad(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Notas'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _recarregar,
          ),
        ],
      ),
      body: FutureBuilder<List<_FormularioGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum formulário criado ainda.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _recarregar,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, i) => _buildGroup(groups[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroup(_FormularioGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.assignment_outlined,
                      color: Colors.orange.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${group.respostas.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (group.respostas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nenhuma resposta ainda.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.respostas.length,
              separatorBuilder: (_, i) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (_, j) =>
                  _buildRespostaItem(group.respostas[j]),
            ),
        ],
      ),
    );
  }

  Widget _buildRespostaItem(_RespostaLog log) {
    final nota = log.nota;
    final notaColor = nota == null
        ? Colors.grey
        : nota >= 7
            ? Colors.green
            : nota >= 5
                ? Colors.orange
                : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline,
                color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.alunoNome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (log.alunoEmail != null &&
                    log.alunoEmail != log.alunoNome)
                  Text(
                    log.alunoEmail!,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (log.respondidoEm != null)
                  Text(
                    _formatarData(log.respondidoEm!),
                    style: TextStyle(
                        fontSize: 11, color: Colors.orange.shade600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: notaColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: notaColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              nota != null ? '${nota.toStringAsFixed(1)} / 10' : 'S/N',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: notaColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioGroup {
  final String id;
  final String titulo;
  final List<_RespostaLog> respostas;

  const _FormularioGroup({
    required this.id,
    required this.titulo,
    required this.respostas,
  });
}

class _RespostaLog {
  final String alunoNome;
  final String? alunoEmail;
  final double? nota;
  final DateTime? respondidoEm;

  const _RespostaLog({
    required this.alunoNome,
    this.alunoEmail,
    this.nota,
    this.respondidoEm,
  });
}
