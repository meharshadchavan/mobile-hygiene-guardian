import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_hygiene_guardian/services/localization_service.dart';

void main() {
  group('LocalizationService Tests', () {
    test('Jarvis speech formatting in English', () {
      final speech = AppTranslations.getJarvisSpeech(85, 2, 'en');
      expect(speech, contains('Your mobile security score is 85 out of 100.'));
      expect(speech, contains('Warning: 2 security risks detected.'));
    });

    test('Jarvis speech formatting in Gujarati', () {
      final speech = AppTranslations.getJarvisSpeech(65, 3, 'gu');
      expect(speech, contains('તમારો મોબાઇલ સિક્યોરિટી સ્કોર 65 છે.'));
      expect(speech, contains('સાવધાન: 3 સુરક્ષા જોખમો મળ્યા છે.'));
    });

    test('Jarvis speech formatting in Hindi', () {
      final speech = AppTranslations.getJarvisSpeech(90, 0, 'hi');
      expect(speech, contains('आपका मोबाइल सिक्योरिटी स्कोर 90 है।'));
      expect(speech, contains('आपका फोन पूरी तरह सुरक्षित है।'));
    });

    test('Fallback on unknown key', () {
      final text = AppTranslations.get('non_existent_key', 'en', defaultValue: 'Fallback Text');
      expect(text, equals('Fallback Text'));
    });
  });
}
