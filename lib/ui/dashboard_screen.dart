import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hygiene_scanner_engine.dart';
import '../services/localization_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final HygieneScannerEngine _engine = HygieneScannerEngine();
  final FlutterTts _tts = FlutterTts();
  
  HygieneReport? _report;
  bool _isScanning = false;
  String _currentLanguage = 'en'; // 'en', 'gu', 'hi'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTranslationsAndScan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Automatically re-scan when user returns to app after fixing system settings
    if (state == AppLifecycleState.resumed && !_isScanning) {
      _startScan(speak: false);
    }
  }

  Future<void> _loadTranslationsAndScan() async {
    await AppTranslations.load(_currentLanguage);
    await _startScan(speak: true);
  }

  Future<void> _onLanguageChanged(String newLang) async {
    setState(() => _currentLanguage = newLang);
    await AppTranslations.load(newLang);
    if (_report != null) {
      _speakJarvisReport(_report!);
    }
  }

  Future<void> _startScan({bool speak = true}) async {
    setState(() => _isScanning = true);
    final report = await _engine.runFullScan();
    setState(() {
      _report = report;
      _isScanning = false;
    });
    if (speak) {
      _speakJarvisReport(report);
    }
  }

  Future<void> _speakJarvisReport(HygieneReport report) async {
    final speech = AppTranslations.getJarvisSpeech(
      report.finalScore,
      report.threats.length,
      _currentLanguage,
    );

    if (_currentLanguage == 'gu') {
      await _tts.setLanguage('gu-IN');
    } else if (_currentLanguage == 'hi') {
      await _tts.setLanguage('hi-IN');
    } else {
      await _tts.setLanguage('en-US');
    }
    
    await _tts.speak(speech);
  }

  Future<void> _callHelpline() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '1930');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer for 1930')),
        );
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.amber;
    return Colors.red;
  }

  String _tr(String key, String fallback) {
    return AppTranslations.get(key, _currentLanguage, defaultValue: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final score = _report?.finalScore ?? 100;
    final scoreColor = _getScoreColor(score);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('app_title', 'Mobile Hygiene Guardian')),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          DropdownButton<String>(
            value: _currentLanguage,
            dropdownColor: Colors.blueGrey[800],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
              DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
            ],
            onChanged: (val) {
              if (val != null) {
                _onLanguageChanged(val);
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Auditing Device Security & OS Settings...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Hygiene Gauge
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scoreColor, width: 12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                          Text(_tr('hygiene_score', 'Hygiene Score'), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rescan & Jarvis Voice Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _startScan(speak: true),
                        icon: const Icon(Icons.refresh),
                        label: Text(_tr('re_scan', 'Re-Scan')),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          if (_report != null) _speakJarvisReport(_report!);
                        },
                        icon: const Icon(Icons.volume_up),
                        label: Text(_tr('jarvis_report', 'Jarvis Report')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Threat List Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tr('detected_risks', 'Detected Security Risks'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_report?.threats.isEmpty ?? true)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(_tr('no_threats', 'No Threats Detected')),
                        subtitle: Text(_tr('no_threats_desc', 'Your device hygiene posture is optimal.')),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _report!.threats.length,
                      itemBuilder: (context, index) {
                        final threat = _report!.threats[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.red[50],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: ListTile(
                              leading: const Icon(Icons.warning, color: Colors.red),
                              title: Text(threat.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(threat.description),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  _engine.fixThreat(
                                    threat.remediationTarget,
                                    packageName: threat.packageName,
                                  );
                                },
                                child: Text(_tr('fix_now', 'Fix Now'), style: const TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // Gujarat Police Cyber Crime Helpline Banner
                  Card(
                    color: Colors.blueGrey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _tr('police_helpline_title', 'Gujarat Police Cyber Crime Helpline'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tr('police_helpline_desc', 'If you are a victim of financial fraud, call 1930 immediately to freeze transactions.'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                            onPressed: _callHelpline,
                            icon: const Icon(Icons.phone, color: Colors.black),
                            label: Text(
                              _tr('call_1930', 'Call Helpline 1930'),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

