import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static final String _smtpEmail = dotenv.get(
    'SMTP_EMAIL',
    fallback: 'seu-email@gmail.com',
  );
  static final String _smtpPassword = dotenv.get(
    'SMTP_PASSWORD',
    fallback: 'sua-senha-de-app',
  );
  static const String _nomeRemetente = 'SATCCO App';

  static SmtpServer get _smtpServer => gmail(_smtpEmail, _smtpPassword);

  /// Envia um código de verificação de 6 dígitos para [destinatario].
  static Future<void> enviarCodigoVerificacao({
    required String destinatario,
    required String codigo,
  }) async {
    final message = Message()
      ..from = Address(_smtpEmail, _nomeRemetente)
      ..recipients.add(destinatario)
      ..subject = 'Código de verificação — SATCCO App'
      ..html =
          '''
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
          <h2 style="color: #1565C0;">SATCCO App</h2>
          <p>Use o código abaixo para confirmar o seu cadastro:</p>
          <div style="
            display: inline-block;
            font-size: 36px;
            font-weight: bold;
            letter-spacing: 10px;
            color: #1565C0;
            background: #E3F2FD;
            padding: 16px 32px;
            border-radius: 8px;
            margin: 16px 0;
          ">$codigo</div>
          <p style="color: #666;">Este código é válido por <strong>10 minutos</strong>.</p>
          <p style="color: #666; font-size: 12px;">
            Se não solicitaste este cadastro, ignora este e-mail.
          </p>
        </div>
      ''';

    await send(message, _smtpServer);
  }

  /// Envia email de convite ao aluno informando que foi adicionado a uma turma.
  static Future<void> enviarConviteAluno({
    required String destinatario,
    required String turmaNome,
  }) async {
    final message = Message()
      ..from = Address(_smtpEmail, _nomeRemetente)
      ..recipients.add(destinatario)
      ..subject = 'Convite para a turma "$turmaNome" — SATCCO App'
      ..html =
          '''
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
          <h2 style="color: #2E7D32;">SATCCO App</h2>
          <p>Você foi convidado(a) para participar da turma
             <strong>$turmaNome</strong>.</p>
          <p>Acesse o aplicativo com o seu e-mail para visualizar e responder
             as avaliações disponíveis.</p>
          <p style="color: #666; font-size: 12px;">
            Caso não reconheça este convite, pode ignorar este e-mail.
          </p>
        </div>
      ''';

    await send(message, _smtpServer);
  }

  /// Envia o relatório de notas de um formulário para o professor.
  static Future<void> enviarRelatorioFormulario({
    required String destinatario,
    required String tituloFormulario,
    required String turmaNome,
    required int totalAlunos,
    required Uint8List pdfBytes,
  }) async {
    final message = Message()
      ..from = Address(_smtpEmail, _nomeRemetente)
      ..recipients.add(destinatario)
      ..subject = 'Relatório de Notas — $tituloFormulario'
      ..html =
          '''
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
          <h2 style="color: #2E7D32;">SATCCO App</h2>
          <p>Segue em anexo o relatório de notas do formulário
             <strong>$tituloFormulario</strong>
             da turma <strong>$turmaNome</strong>.</p>
          <p>Total de alunos: <strong>$totalAlunos</strong></p>
          <p style="color: #666; font-size: 12px;">
            Consulte o PDF em anexo para mais detalhes.
          </p>
        </div>
      '''
      ..attachments = [
        StreamAttachment(
          Stream.fromIterable([pdfBytes]),
          'application/pdf',
          fileName: 'Relatorio_${tituloFormulario.replaceAll(' ', '_')}.pdf',
        ),
      ];

    await send(message, _smtpServer);
  }
}
