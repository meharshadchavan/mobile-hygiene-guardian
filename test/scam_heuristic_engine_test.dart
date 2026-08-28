import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_hygiene_guardian/services/scam_heuristic_engine.dart';

void main() {
  group('ScamHeuristicEngine Unit Tests', () {
    test('Clean text message returns safe clean result', () {
      const msg = 'Hi mom, I will reach home by 7 PM for dinner.';
      final result = ScamHeuristicEngine.analyzeMessage(msg);

      expect(result.isScam, isFalse);
      expect(result.riskLevel, equals(ScamRiskLevel.safe));
      expect(result.detectedRedFlags, isEmpty);
      expect(result.confidenceScore, lessThan(20));
    });

    test('Electricity Bill Scam message detected with high confidence', () {
      const msg = 'Dear Customer, your electricity power will be disconnected tonight at 9:30 PM because your previous month bill was not updated. Please contact electric officer immediately at 9876543210.';
      final result = ScamHeuristicEngine.analyzeMessage(msg);

      expect(result.isScam, isTrue);
      expect(result.category, contains('Electricity Bill Fraud'));
      expect(result.confidenceScore, greaterThanOrEqualTo(40));
      expect(result.detectedRedFlags.any((f) => f.contains('utility')), isTrue);
      expect(result.detectedRedFlags.any((f) => f.contains('urgency')), isTrue);
    });

    test('Banking / KYC Phishing message with APK link detected as critical scam', () {
      const msg = 'SBI Alert: Your YONO account is suspended. Update your PAN card immediately by downloading the update app: http://192.168.1.1/sbi_update.apk';
      final result = ScamHeuristicEngine.analyzeMessage(msg);

      expect(result.isScam, isTrue);
      expect(result.riskLevel, equals(ScamRiskLevel.criticalScam));
      expect(result.confidenceScore, greaterThanOrEqualTo(70));
      expect(result.detectedRedFlags.any((f) => f.contains('.APK')), isTrue);
      expect(result.detectedRedFlags.any((f) => f.contains('numeric IP')), isTrue);
      expect(result.detectedRedFlags.any((f) => f.contains('account suspension')), isTrue);
    });

    test('Remote Access AnyDesk Scam message detected', () {
      const msg = 'Customer care refund department: To receive your 5000 cashback, install AnyDesk app and share 9 digit code.';
      final result = ScamHeuristicEngine.analyzeMessage(msg);

      expect(result.isScam, isTrue);
      expect(result.category, contains('Remote Access'));
      expect(result.detectedRedFlags.any((f) => f.contains('remote screen-sharing')), isTrue);
    });

    test('Obfuscated scam message with symbol insertion and leetspeak detected', () {
      const msg = 'Urgent: e1ectricity b i l l unpaid. Contact e.l.e.c.t.r.i.c officer immediately.';
      final result = ScamHeuristicEngine.analyzeMessage(msg);

      expect(result.isScam, isTrue);
      expect(result.category, contains('Electricity Bill Fraud'));
      expect(result.detectedRedFlags.isNotEmpty, isTrue);
    });

    test('Empty text returns safe clean result gracefully', () {
      final result = ScamHeuristicEngine.analyzeMessage('   ');
      expect(result.isScam, isFalse);
      expect(result.riskLevel, equals(ScamRiskLevel.safe));
    });
  });
}
