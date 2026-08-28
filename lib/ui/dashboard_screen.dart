import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hygiene_scanner_engine.dart';
import '../services/localization_service.dart';
import '../services/forensic_pdf_service.dart';
import '../services/scam_heuristic_engine.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final HygieneScannerEngine _engine = HygieneScannerEngine();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _messageController = TextEditingController();

  HygieneReport? _report;
  bool _isScanning = false;
  String _scanProgressStage = 'Ready to scan';
  double _scanProgressValue = 0.0;
  String _currentLanguage = 'en'; // 'en', 'gu', 'hi'
  int _selectedTabIndex = 0;

  ScamAnalysisResult? _scamResult;

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
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isScanning && _selectedTabIndex == 0) {
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
    if (_report != null && _selectedTabIndex == 0) {
      _speakJarvisReport(_report!);
    }
  }

  Future<void> _startScan({bool speak = true}) async {
    setState(() {
      _isScanning = true;
      _scanProgressStage = 'Initializing Security Audit...';
      _scanProgressValue = 0.1;
    });

    final report = await _engine.runFullScan(
      onProgress: (stage, progress) {
        if (mounted) {
          setState(() {
            _scanProgressStage = stage;
            _scanProgressValue = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _report = report;
        _isScanning = false;
      });
      if (speak) {
        _speakJarvisReport(report);
      }
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

  Future<void> _exportPdfReport() async {
    if (_report == null || _report!.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please perform a successful device scan first.')),
      );
      return;
    }
    try {
      await ForensicPdfService.exportAndShareReport(_report!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export PDF: $e')),
        );
      }
    }
  }

  void _analyzeSuspiciousMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste or enter a message to analyze.')),
      );
      return;
    }
    final result = ScamHeuristicEngine.analyzeMessage(text);
    setState(() {
      _scamResult = result;
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('app_title', 'Mobile Hygiene Guardian')),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.amber),
            tooltip: _tr('export_pdf', 'Export Police Advisory PDF'),
            onPressed: _exportPdfReport,
          ),
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
          const SizedBox(width: 8),
        ],
      ),
      body: _buildSelectedTabBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) => setState(() => _selectedTabIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.security),
            label: _tr('tab_audit', 'Device Audit'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: _tr('tab_scam_scanner', 'Scam Scanner'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            label: _tr('tab_report', 'Forensic Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabBody() {
    switch (_selectedTabIndex) {
      case 1:
        return _buildScamScannerTab();
      case 2:
        return _buildForensicReportTab();
      case 0:
      default:
        return _buildDeviceAuditTab();
    }
  }

  // TAB 1: 🛡️ Real-time Device Hygiene Audit
  Widget _buildDeviceAuditTab() {
    if (_report != null && _report!.isError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _report!.riskCategory == 'UNSUPPORTED' ? Icons.phonelink_off : Icons.error_outline,
                size: 72,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 16),
              Text(
                _report!.riskCategory == 'UNSUPPORTED' ? 'Android Device Required' : 'Scan Error',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _report!.errorMessage ?? 'An unexpected error occurred.',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _startScan(speak: false),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Scan'),
              ),
            ],
          ),
        ),
      );
    }

    final score = _report?.finalScore ?? 100;
    final scoreColor = _getScoreColor(score);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated Circular Hygiene Gauge
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              final currentScore = animatedValue.toInt();
              final currentColor = _getScoreColor(currentScore);
              return Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: currentColor, width: 14),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$currentScore',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: currentColor,
                        ),
                      ),
                      Text(
                        _tr('hygiene_score', 'Hygiene Score'),
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Scanning Progress Indicator
          if (_isScanning) ...[
            LinearProgressIndicator(value: _scanProgressValue),
            const SizedBox(height: 8),
            Text(
              _scanProgressStage,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Action Buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isScanning ? null : () => _startScan(speak: true),
                icon: const Icon(Icons.refresh),
                label: Text(_tr('re_scan', 'Re-Scan')),
              ),
              OutlinedButton.icon(
                onPressed: _report != null ? () => _speakJarvisReport(_report!) : null,
                icon: const Icon(Icons.volume_up),
                label: Text(_tr('jarvis_report', 'Jarvis Voice')),
              ),
              OutlinedButton.icon(
                onPressed: _exportPdfReport,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.amber),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Detected Threats Section
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
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 36),
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
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                      title: Text(threat.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(threat.description),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          final success = await _engine.fixThreat(
                            threat.remediationTarget,
                            packageName: threat.packageName,
                          );
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please navigate to Settings manually to resolve threat.'),
                              ),
                            );
                          }
                        },
                        child: Text(_tr('fix_now', 'Fix Now'), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),

          // Gujarat Police Helpline 1930 Banner
          _buildHelplineCard(),
        ],
      ),
    );
  }

  // TAB 2: 🔍 SMS & WhatsApp Scam Message Heuristic Scanner
  Widget _buildScamScannerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blueGrey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.search_shield, color: Colors.amber, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr('tab_scam_scanner', 'SMS & Message Scam Scanner'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Detect financial fraud, APK traps, electricity bill & KYC phish before tapping.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Text Input Box
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _tr('scan_message_hint', 'Paste suspicious SMS or WhatsApp message here...'),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _analyzeSuspiciousMessage,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(_tr('analyze_message', 'Analyze Phishing Risk')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    setState(() => _messageController.text = data!.text!);
                  }
                },
                icon: const Icon(Icons.paste),
                label: const Text('Paste'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _messageController.clear();
                  _scamResult = null;
                }),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Scam Analysis Results Card
          if (_scamResult != null) ...[
            Card(
              color: _scamResult!.isScam ? Colors.red[50] : Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _scamResult!.category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _scamResult!.isScam ? Colors.red[900] : Colors.green[900],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _scamResult!.isScam ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_scamResult!.confidenceScore}% Scam Risk',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      _scamResult!.actionRecommendation,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _scamResult!.isScam ? Colors.red[800] : Colors.green[800],
                      ),
                    ),
                    if (_scamResult!.detectedRedFlags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Detected Red Flags:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ..._scamResult!.detectedRedFlags.map((flag) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning, size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(child: Text(flag, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TAB 3: 📄 Police Forensic Report & Cyber Tips
  Widget _buildForensicReportTab() {
    final tips = AppTranslations.getCyberTips(_currentLanguage);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blueGrey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.amber, size: 32),
                      SizedBox(width: 10),
                      Text(
                        'Official Gujarat Police Audit PDF',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generate a formal cryptographic timestamped audit document for reporting cyber fraud to cybercrime.gov.in or local police station.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                    onPressed: _exportPdfReport,
                    icon: const Icon(Icons.download, color: Colors.black),
                    label: Text(
                      _tr('export_pdf', 'Export Police Advisory PDF'),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cyber Hygiene Guide
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        _tr('cyber_tips_title', 'Cyber Hygiene & Safety Tips'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ...tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildHelplineCard(),
        ],
      ),
    );
  }

  Widget _buildHelplineCard() {
    return Card(
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
    );
  }
}
