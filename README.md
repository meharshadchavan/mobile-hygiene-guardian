# 🛡️ Mobile Hygiene Guardian

**Mobile Hygiene Guardian** is a production-grade mobile security, proactive watchdog, scam heuristic analysis, and digital hygiene auditing platform engineered with Flutter & Android Native Kotlin for the **Gujarat Police Hackathon (Problem Statement: PS-69E9C82CCEFA4)**.

---

## 🌟 Key Features & Architectural Capabilities

### 1. 📱 Native OS Security & Integrity Audit
* **Root Detection**: Inspects standard su binaries, test-keys build tags, Superuser/Magisk artifacts.
* **ADB / USB Debugging & Developer Options**: Proactively detects active developer debugging states that expose devices to malicious workstation exfiltration.
* **Lock Screen Enforcement**: Audits Keyguard status to ensure PIN, Password, or Biometric device locks are configured.

### 2. 🛑 Sideloading & Dangerous Permission Risk Engine
* **Source Attribution**: Distinguishes between trusted store installations (Google Play Store) and untrusted sideloaded APKs (WhatsApp forwards, Telegram downloads, SMS links).
* **High-Risk Permission Audits**:
  * `BIND_ACCESSIBILITY_SERVICE` (Screen scrapers, credential loggers, keyloggers)
  * `RECEIVE_SMS` / `READ_SMS` (OTP interception, financial fraud)
  * `SYSTEM_ALERT_WINDOW` (Cloaking overlays, fake banking login screens)
* **Threat Signature DB Matching**: Rapid hash & package identification against known community malware signatures (`assets/threat_signatures.json`).

### 3. 🔍 Scam & SMS Heuristic Engine
* **Rule-Based NLP & Regex Heuristics**: Analyzes SMS messages, WhatsApp text alerts, and unsolicited communication for:
  * Electricity disconnection / power cutoff fraud
  * Banking / KYC suspension phishing
  * Remote desktop APK download baiting (AnyDesk, TeamViewer, RustDesk)
  * Obfuscated symbol injection & leetspeak evasion attempts
* **Confidence & Threat Scoring**: Returns categorized severity (`CRITICAL`, `HIGH`, `MEDIUM`, `SAFE`) with matched pattern rationales.

### 4. 🐕 App Install Watchdog Background Receiver
* **Native Broadcast Receiver**: `AppInstallWatchdogReceiver` listens for `ACTION_PACKAGE_ADDED` events.
* **Immediate Security Assessment**: Evaluates newly installed sideloaded packages and dispatches immediate high-priority notifications to protect users in real time.

### 5. 📑 Forensic PDF Audit Export
* **Evidence Generation**: `ForensicPdfService` exports tamper-resistant audit logs including device fingerprints, detected vulnerabilities, severity breakdowns, and timestamped forensic evidence.
* **Direct Integration**: Native share/print/open capabilities via standard printing & PDF channels.

### 6. ⚡ 1-Tap Direct Remediation
* **Instant Native Intent Redirection**: Directs non-technical users straight into Android native settings (`ACCESSIBILITY_SETTINGS`, `DEVELOPMENT_SETTINGS`, `SECURITY_SETTINGS`, `APPLICATION_DETAILS_SETTINGS`) to revoke permissions or uninstall threats instantly.

### 7. 🗣️ Jarvis Multi-Lingual Voice Assistant (TTS)
* **Universal Accessibility**: Native Text-to-Speech audio briefings available in **English**, **Gujarati (ગુજરાતી)**, and **Hindi (हिंदी)** to empower rural and senior citizens.

### 8. 📞 Gujarat Police Cyber Crime Helpline 1930 Integration
* **1-Tap Emergency Dialing**: Instant direct dialer to freeze compromised banking transactions and lodge reports with the National Cyber Crime Reporting Portal (1930).

---

## 📁 Repository Structure

```
.
├── android/                                     # Android Native Kotlin & Gradle platform project
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml              # Permissions, receivers & queries
│   │       ├── kotlin/com/example/mobile_hygiene_guardian/
│   │       │   ├── MainActivity.kt              # Flutter-Android Native Method Channel
│   │       │   └── AppInstallWatchdogReceiver.kt # Real-time package install receiver
│   │       └── res/                             # Android mipmap icons & launcher styles
│   ├── build.gradle
│   ├── gradle.properties
│   └── settings.gradle
├── assets/
│   ├── l10n/                                    # Multi-lingual localization bundles (EN, GU, HI)
│   └── threat_signatures.json                   # Malware package & signature database
├── lib/
│   ├── main.dart                                # Application entry point
│   ├── services/
│   │   ├── forensic_pdf_service.dart            # Forensic PDF audit report generator
│   │   ├── hygiene_scanner_engine.dart          # Core security scoring & audit engine
│   │   ├── localization_service.dart            # Multi-lingual translation & TTS helper
│   │   └── scam_heuristic_engine.dart           # SMS/text phishing heuristic analyzer
│   └── ui/
│       └── dashboard_screen.dart                # Material 3 dynamic security dashboard
├── test/
│   ├── forensic_pdf_service_test.dart           # Unit tests for PDF generation & formatting
│   ├── hygiene_scanner_engine_test.dart         # Unit tests for hygiene scoring & rules
│   ├── localization_service_test.dart           # Unit tests for translation & TTS formatting
│   ├── scam_heuristic_engine_test.dart          # Unit tests for scam heuristic engine
│   └── stress_test.dart                         # Stress & load test suites (10k+ apps, concurrency)
├── analysis_options.yaml
└── pubspec.yaml
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.0.0+)
* Android SDK (API 21+)

### Installation & Run

```bash
# Get dependencies
flutter pub get

# Run application
flutter run
```

### Running Test Suites

```bash
# Execute comprehensive unit & stress test suites
flutter test
```
