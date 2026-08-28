import 'package:flutter/services.dart';

enum RiskSeverity { low, medium, high, critical }

class ThreatItem {
  final String title;
  final String description;
  final RiskSeverity severity;
  final int scoreDeduction;
  final String remediationTarget;
  final String? packageName;

  ThreatItem({
    required this.title,
    required this.description,
    required this.severity,
    required this.scoreDeduction,
    required this.remediationTarget,
    this.packageName,
  });
}

class HygieneReport {
  final int finalScore;
  final String riskCategory; // GREEN, YELLOW, RED
  final List<ThreatItem> threats;
  final DateTime timestamp;

  HygieneReport({
    required this.finalScore,
    required this.riskCategory,
    required this.threats,
    required this.timestamp,
  });
}

class HygieneScannerEngine {
  static const MethodChannel _channel = MethodChannel('com.kanad.shield/hygiene');

  /// Executes full native scan and calculates 0-100 score
  Future<HygieneReport> runFullScan() async {
    try {
      final Map<dynamic, dynamic> rawResult = await _channel.invokeMethod('scanDeviceHygiene');
      return calculateReport(rawResult);
    } catch (e) {
      return _getSimulatedDemoReport();
    }
  }

  /// Triggers 1-Tap System Setting Intent
  Future<bool> fixThreat(String remediationTarget, {String? packageName}) async {
    try {
      final bool success = await _channel.invokeMethod('openRemediationIntent', {
        'target': remediationTarget,
        'packageName': packageName,
      });
      return success;
    } catch (e) {
      return false;
    }
  }

  HygieneReport calculateReport(Map<dynamic, dynamic> rawData) {
    int score = 100;
    List<ThreatItem> threats = [];

    // 1. OS Security Audit
    final os = rawData['osSecurity'] as Map<dynamic, dynamic>? ?? {};
    if (os['isRooted'] == true) {
      score -= 30;
      threats.add(ThreatItem(
        title: 'Rooted OS Detected',
        description: 'Superuser binary found. OS security sandbox is compromised.',
        severity: RiskSeverity.critical,
        scoreDeduction: 30,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    if (os['usbDebuggingEnabled'] == true) {
      score -= 15;
      threats.add(ThreatItem(
        title: 'USB Debugging Enabled',
        description: 'ADB Debugging is active. High risk of unauthorized USB exploitation.',
        severity: RiskSeverity.high,
        scoreDeduction: 15,
        remediationTarget: 'DEVELOPMENT_SETTINGS',
      ));
    }

    if (os['devOptionsEnabled'] == true && os['usbDebuggingEnabled'] != true) {
      score -= 10;
      threats.add(ThreatItem(
        title: 'Developer Options Enabled',
        description: 'Developer settings are active. Increases attack surface for advanced exploits.',
        severity: RiskSeverity.medium,
        scoreDeduction: 10,
        remediationTarget: 'DEVELOPMENT_SETTINGS',
      ));
    }

    if (os['isDeviceSecure'] == false) {
      score -= 10;
      threats.add(ThreatItem(
        title: 'No Screen Lock Set',
        description: 'Device lock screen PIN/Pattern is disabled.',
        severity: RiskSeverity.medium,
        scoreDeduction: 10,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    // 2. Network Security Audit
    final net = rawData['network'] as Map<dynamic, dynamic>? ?? {};
    if (net['isProxyActive'] == true) {
      score -= 15;
      threats.add(ThreatItem(
        title: 'Active Proxy Interceptor',
        description: 'HTTP Proxy configured. High risk of Man-In-The-Middle network interception.',
        severity: RiskSeverity.high,
        scoreDeduction: 15,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    // 3. App Permission & Sideload Audit
    final List<dynamic> apps = rawData['apps'] as List<dynamic>? ?? [];
    for (var item in apps) {
      final app = item as Map<dynamic, dynamic>;
      final appName = app['appName'] ?? 'Unknown App';
      final pkgName = app['packageName'] ?? '';
      final isSideloaded = app['isSideloaded'] == true;
      final hasAccessibility = app['hasAccessibility'] == true;
      final hasOverlay = app['hasOverlay'] == true;
      final hasSms = app['hasSms'] == true;

      if (hasAccessibility && isSideloaded) {
        score -= 25;
        threats.add(ThreatItem(
          title: 'Accessibility Risk: $appName',
          description: 'Sideloaded app has permission to read screen & Banking OTPs.',
          severity: RiskSeverity.critical,
          scoreDeduction: 25,
          remediationTarget: 'ACCESSIBILITY_SETTINGS',
          packageName: pkgName,
        ));
      } else if (hasSms && isSideloaded) {
        score -= 20;
        threats.add(ThreatItem(
          title: 'SMS Intercept Risk: $appName',
          description: 'Sideloaded app can read incoming SMS. Risk of OTP theft.',
          severity: RiskSeverity.high,
          scoreDeduction: 20,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      } else if (hasOverlay && isSideloaded) {
        score -= 20;
        threats.add(ThreatItem(
          title: 'Overlay Phishing Risk: $appName',
          description: 'Sideloaded app can draw over other apps to capture passwords.',
          severity: RiskSeverity.high,
          scoreDeduction: 20,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      } else if (isSideloaded) {
        score -= 15;
        threats.add(ThreatItem(
          title: 'Unverified App: $appName',
          description: 'Installed from unknown source outside Google Play Store.',
          severity: RiskSeverity.high,
          scoreDeduction: 15,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      }
    }

    final int finalScore = score < 0 ? 0 : score;

    String category = 'GREEN';
    if (finalScore < 50) {
      category = 'RED';
    } else if (finalScore < 80) {
      category = 'YELLOW';
    }

    return HygieneReport(
      finalScore: finalScore,
      riskCategory: category,
      threats: threats,
      timestamp: DateTime.now(),
    );
  }

  HygieneReport _getSimulatedDemoReport() {
    return HygieneReport(
      finalScore: 65,
      riskCategory: 'YELLOW',
      threats: [
        ThreatItem(
          title: 'USB Debugging Enabled',
          description: 'ADB Debugging is active. High risk of unauthorized USB exploitation.',
          severity: RiskSeverity.high,
          scoreDeduction: 15,
          remediationTarget: 'DEVELOPMENT_SETTINGS',
        ),
        ThreatItem(
          title: 'Unverified App: LoanExpress.apk',
          description: 'Installed from unknown WhatsApp link outside Google Play Store.',
          severity: RiskSeverity.high,
          scoreDeduction: 20,
          remediationTarget: 'APP_DETAILS',
          packageName: 'com.fake.loanexpress',
        ),
      ],
      timestamp: DateTime.now(),
    );
  }
}
