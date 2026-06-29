import 'package:flutter/material.dart';
import '../../models/firebase_config_model.dart';
import '../../services/firebase_config_service.dart';
import '../../services/setup_mode_service.dart';
import '../../services/device_id_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../auth/setup_screen.dart';
import 'setup_mode_selection_screen.dart';
import 'setup_path_detector_screen.dart';

/// Step 3 — Firebase Manual Config + Connection Test
/// Field order mirrors the Firebase Console firebaseConfig snippet 1:1.
class FirebaseConfigScreen extends StatefulWidget {
  const FirebaseConfigScreen({super.key});

  @override
  State<FirebaseConfigScreen> createState() => _FirebaseConfigScreenState();
}

class _FirebaseConfigScreenState extends State<FirebaseConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirebaseConfigService();
  final _setupModeService = SetupModeService();
  final _deviceIdService = DeviceIdService();

  // firebaseConfig (same order as Console)
  final _apiKey = TextEditingController();
  final _authDomain = TextEditingController();
  final _projectId = TextEditingController();
  final _storageBucket = TextEditingController();
  final _senderId = TextEditingController();
  final _appId = TextEditingController();
  final _measurementId = TextEditingController();

  // Separate
  final _databaseUrl = TextEditingController();
  final _companyCode = TextEditingController();

  bool _showApiKey = false;
  bool _showAppId = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _locked = false;

  // Test state
  bool _testPassed = false;
  String? _testError;
  String? _lastTestedAt;
  String? _lastTestedPath;
  String? _deviceId;

  static const Color _primaryPurple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final existing = await _service.load();
    final locked = await _service.isLocked();
    final deviceId = await _deviceIdService.getOrCreate();
    if (existing != null) {
      _apiKey.text = existing.apiKey;
      _authDomain.text = existing.authDomain;
      _projectId.text = existing.projectId;
      _storageBucket.text = existing.storageBucket;
      _senderId.text = existing.messagingSenderId;
      _appId.text = existing.appId;
      _measurementId.text = existing.measurementId;
      _databaseUrl.text = existing.databaseUrl;
      _companyCode.text = existing.companyCode;
    }
    if (!mounted) return;
    setState(() {
      _locked = locked;
      _deviceId = deviceId;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _authDomain.dispose();
    _projectId.dispose();
    _storageBucket.dispose();
    _senderId.dispose();
    _appId.dispose();
    _measurementId.dispose();
    _databaseUrl.dispose();
    _companyCode.dispose();
    super.dispose();
  }

  // ---------- Validators ----------
  String? _vReq(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  String? _vCompany(String? v) {
    final r = _vReq(v, 'Company Code');
    if (r != null) return r;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v!.trim())) {
      return 'Use letters, numbers, "-" or "_" only (no spaces)';
    }
    return null;
  }

  String? _vUrl(String? v) {
    final r = _vReq(v, 'databaseURL');
    if (r != null) return r;
    final s = v!.trim();
    if (!(s.startsWith('https://') || s.startsWith('http://'))) {
      return 'Must start with https://';
    }
    if (!s.contains('firebaseio.com') && !s.contains('firebasedatabase.app')) {
      return 'Use the firebaseio.com or firebasedatabase.app URL';
    }
    return null;
  }

  FirebaseConfig _buildConfig({String existingCompanyName = ''}) {
    return FirebaseConfig(
      apiKey: _apiKey.text.trim(),
      authDomain: _authDomain.text.trim(),
      projectId: _projectId.text.trim(),
      storageBucket: _storageBucket.text.trim(),
      messagingSenderId: _senderId.text.trim(),
      appId: _appId.text.trim(),
      measurementId: _measurementId.text.trim(),
      databaseUrl: _databaseUrl.text.trim(),
      companyCode: _companyCode.text.trim(),
      companyName: existingCompanyName,
    );
  }

  // ---------- Actions ----------
  Future<void> _onSave() async {
    if (_locked) {
      _snack('Firebase config is locked. Only admin can edit.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      // Saving fresh values invalidates any previous test.
      _testPassed = false;
      _testError = null;
    });
    try {
      final existing = await _service.load();
      final cfg = _buildConfig(
          existingCompanyName: existing?.companyName ?? '');
      await _service.save(cfg);
      if (!mounted) return;
      _snack('Firebase config saved locally ✓');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onTest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_deviceId == null) {
      _snack('Device ID not ready. Try again.');
      return;
    }

    setState(() {
      _testing = true;
      _testError = null;
      _testPassed = false;
    });

    try {
      // 1) Always save first so init uses the latest typed values.
      final existing = await _service.load();
      final cfg = _buildConfig(
          existingCompanyName: existing?.companyName ?? '');
      await _service.save(cfg);

      // 2) Initialize Firebase dynamically.
      await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);

      // 3) Round-trip test.
      final result = await FirebaseRealtimeService.instance
          .testConnection(deviceId: _deviceId!);

      if (!mounted) return;
      setState(() {
        _testPassed = result.success;
        _testError = result.error;
        _lastTestedAt = result.testedAt;
        _lastTestedPath = result.path;
      });

      _snack(result.success
          ? 'Firebase connected ✓'
          : 'Connection failed: ${result.error}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testPassed = false;
        _testError = e.toString();
      });
      _snack('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ═══ PASTE FIREBASE CONFIG FEATURE ═══
  void _showPasteConfigDialog() {
    final pasteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_paste, color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(child: Text("Paste Firebase Config", style: TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "From Firebase Console:\n"
                "1. Project Settings → Your apps → Web app\n"
                "2. Copy the entire firebaseConfig block\n"
                "3. Paste it below — fields auto-fill!",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pasteCtrl,
                maxLines: 10,
                minLines: 6,
                style: const TextStyle(fontFamily: "monospace", fontSize: 11),
                decoration: InputDecoration(
                  hintText: "Paste firebaseConfig here...",
                  hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _parseAndFillConfig(pasteCtrl.text);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text("Auto-Fill"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _parseAndFillConfig(String input) {
    String extract(String key) {
      final pattern = RegExp("\"?" + key + "\"?\\s*:\\s*[\"']([^\"']+)[\"']");
      final m = pattern.firstMatch(input);
      return m?.group(1) ?? "";
    }

    final apiKey = extract("apiKey");
    final authDomain = extract("authDomain");
    final projectId = extract("projectId");
    final storageBucket = extract("storageBucket");
    final senderId = extract("messagingSenderId");
    final appId = extract("appId");
    final measurementId = extract("measurementId");
    final databaseUrl = extract("databaseURL");

    setState(() {
      if (apiKey.isNotEmpty) _apiKey.text = apiKey;
      if (authDomain.isNotEmpty) _authDomain.text = authDomain;
      if (projectId.isNotEmpty) _projectId.text = projectId;
      if (storageBucket.isNotEmpty) _storageBucket.text = storageBucket;
      if (senderId.isNotEmpty) _senderId.text = senderId;
      if (appId.isNotEmpty) _appId.text = appId;
      if (measurementId.isNotEmpty) _measurementId.text = measurementId;
      if (databaseUrl.isNotEmpty) _databaseUrl.text = databaseUrl;
    });

    final filled = [apiKey, authDomain, projectId, storageBucket,
                    senderId, appId, databaseUrl]
        .where((s) => s.isNotEmpty).length;

    if (filled == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ No fields found. Check that you pasted the firebaseConfig block."),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Auto-filled $filled fields! Add Company Code → Test Connection."),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  // ═══ END PASTE FEATURE ═══

  void _onContinue() {
    if (!_testPassed) {
      _snack("Please run a successful Test Connection first.");
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SetupPathDetectorScreen(),
    ));
  }

  Future<void> _onBack() async {
    if (_locked) {
      if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change setup mode?'),
        content: const Text(
          'Going back will clear your "Multiple Store" choice so you can pick again. '
          'Saved Firebase config values are kept.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPurple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await _setupModeService.clearSetupMode();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const SetupModeSelectionScreen(soloNextScreen: SetupScreen()),
      ),
      (route) => false,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final maxCardWidth = isTablet ? 640.0 : 460.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _lightPurple,
        appBar: AppBar(
          backgroundColor: _primaryPurple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Setup Mode',
            onPressed: _onBack,
          ),
          title: const Text('Firebase Config'),
          actions: [
            if (_locked)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.lock_outline),
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryPurple))
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxCardWidth),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                          padding: EdgeInsets.all(isTablet ? 28 : 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(Icons.cloud_sync_outlined,
                                    size: 56, color: _primaryPurple),
                                const SizedBox(height: 8),
                                Text(
                                  'Firebase Realtime Database',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isTablet ? 22 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Field order matches the Firebase Console snippet 1:1.\nCopy each line top-to-bottom from your Console.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                _statusBadge(),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _lightPurple,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _primaryPurple
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 18, color: _primaryPurple),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Company Name will be collected in the next step (Create Branch / Company Setup).',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_locked) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.lock_outline,
                                            size: 18, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Config is locked after main setup. Only company admin can edit later.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // 📋 PASTE FIREBASE CONFIG BUTTON
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _showPasteConfigDialog,
                                    icon: const Icon(Icons.content_paste, size: 20),
                                    label: const Text(
                                      "📋 Paste Firebase Config (Auto-Fill)",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _section('firebaseConfig'),
                                _field(
                                  ctrl: _apiKey,
                                  label: 'apiKey *',
                                  hint: 'AIzaSy...',
                                  icon: Icons.vpn_key_outlined,
                                  obscure: !_showApiKey,
                                  suffix: IconButton(
                                    icon: Icon(_showApiKey
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _showApiKey = !_showApiKey),
                                  ),
                                  validator: (v) => _vReq(v, 'apiKey'),
                                ),
                                _field(
                                  ctrl: _authDomain,
                                  label: 'authDomain',
                                  hint: 'YOUR-PROJECT.firebaseapp.com',
                                  icon: Icons.shield_outlined,
                                ),
                                _field(
                                  ctrl: _projectId,
                                  label: 'projectId *',
                                  hint: 'sample-be44f',
                                  icon: Icons.tag,
                                  validator: (v) => _vReq(v, 'projectId'),
                                ),
                                _field(
                                  ctrl: _storageBucket,
                                  label: 'storageBucket',
                                  hint: 'YOUR-PROJECT.firebasestorage.app',
                                  icon: Icons.storage_outlined,
                                ),
                                _field(
                                  ctrl: _senderId,
                                  label: 'messagingSenderId *',
                                  hint: '864778424112',
                                  icon: Icons.send_outlined,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      _vReq(v, 'messagingSenderId'),
                                ),
                                _field(
                                  ctrl: _appId,
                                  label: 'appId *',
                                  hint: '1:864778424112:web:...',
                                  icon: Icons.fingerprint,
                                  obscure: !_showAppId,
                                  suffix: IconButton(
                                    icon: Icon(_showAppId
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _showAppId = !_showAppId),
                                  ),
                                  validator: (v) => _vReq(v, 'appId'),
                                ),
                                _field(
                                  ctrl: _measurementId,
                                  label: 'measurementId (optional)',
                                  hint: 'G-XXXXXXXXXX',
                                  icon: Icons.analytics_outlined,
                                ),

                                const SizedBox(height: 14),
                                _section('Realtime Database (separate tab)'),
                                _field(
                                  ctrl: _databaseUrl,
                                  label: 'databaseURL *',
                                  hint:
                                      'https://YOUR-PROJECT-default-rtdb.firebaseio.com',
                                  icon: Icons.link,
                                  keyboardType: TextInputType.url,
                                  validator: _vUrl,
                                ),

                                const SizedBox(height: 14),
                                _section('Your Company'),
                                _field(
                                  ctrl: _companyCode,
                                  label: 'Company Code / Store Group Code *',
                                  hint: 'e.g. FLAVIANO01',
                                  icon: Icons.qr_code_2,
                                  validator: _vCompany,
                                ),

                                const SizedBox(height: 8),
                                if (_deviceId != null)
                                  Text(
                                    'Device ID: $_deviceId',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black38),
                                  ),

                                const SizedBox(height: 20),

                                // Save Config
                                SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primaryPurple,
                                      side: const BorderSide(
                                          color: _primaryPurple, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    onPressed:
                                        (_saving || _locked) ? null : _onSave,
                                    icon: _saving
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.2))
                                        : const Icon(Icons.save_outlined),
                                    label: Text(
                                        _locked ? 'Locked' : 'Save Config'),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Test Connection
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryPurple,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: _primaryPurple
                                          .withValues(alpha: 0.4),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onPressed:
                                        (_testing || _locked) ? null : _onTest,
                                    icon: _testing
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.wifi_tethering),
                                    label:
                                        Text(_testing ? 'Testing...' : 'Test Connection'),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Continue button (enabled only after successful test)
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    onPressed:
                                        _testPassed ? _onContinue : null,
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text('Continue to Setup'),
                                  ),
                                ),

                                const SizedBox(height: 10),
                                if (_testError != null && !_testPassed)
                                  _errorBox(_testError!),
                                if (_testPassed)
                                  _successBox(_lastTestedPath, _lastTestedAt),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statusBadge() {
    if (_testing) {
      return _pill('Testing connection...', Colors.blueGrey,
          icon: Icons.sync);
    }
    if (_testPassed) {
      return _pill('Firebase Connected ✓', Colors.green.shade700,
          icon: Icons.check_circle);
    }
    if (_testError != null) {
      return _pill('Not connected', Colors.red.shade700,
          icon: Icons.error_outline);
    }
    return _pill('Not tested yet', Colors.black54,
        icon: Icons.cloud_off_outlined);
  }

  Widget _pill(String text, Color color, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ],
        ),
      );

  Widget _successBox(String? path, String? at) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Round-trip successful',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (path != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Path: $path',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54)),
              ),
            if (at != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Tested at: $at',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54)),
              ),
          ],
        ),
      );

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: _primaryPurple,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    IconData? icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        readOnly: _locked,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: (_) {
          // Any edit invalidates a previous successful test.
          if (_testPassed || _testError != null) {
            setState(() {
              _testPassed = false;
              _testError = null;
            });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, color: _primaryPurple),
          suffixIcon: suffix,
          filled: true,
          fillColor: _locked ? Colors.grey.shade100 : Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _primaryPurple, width: 1.5)),
        ),
      ),
    );
  }
}
