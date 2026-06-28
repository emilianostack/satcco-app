import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  /// Gera e mostra o PDF de notas de um formulário (visão do professor).
  static Future<void> gerarNotasFormulario({
    required String tituloFormulario,
    required String turmaNome,
    required List<Map<String, dynamic>> perguntas,
    required List<Map<String, dynamic>> alunos,
  }) async {
    final pdf = await _buildNotasDoc(
      tituloFormulario: tituloFormulario,
      turmaNome: turmaNome,
      perguntas: perguntas,
      alunos: alunos,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: tituloFormulario,
    );
  }

  /// Gera o PDF de notas e retorna os bytes para envio por email.
  static Future<Uint8List> gerarNotasFormularioBytes({
    required String tituloFormulario,
    required String turmaNome,
    required List<Map<String, dynamic>> perguntas,
    required List<Map<String, dynamic>> alunos,
  }) async {
    final pdf = await _buildNotasDoc(
      tituloFormulario: tituloFormulario,
      turmaNome: turmaNome,
      perguntas: perguntas,
      alunos: alunos,
    );
    return pdf.save();
  }

  static Future<pw.Document> _buildNotasDoc({
    required String tituloFormulario,
    required String turmaNome,
    required List<Map<String, dynamic>> perguntas,
    required List<Map<String, dynamic>> alunos,
  }) async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SATCCO Digital',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              tituloFormulario,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              turmaNome,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) => [
          // Tabela de Resumo (Já existia)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueAccent),
                children: [
                  _cell('Aluno', bold: true, headerRow: true),
                  _cell('Email', bold: true, headerRow: true),
                  _cell('Nota', bold: true, headerRow: true),
                  _cell('Data', bold: true, headerRow: true),
                ],
              ),
              ...alunos.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                final nota = (a['nota'] as double?);
                final data = a['data'] as DateTime?;
                final isProfessor = (a['is_professor'] as bool?) == true;
                final bgColor = isProfessor
                    ? PdfColors.teal50
                    : (i.isEven ? PdfColors.white : PdfColors.grey100);
                final displayName = isProfessor
                    ? '${a['nome'] ?? '—'} (Professor)'
                    : (a['nome'] as String? ?? '—');
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgColor),
                  children: [
                    _cell(displayName,
                        bold: isProfessor,
                        professorColor: isProfessor ? PdfColors.teal800 : null),
                    _cell(a['email'] as String? ?? '—'),
                    _cell(
                      nota != null ? '${nota.toStringAsFixed(1)} / 10' : 'S/N',
                      notaColor: nota != null ? _notaColor(nota) : null,
                    ),
                    _cell(data != null ? _formatData(data) : '—'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Total: ${alunos.length} aluno${alunos.length != 1 ? 's' : ''}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),

          // NOVA SEÇÃO: Detalhamento de Respostas
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(
              'Detalhamento de Respostas',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),

          ...alunos.expand((a) {
            final respostas = a['respostas'] as List<dynamic>?;
            if (respostas == null || respostas.isEmpty) {
              return [pw.SizedBox()];
            }

            final isProfessor = (a['is_professor'] as bool?) == true;
            final headerLabel =
                isProfessor ? 'Professor: ${a['nome'] ?? '—'}' : 'Aluno: ${a['nome'] ?? '—'}';
            final headerColor =
                isProfessor ? PdfColors.teal800 : PdfColors.blueAccent;
            final bgColor = isProfessor ? PdfColors.teal50 : PdfColors.grey50;

            return [
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: bgColor,
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      headerLabel,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: headerColor,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ...respostas.map((r) {
                      final respMap = r as Map<String, dynamic>;
                      final titulo = respMap['titulo']?.toString() ?? 'Pergunta sem título';
                      final valor = respMap['valor_formatado']?.toString() ??
                          respMap['valor']?.toString() ??
                          respMap['resposta']?.toString() ??
                          'Sem resposta';

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Q: $titulo',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'R: $valor',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ];
          }),
        ],
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
      ),
    );

    return pdf;
  }

  /// Abre o comprovante individual do aluno no visualizador de impressão.
  static Future<void> gerarComprovanteAluno({
    required String tituloFormulario,
    required String alunoNome,
    required String alunoEmail,
    required double? nota,
    required DateTime? respondidoEm,
  }) async {
    final pdf = await _buildComprovanteDoc(
      tituloFormulario: tituloFormulario,
      alunoNome: alunoNome,
      alunoEmail: alunoEmail,
      nota: nota,
      respondidoEm: respondidoEm,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Comprovante - $tituloFormulario',
    );
  }

  /// Gera o comprovante individual e retorna os bytes para envio por email.
  static Future<Uint8List> gerarComprovanteBytesAluno({
    required String tituloFormulario,
    required String alunoNome,
    required String alunoEmail,
    required double? nota,
    required DateTime? respondidoEm,
  }) async {
    final pdf = await _buildComprovanteDoc(
      tituloFormulario: tituloFormulario,
      alunoNome: alunoNome,
      alunoEmail: alunoEmail,
      nota: nota,
      respondidoEm: respondidoEm,
    );
    return pdf.save();
  }

  static Future<pw.Document> _buildComprovanteDoc({
    required String tituloFormulario,
    required String alunoNome,
    required String alunoEmail,
    required double? nota,
    required DateTime? respondidoEm,
  }) async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    final notaColor = nota == null
        ? PdfColors.grey600
        : nota >= 7
        ? PdfColors.green700
        : nota >= 5
        ? PdfColors.orange700
        : PdfColors.red700;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SATCCO Digital',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Comprovante de Avaliação',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 24),

            pw.Text(
              'Formulário',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              tituloFormulario,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 24),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Aluno',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        alunoNome,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        alunoEmail,
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (respondidoEm != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Data',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _formatData(respondidoEm),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 40),

            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 28,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: notaColor, width: 2),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(12),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Nota Final',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      nota != null
                          ? '${nota.toStringAsFixed(1)} / 10'
                          : 'Sem nota automática',
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: notaColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    bool headerRow = false,
    PdfColor? notaColor,
    PdfColor? professorColor,
  }) {
    final PdfColor color;
    if (headerRow) {
      color = PdfColors.white;
    } else if (notaColor != null) {
      color = notaColor;
    } else if (professorColor != null) {
      color = professorColor;
    } else {
      color = PdfColors.black;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static String _formatData(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.day)}/${pad(dt.month)}/${dt.year}';
  }

  static PdfColor _notaColor(double nota) {
    if (nota >= 7) return PdfColors.green700;
    if (nota >= 5) return PdfColors.orange700;
    return PdfColors.red700;
  }
}
