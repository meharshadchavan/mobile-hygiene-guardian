import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_hygiene_guardian/services/hygiene_scanner_engine.dart';
import 'package:mobile_hygiene_guardian/services/forensic_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForensicPdfService Tests', () {
    test('generateAuditReportBytes produces valid non-empty PDF bytes', () async {
      final report = HygieneReport(
        finalScore: 75,
        riskCategory: 'YELLOW',
        threats: [
          ThreatItem(
            title: 'Sideloaded BankScam.apk',
            description: 'Requests Accessibility & OTP reading permission.',
            severity: RiskSeverity.critical,
            scoreDeduction: 25,
            remediationTarget: 'ACCESSIBILITY_SETTINGS',
            packageName: 'com.scam.bank',
          ),
          ThreatItem(
            title: 'USB Debugging Enabled',
            description: 'ADB Debugging is active.',
            severity: RiskSeverity.high,
            scoreDeduction: 15,
            remediationTarget: 'DEVELOPMENT_SETTINGS',
          ),
        ],
        timestamp: DateTime.now(),
      );

      final pdfBytes = await ForensicPdfService.generateAuditReportBytes(report);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('generateAuditReportBytes produces valid PDF for clean report with 0 threats', () async {
      final cleanReport = HygieneReport(
        finalScore: 100,
        riskCategory: 'GREEN',
        threats: [],
        timestamp: DateTime.now(),
      );

      final pdfBytes = await ForensicPdfService.generateAuditReportBytes(cleanReport);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('generateAuditReportBytes handles non-ASCII localized strings safely without crashing', () async {
      final report = HygieneReport(
        finalScore: 50,
        riskCategory: 'YELLOW',
        threats: [
          ThreatItem(
            title: 'સુરક્ષા જોખમ (Threat Title)',
            description: 'સાઇડલોડ થયેલી એપ (Sideloaded App)',
            severity: RiskSeverity.high,
            scoreDeduction: 20,
            remediationTarget: 'ACCESSIBILITY_SETTINGS',
            packageName: 'com.scam.gujarati',
          ),
        ],
        timestamp: DateTime.now(),
      );

      final pdfBytes = await ForensicPdfService.generateAuditReportBytes(report);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });
  });
}
