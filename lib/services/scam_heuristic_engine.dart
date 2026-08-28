enum ScamRiskLevel { safe, suspicious, dangerous, criticalScam }

class ScamAnalysisResult {
  final bool isScam;
  final int confidenceScore; // 0 to 100%
  final ScamRiskLevel riskLevel;
  final String category;
  final List<String> detectedRedFlags;
  final String actionRecommendation;

  ScamAnalysisResult({
    required this.isScam,
    required this.confidenceScore,
    required this.riskLevel,
    required this.category,
    required this.detectedRedFlags,
    required this.actionRecommendation,
  });

  factory ScamAnalysisResult.clean() => ScamAnalysisResult(
        isScam: false,
        confidenceScore: 5,
        riskLevel: ScamRiskLevel.safe,
        category: 'Clean Message',
        detectedRedFlags: [],
        actionRecommendation: 'No malicious patterns or phishing indicators found.',
      );
}

class ScamHeuristicEngine {
  static final List<String> _electricityKeywords = [
    'electricity',
    'bill unpaid',
    'power disconnected',
    'power will be disconnected',
    'power cut',
    'electric officer',
    'bescom',
    'pgvcl',
    'dgvcl',
    'ugvcl',
    'mgvcl',
    'torrent power',
    'light cut',
    'meter disconnected',
  ];

  static final List<String> _kycBankingKeywords = [
    'kyc',
    'pan card',
    'bank account blocked',
    'account suspended',
    'debit card blocked',
    'update kyc',
    'aadhaar link',
    'sim blocked',
    'yono sbi',
    'paytm kyc',
    'hdfc alert',
    'icici reward',
  ];

  static final List<String> _remoteAccessKeywords = [
    'anydesk',
    'teamviewer',
    'rustdesk',
    'quicksupport',
    'screen share',
  ];

  static final List<String> _lotteryJobKeywords = [
    'lottery',
    'kbc prize',
    'won 25 lakh',
    'part time job',
    'earn 5000 daily',
    'pm yojana',
    'free recharge',
    'gift card',
  ];

  static final List<String> _urgencyKeywords = [
    'tonight at 9:30',
    'immediately',
    'within 24 hours',
    'urgent',
    'last warning',
    'final notice',
    'contact immediately',
  ];

  static ScamAnalysisResult analyzeMessage(String rawText) {
    if (rawText.trim().isEmpty) {
      return ScamAnalysisResult.clean();
    }

    final lower = rawText.toLowerCase();
    // Normalized copy to defeat character-spaced or symbol-inserted obfuscations (e.g. p.a.y.t.m or e1ectricity)
    final normalized = lower
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll(RegExp(r'[\.\-\_\s]+'), '');

    final redFlags = <String>[];
    int score = 0;
    String detectedCategory = 'General Message';

    // 1. Check for APK link or IP URL
    final hasApkLink = lower.contains('.apk') || lower.contains('download apk') || lower.contains('install apk') || normalized.contains('apk');
    final hasIpUrl = RegExp(r'https?:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(lower);
    final hasShortener = lower.contains('bit.ly') || lower.contains('tinyurl.com') || lower.contains('t.co') || lower.contains('is.gd') || lower.contains('ngrok');

    if (hasApkLink) {
      score += 45;
      redFlags.add('Message prompts downloading an unverified .APK file.');
    }
    if (hasIpUrl) {
      score += 35;
      redFlags.add('Message contains a raw numeric IP web address (common in phishing).');
    }
    if (hasShortener) {
      score += 20;
      redFlags.add('Message uses URL shortener to hide destination website.');
    }

    // Helper for keyword match across lower and normalized strings
    bool matchesKeyword(String keyword) {
      final cleanK = keyword.replaceAll(' ', '');
      return lower.contains(keyword) || normalized.contains(cleanK);
    }

    // 2. Electricity Bill Scam
    final electricityMatches = _electricityKeywords.where(matchesKeyword).toList();
    if (electricityMatches.isNotEmpty) {
      score += 35;
      detectedCategory = 'Electricity Bill Fraud Vector';
      redFlags.add('Impersonates utility board (${electricityMatches.first}) threatening power cutoff.');
    }

    // 3. Banking & KYC Phishing
    final kycMatches = _kycBankingKeywords.where(matchesKeyword).toList();
    if (kycMatches.isNotEmpty) {
      score += 35;
      detectedCategory = 'Banking / KYC Phishing Vector';
      redFlags.add('Claims urgent account suspension or KYC update (${kycMatches.first}).');
    }

    // 4. Remote Access Tool Phishing
    final remoteMatches = _remoteAccessKeywords.where(matchesKeyword).toList();
    if (remoteMatches.isNotEmpty) {
      score += 40;
      detectedCategory = 'Remote Access Control Scam';
      redFlags.add('Requests installing remote screen-sharing software (${remoteMatches.first}).');
    }

    // 5. Lottery / Job Fraud
    final lotteryMatches = _lotteryJobKeywords.where(matchesKeyword).toList();
    if (lotteryMatches.isNotEmpty) {
      score += 30;
      detectedCategory = 'Fake Lottery / Job Offer Scam';
      redFlags.add('Promises unrealistic financial reward or fake government scheme.');
    }

    // 6. Artificial Urgency / Coercion
    final urgencyMatches = _urgencyKeywords.where(matchesKeyword).toList();
    if (urgencyMatches.isNotEmpty) {
      score += 15;
      redFlags.add('Uses artificial urgency pressure ("${urgencyMatches.first}").');
    }

    final confidence = score.clamp(0, 100);

    if (confidence >= 70) {
      return ScamAnalysisResult(
        isScam: true,
        confidenceScore: confidence,
        riskLevel: ScamRiskLevel.criticalScam,
        category: detectedCategory,
        detectedRedFlags: redFlags,
        actionRecommendation: 'DO NOT click links or call numbers in this message. Report immediately to 1930.',
      );
    } else if (confidence >= 40) {
      return ScamAnalysisResult(
        isScam: true,
        confidenceScore: confidence,
        riskLevel: ScamRiskLevel.dangerous,
        category: detectedCategory,
        detectedRedFlags: redFlags,
        actionRecommendation: 'High likelihood of phishing. Do not share personal details or install files.',
      );
    } else if (confidence >= 20) {
      return ScamAnalysisResult(
        isScam: false,
        confidenceScore: confidence,
        riskLevel: ScamRiskLevel.suspicious,
        category: 'Suspicious Elements Detected',
        detectedRedFlags: redFlags,
        actionRecommendation: 'Exercise caution. Verify with official helpline before proceeding.',
      );
    }

    return ScamAnalysisResult.clean();
  }
}
