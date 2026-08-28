import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_hygiene_guardian/services/hygiene_scanner_engine.dart';

void main() {
  group('HygieneScannerEngine Unit Tests', () {
    late HygieneScannerEngine engine;

    setUp(() {
      engine = HygieneScannerEngine();
    });

    test('Clean device state produces 100 score and GREEN category', () {
      final rawData = {
        'osSecurity': {
          'isRooted': false,
          'usbDebuggingEnabled': false,
          'devOptionsEnabled': false,
          'isDeviceSecure': true,
        },
        'network': {
          'isProxyActive': false,
          'isVpnActive': false,
          'isWifi': true,
        },
        'apps': []
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(100));
      expect(report.riskCategory, equals('GREEN'));
      expect(report.threats, isEmpty);
    });

    test('Rooted OS applies 30 point deduction and CRITICAL severity', () {
      final rawData = {
        'osSecurity': {
          'isRooted': true,
          'usbDebuggingEnabled': false,
          'isDeviceSecure': true,
        },
        'apps': []
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(70));
      expect(report.riskCategory, equals('YELLOW'));
      expect(report.threats.length, equals(1));
      expect(report.threats.first.severity, equals(RiskSeverity.critical));
      expect(report.threats.first.remediationTarget, equals('SECURITY_SETTINGS'));
    });

    test('USB Debugging applies 15 point deduction and DEVELOPMENT_SETTINGS remediation', () {
      final rawData = {
        'osSecurity': {
          'isRooted': false,
          'usbDebuggingEnabled': true,
          'isDeviceSecure': true,
        },
        'apps': []
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(85));
      expect(report.riskCategory, equals('GREEN'));
      expect(report.threats.first.remediationTarget, equals('DEVELOPMENT_SETTINGS'));
    });

    test('Sideloaded app with Accessibility permission applies 25 point deduction and ACCESSIBILITY_SETTINGS remediation', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'apps': [
          {
            'appName': 'BankScam.apk',
            'packageName': 'com.scam.bank',
            'isSideloaded': true,
            'hasAccessibility': true,
          }
        ]
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(75));
      expect(report.threats.first.severity, equals(RiskSeverity.critical));
      expect(report.threats.first.remediationTarget, equals('ACCESSIBILITY_SETTINGS'));
      expect(report.threats.first.packageName, equals('com.scam.bank'));
    });

    test('Sideloaded app with SMS permission applies 20 point deduction', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'apps': [
          {
            'appName': 'OTPReader.apk',
            'packageName': 'com.scam.sms',
            'isSideloaded': true,
            'hasSms': true,
          }
        ]
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(80));
      expect(report.threats.first.title, contains('SMS Intercept Risk'));
    });

    test('Sideloaded app with Overlay permission applies 20 point deduction', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'apps': [
          {
            'appName': 'ScreenLocker.apk',
            'packageName': 'com.scam.overlay',
            'isSideloaded': true,
            'hasOverlay': true,
          }
        ]
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(80));
      expect(report.threats.first.title, contains('Overlay Phishing Risk'));
    });

    test('Active Proxy applies 15 point deduction', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'network': {'isProxyActive': true},
        'apps': []
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(85));
      expect(report.threats.first.title, equals('Active Proxy Interceptor'));
    });

    test('Open Wi-Fi applies 15 point deduction', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'network': {'isOpenWifi': true},
        'apps': []
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(85));
      expect(report.threats.first.title, contains('Open / Unencrypted Wi-Fi Risk'));
    });

    test('Outdated OS Security Patch applies 10 point deduction', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true, 'isPatchOutdated': true},
        'apps': []
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(90));
      expect(report.threats.first.title, contains('Outdated System Security Patch'));
    });

    test('Known Community Malware Signature applies 30 point deduction and CRITICAL severity', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'apps': [
          {
            'appName': 'Electricity Bill Update',
            'packageName': 'com.electricity.bill.pay',
            'isSideloaded': true,
          }
        ]
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(70));
      expect(report.threats.first.severity, equals(RiskSeverity.critical));
      expect(report.threats.first.title, contains('Known Malware / Phishing Match'));
    });

    test('Sideloaded Background Service applies 15 point deduction', () {
      final rawData = {
        'osSecurity': {'isDeviceSecure': true},
        'apps': [
          {
            'appName': 'BackgroundTracker',
            'packageName': 'com.track.app',
            'isSideloaded': true,
            'hasBackgroundService': true,
          }
        ]
      };

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(85));
      expect(report.threats.first.title, contains('Background Drain & Battery Risk'));
    });

    test('Cumulative score deductions clamp at 0 minimum and RED category', () {
      final rawData = {
        'osSecurity': {
          'isRooted': true, // -30
          'usbDebuggingEnabled': true, // -15
          'isDeviceSecure': false, // -10
        },
        'network': {
          'isProxyActive': true, // -15
        },
        'apps': [
          {
            'appName': 'Threat1.apk', // -25
            'isSideloaded': true,
            'hasAccessibility': true,
          },
          {
            'appName': 'Threat2.apk', // -20
            'isSideloaded': true,
            'hasSms': true,
          },
          {
            'appName': 'Threat3.apk', // -20
            'isSideloaded': true,
            'hasOverlay': true,
          }
        ]
      }; // Total deductions: 135 -> Should clamp to 0

      final report = engine.calculateReport(rawData);
      expect(report.finalScore, equals(0));
      expect(report.riskCategory, equals('RED'));
      expect(report.threats.length, equals(7));
    });

    test('HygieneReport.platformUnsupported constructs correct unsupported state', () {
      final report = HygieneReport.platformUnsupported();
      expect(report.finalScore, equals(-1));
      expect(report.riskCategory, equals('UNSUPPORTED'));
      expect(report.isError, isTrue);
      expect(report.errorMessage, contains('Android devices'));
    });

    test('HygieneReport.scanError constructs correct error state', () {
      final report = HygieneReport.scanError('Test error message');
      expect(report.finalScore, equals(-1));
      expect(report.riskCategory, equals('ERROR'));
      expect(report.isError, isTrue);
      expect(report.errorMessage, equals('Test error message'));
    });
  });
}
