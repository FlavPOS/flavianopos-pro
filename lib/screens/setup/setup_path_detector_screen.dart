import 'package:flutter/material.dart';
import '../../services/company_lookup_service.dart';
import '../../services/firebase_config_service.dart';
import '../../services/firebase_realtime_service.dart';
import 'company_setup_wizard.dart';
import 'setup_path_selector_screen.dart';

/// Detects whether the Firebase company already exists and routes accordingly.
/// IMPORTANT: Initializes Firebase first if it isn't already (browser refresh,
/// hot restart, fresh launch, etc.).
class SetupPathDetectorScreen extends StatefulWidget {
  const SetupPathDetectorScreen({super.key});
  @override
  State<SetupPathDetectorScreen> createState() =>
      _SetupPathDetectorScreenState();
}

class _SetupPathDetectorScreenState extends State<SetupPathDetectorScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  String _status = 'Loading Firebase config...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    try {
      // 1) Load saved manual Firebase config
      final cfg = await FirebaseConfigService().load();
      if (cfg == null || !cfg.hasRequiredFields) {
        // No config at all → start a fresh wizard
        _go(const CompanySetupWizard());
        return;
      }

      // 2) Ensure Firebase is initialized for THIS session.
      if (!FirebaseRealtimeService.instance.isInitialized) {
        setState(() => _status = 'Initializing Firebase...');
        await FirebaseRealtimeService.instance
            .initializeFromManualConfig(cfg);
      }

      // 3) Check whether the company profile already exists
      setState(() => _status = 'Looking up company ${cfg.companyCode}...');
      final profile =
          await CompanyLookupService().fetchCompanyProfile(cfg.companyCode);

      if (!mounted) return;
      if (profile == null || profile.isEmpty) {
        // Path A — new company
        _go(const CompanySetupWizard());
      } else {
        // Path B or C — let user choose
        _go(SetupPathSelectorScreen(existingProfile: profile));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _go(Widget next) => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFEDE7F6),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error == null) ...[
                  const CircularProgressIndicator(color: _purple),
                  const SizedBox(height: 20),
                  Text(_status,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54)),
                ] else ...[
                  const Icon(Icons.error_outline, color: Colors.red, size: 56),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _purple, foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _status = 'Retrying...';
                      });
                      _detect();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
