import 'dart:convert';
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
  final String riskCategory; // GREEN, YELLOW, RED, ERROR, UNSUPPORTED
  final List<ThreatItem> threats;
  final DateTime timestamp;
  final String? errorMessage;

  HygieneReport({
    required this.finalScore,
    required this.riskCategory,
    required this.threats,
    required this.timestamp,
    this.errorMessage,
  });

  /// Returned when the native plugin is not registered (iOS, desktop, or
  /// running without a connected Android device). Never shows synthetic data.
  factory HygieneReport.platformUnsupported() => HygieneReport(
        finalScore: -1,
        riskCategory: 'UNSUPPORTED',
        threats: [],
        timestamp: DateTime.now(),
        errorMessage: 'Native scan is only supported on Android devices.',
      );

  /// Returned when an unexpected runtime error occurs during scanning.
  factory HygieneReport.scanError(String message) => HygieneReport(
        finalScore: -1,
        riskCategory: 'ERROR',
        threats: [],
        timestamp: DateTime.now(),
        errorMessage: message,
      );

  bool get isError => finalScore == -1;
}

class HygieneScannerEngine {
  static const MethodChannel _channel =
      MethodChannel('com.mobile.hygiene.guardian/hygiene');

  static List<String> _threatSignatures = [
    'com.fake.',
    'com.pm.yojana',
    'com.electricity.bill',
    'com.anydesk.',
    'com.teamviewer.host',
    'com.quicksupport',
    'com.cyber.fraud',
    'com.mod.apk',
    'com.apk.installer',
  ];

  static Future<void> loadSignatures() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/threat_signatures.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      if (data['signatures'] is List) {
        _threatSignatures = (data['signatures'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
  }

  /// Executes full native scan and calculates 0-100 score.
  /// Returns [HygieneReport.platformUnsupported] on iOS/desktop/unregistered plugin.
  /// Returns [HygieneReport.scanError] on unexpected failures.
  /// Never returns synthetic demo data.
  Future<HygieneReport> runFullScan({Function(String stage, double progress)? onProgress}) async {
    try {
      onProgress?.call('Initializing Security Audit...', 0.1);
      await loadSignatures();
      
      onProgress?.call('Auditing OS Security Sandbox & Root Integrity...', 0.3);
      final Map<dynamic, dynamic> rawResult =
          await _channel.invokeMethod('scanDeviceHygiene');
      
      onProgress?.call('Analyzing Network Interceptors & Proxies...', 0.6);
      await Future.delayed(const Duration(milliseconds: 150));
      
      onProgress?.call('Matching Community Threat Intelligence...', 0.85);
      final report = calculateReport(rawResult);
      
      onProgress?.call('Audit Complete', 1.0);
      return report;
    } on MissingPluginException {
      // Plugin not registered — iOS, desktop, or plugin build issue.
      return HygieneReport.platformUnsupported();
    } catch (e) {
      return HygieneReport.scanError(e.toString());
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

  HygieneReport calculateReport(Map<dynamic, dynamic> rawData, {List<String>? customSignatures}) {
    int score = 100;
    List<ThreatItem> threats = [];

    // 1. OS Security Audit
    final os = rawData['osSecurity'] is Map ? rawData['osSecurity'] as Map<dynamic, dynamic> : {};
    if (os['isRooted'] == true) {
      score = (score - 30).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'Rooted OS Detected',
        description: 'Superuser binary found. OS security sandbox is compromised.',
        severity: RiskSeverity.critical,
        scoreDeduction: 30,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    if (os['usbDebuggingEnabled'] == true) {
      score = (score - 15).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'USB Debugging Enabled',
        description: 'ADB Debugging is active. High risk of unauthorized USB exploitation.',
        severity: RiskSeverity.high,
        scoreDeduction: 15,
        remediationTarget: 'DEVELOPMENT_SETTINGS',
      ));
    }

    if (os['devOptionsEnabled'] == true && os['usbDebuggingEnabled'] != true) {
      score = (score - 10).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'Developer Options Enabled',
        description: 'Developer settings are active. Increases attack surface for advanced exploits.',
        severity: RiskSeverity.medium,
        scoreDeduction: 10,
        remediationTarget: 'DEVELOPMENT_SETTINGS',
      ));
    }

    if (os['isDeviceSecure'] == false) {
      score = (score - 10).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'No Screen Lock Set',
        description: 'Device lock screen PIN/Pattern is disabled.',
        severity: RiskSeverity.medium,
        scoreDeduction: 10,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    if (os['isPatchOutdated'] == true) {
      score = (score - 10).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'Outdated System Security Patch',
        description: 'Android OS security patch level is unpatched/outdated.',
        severity: RiskSeverity.medium,
        scoreDeduction: 10,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    // 2. Network Security Audit
    final net = rawData['network'] is Map ? rawData['network'] as Map<dynamic, dynamic> : {};
    if (net['isProxyActive'] == true) {
      score = (score - 15).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'Active Proxy Interceptor',
        description: 'HTTP Proxy configured. High risk of Man-In-The-Middle network interception.',
        severity: RiskSeverity.high,
        scoreDeduction: 15,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    if (net['isOpenWifi'] == true) {
      score = (score - 15).clamp(0, 100);
      threats.add(ThreatItem(
        title: 'Open / Unencrypted Wi-Fi Risk',
        description: 'Connected to an open/untrusted Wi-Fi network without encryption.',
        severity: RiskSeverity.high,
        scoreDeduction: 15,
        remediationTarget: 'SECURITY_SETTINGS',
      ));
    }

    // Known Community Malware & Phishing Package Patterns
    final signatures = customSignatures ?? _threatSignatures;

    // 3. App Permission & Sideload Audit
    final List<dynamic> apps = rawData['apps'] is List ? rawData['apps'] as List<dynamic> : [];
    for (var item in apps) {
      if (item is! Map) continue;
      final app = item as Map<dynamic, dynamic>;
      final appName = (app['appName'] ?? 'Unknown App').toString();
      final pkgName = (app['packageName'] ?? '').toString();
      final isSideloaded = app['isSideloaded'] == true;
      final hasAccessibility = app['hasAccessibility'] == true;
      final hasOverlay = app['hasOverlay'] == true;
      final hasSms = app['hasSms'] == true;
      final hasBackgroundService = app['hasBackgroundService'] == true;

      final isKnownScamSignature = signatures.any(
        (sig) => pkgName.toLowerCase().contains(sig) || appName.toLowerCase().contains(sig.replaceAll('com.', '').replaceAll('.', ''))
      );

      if (isKnownScamSignature && isSideloaded) {
        score = (score - 30).clamp(0, 100);
        threats.add(ThreatItem(
          title: 'Known Malware / Phishing Match: $appName',
          description: 'Matched community intelligence database of financial fraud / remote access scam tools.',
          severity: RiskSeverity.critical,
          scoreDeduction: 30,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      } else if (hasAccessibility && isSideloaded) {
        score = (score - 25).clamp(0, 100);
        threats.add(ThreatItem(
          title: 'Accessibility Risk: $appName',
          description: 'Sideloaded app has permission to read screen & Banking OTPs.',
          severity: RiskSeverity.critical,
          scoreDeduction: 25,
          remediationTarget: 'ACCESSIBILITY_SETTINGS',
          packageName: pkgName,
        ));
      } else if (hasSms && isSideloaded) {
        score = (score - 20).clamp(0, 100);
        threats.add(ThreatItem(
          title: 'SMS Intercept Risk: $appName',
          description: 'Sideloaded app can read incoming SMS. Risk of OTP theft.',
          severity: RiskSeverity.high,
          scoreDeduction: 20,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      } else if (hasOverlay && isSideloaded) {
        score = (score - 20).clamp(0, 100);
        threats.add(ThreatItem(
          title: 'Overlay Phishing Risk: $appName',
          description: 'Sideloaded app can draw over other apps to capture passwords.',
          severity: RiskSeverity.high,
          scoreDeduction: 20,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      } else if (hasBackgroundService && isSideloaded) {
        score = (score - 15).clamp(0, 100);
        threats.add(ThreatItem(
          title: 'Background Drain & Battery Risk: $appName',
          description: 'Sideloaded app runs persistent background services & bypasses battery optimization.',
          severity: RiskSeverity.high,
          scoreDeduction: 15,
          remediationTarget: 'APP_DETAILS',
          packageName: pkgName,
        ));
      } else if (isSideloaded) {
        score = (score - 15).clamp(0, 100);
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

    final int finalScore = score.clamp(0, 100);

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

}

