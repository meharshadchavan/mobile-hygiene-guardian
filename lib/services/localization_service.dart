import 'dart:convert';
import 'package:flutter/services.dart';

class AppTranslations {
  static final Map<String, Map<String, String>> _localizedValues = {};

  static Future<void> load(String languageCode) async {
    if (_localizedValues.containsKey(languageCode)) return;
    try {
      final jsonString = await rootBundle.loadString('assets/l10n/$languageCode.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedValues[languageCode] = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      _localizedValues[languageCode] = {};
    }
  }

  static String get(String key, String languageCode, {String defaultValue = ''}) {
    return _localizedValues[languageCode]?[key] ?? defaultValue;
  }

  static String getJarvisSpeech(int score, int threatCount, String languageCode) {
    if (languageCode == 'gu') {
      String speech = "સ્કેન પૂર્ણ થયુ! તમારો મોબાઇલ સિક્યોરિટી સ્કોર $score છે.";
      if (threatCount > 0) {
        speech += " સાવધાન: $threatCount સુરક્ષા જોખમો મળ્યા છે.";
      } else {
        speech += " તમારો ફોન સંપૂર્ણપણે સુરક્ષિત છે.";
      }
      return speech;
    } else if (languageCode == 'hi') {
      String speech = "स्कैन पूरा हो गया है! आपका मोबाइल सिक्योरिटी स्कोर $score है।";
      if (threatCount > 0) {
        speech += " सावधान: $threatCount सुरक्षा जोखिम पाए गए हैं।";
      } else {
        speech += " आपका फोन पूरी तरह सुरक्षित है।";
      }
      return speech;
    } else {
      String speech = "Scan complete! Your mobile security score is $score out of 100.";
      if (threatCount > 0) {
        speech += " Warning: $threatCount security risks detected.";
      } else {
        speech += " Your device hygiene posture is optimal.";
      }
      return speech;
    }
  }

  static List<String> getCyberTips(String languageCode) {
    return [
      get('tip_1', languageCode, defaultValue: 'Never install APK files sent via WhatsApp, SMS, or Telegram links.'),
      get('tip_2', languageCode, defaultValue: 'Never grant Accessibility permission or share OTPs with unverified apps.'),
      get('tip_3', languageCode, defaultValue: 'Avoid using open public Wi-Fi networks for banking transactions.'),
      get('tip_4', languageCode, defaultValue: 'Report financial fraud immediately by calling 1930 within the golden hour.'),
    ];
  }
}
