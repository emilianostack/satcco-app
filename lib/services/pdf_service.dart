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
          // --- Tabela resumo ---
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
                final bgColor = i.isEven ? PdfColors.white : PdfColors.grey100;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgColor),
                  children: [
                    _cell(a['nome'] as String? ?? '—'),
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

          // --- Detalhes por aluno ---
          if (perguntas.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Respostas por Aluno',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            ...alunos.where((a) => a['respostas'] != null).expand((a) {
              final nome = a['nome'] as String? ?? '—';
              final email = a['email'] as String? ?? '—';
              final nota = a['nota'] as double?;
              final respostas =
                  List<Map<String, dynamic>>.from(a['respostas'] as List);

              return [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            nome,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.Text(
                            email,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      if (nota != null)
                        pw.Text(
                          '${nota.toStringAsFixed(1)} / 10',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: _notaColor(nota),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(5),
                    1: pw.FlexColumnWidth(5),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _cell('Pergunta', bold: true),
                        _cell('Resposta', bold: true),
                      ],
                    ),
                    ...respostas.asMap().entries.map((re) {
                      final ri = re.key;
                      final r = re.value;
                      final titulo =
                          (r['titulo'] as String?) ?? 'Pergunta ${ri + 1}';
                      final valorFmt = r['valor_formatado'] as String? ?? '—';
                      final bg = ri.isEven ? PdfColors.white : PdfColors.grey50;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: bg),
                        children: [
                          _cell(titulo),
                          _cell(valorFmt),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 14),
              ];
            }),
          ],
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
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: headerRow ? PdfColors.white : (notaColor ?? PdfColors.black),
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
