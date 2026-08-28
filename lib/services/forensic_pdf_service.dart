import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'hygiene_scanner_engine.dart';

class ForensicPdfService {
  static String _sanitizeText(String input) {
    // Replaces characters outside Latin-1 printable range with ASCII equivalents or removes them to prevent font crash
    return input.replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
  }

  static Future<Uint8List> generateAuditReportBytes(HygieneReport report) async {
    final pdf = pw.Document();

    final scoreColor = report.finalScore >= 80
        ? PdfColors.green700
        : (report.finalScore >= 50 ? PdfColors.amber700 : PdfColors.red700);

    final riskStatus = report.finalScore >= 80
        ? 'SECURE / OPTIMAL'
        : (report.finalScore >= 50 ? 'WARNING / MODERATE RISK' : 'CRITICAL THREAT DETECTED');

    final dateStr = report.timestamp.toIso8601String().replaceAll('T', ' ').substring(0, 19);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GUJARAT POLICE CYBER CRIME BRANCH',
                        style: pw.TextStyle(
                          color: PdfColors.amber,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Mobile Device Security & Cyber Hygiene Audit Report',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'HELPLINE: 1930',
                      style: pw.TextStyle(
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Metadata Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Audit Timestamp: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('Classification: Official Citizen Audit', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Score Summary Card
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: scoreColor, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        '${report.finalScore} / 100',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      pw.Text('Device Hygiene Score', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(height: 40, width: 1, color: PdfColors.grey400),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Security Posture:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(
                        riskStatus,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      pw.Text('Threats Identified: ${report.threats.length}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Threat Forensics Section
            pw.Text(
              'FORENSIC THREAT BREAKDOWN',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 8),

            if (report.threats.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'No security vulnerabilities or indicators of compromise detected. Device security posture is clean.',
                  style: const pw.TextStyle(color: PdfColors.green800, fontSize: 10),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['#', 'Threat Title', 'Severity', 'Target Package / Setting', 'Score Deduction'],
                data: List<List<String>>.generate(report.threats.length, (index) {
                  final t = report.threats[index];
                  return [
                    '${index + 1}',
                    _sanitizeText(t.title),
                    t.severity.name.toUpperCase(),
                    _sanitizeText(t.packageName ?? t.remediationTarget),
                    '-${t.scoreDeduction} pts',
                  ];
                }),
              ),
            pw.SizedBox(height: 20),

            // Gujarat Police Cyber Advisory Box
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                border: pw.Border.all(color: PdfColors.blueGrey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'GUJARAT POLICE CYBER CRIME ADVISORY',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Bullet(text: 'If you have been defrauded, call National Cyber Crime Helpline 1930 immediately to freeze financial transactions during the golden hour.', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Never download APK applications received via WhatsApp, SMS, or Telegram messages.', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Never enable Accessibility Service permissions for non-PlayStore applications.', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Official Cyber Crime Reporting Portal: www.cybercrime.gov.in', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by Mobile Hygiene Guardian — Kanad S.H.I.E.L.D.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> exportAndShareReport(HygieneReport report) async {
    final pdfBytes = await generateAuditReportBytes(report);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Gujarat_Police_Mobile_Hygiene_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
