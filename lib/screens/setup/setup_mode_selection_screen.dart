import 'package:flutter/material.dart';
import '../../services/setup_mode_service.dart';
import 'firebase_config_placeholder_screen.dart';

/// Step 1 — Setup Mode Selection Screen
/// Shown ONLY on fresh install / first launch, before the existing setup screen.
class SetupModeSelectionScreen extends StatefulWidget {
  /// The widget to navigate to when Solo Store is selected.
  final Widget soloNextScreen;

  const SetupModeSelectionScreen({
    super.key,
    required this.soloNextScreen,
  });

  @override
  State<SetupModeSelectionScreen> createState() =>
      _SetupModeSelectionScreenState();
}

class _SetupModeSelectionScreenState extends State<SetupModeSelectionScreen> {
  final SetupModeService _setupModeService = SetupModeService();

  String? _selectedMode;
  bool _saving = false;

  static const Color _primaryPurple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  Future<void> _onContinue() async {
    if (_selectedMode == null || _saving) return;

    setState(() => _saving = true);
    try {
      await _setupModeService.setSetupMode(_selectedMode!);

      if (!mounted) return;

      if (_selectedMode == SetupModeService.modeSolo) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.soloNextScreen),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const FirebaseConfigPlaceholderScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save selection: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final maxCardWidth = isTablet ? 520.0 : 420.0;

    return Scaffold(
      backgroundColor: _lightPurple,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 32 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.store_mall_directory_rounded,
                        size: 64,
                        color: _primaryPurple,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select Store Setup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 26 : 22,
                          fontWeight: FontWeight.bold,
                          color: _primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose how you want to use FlavianoPOS Pro.\nYou can change this later only by reinstalling or resetting setup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      _ModeOptionTile(
                        title: 'Solo Store',
                        subtitle:
                            'Use this device as a single store.\nLocal SQLite only. No internet required.',
                        icon: Icons.storefront_rounded,
                        value: SetupModeService.modeSolo,
                        groupValue: _selectedMode,
                        onChanged: (v) => setState(() => _selectedMode = v),
                        primaryColor: _primaryPurple,
                      ),
                      const SizedBox(height: 12),
                      _ModeOptionTile(
                        title: 'Multiple Store',
                        subtitle:
                            'Connect multiple branches online.\nRequires Firebase config (next step).',
                        icon: Icons.account_tree_rounded,
                        value: SetupModeService.modeMultiple,
                        groupValue: _selectedMode,
                        onChanged: (v) => setState(() => _selectedMode = v),
                        primaryColor: _primaryPurple,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _primaryPurple.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: (_selectedMode == null || _saving)
                              ? null
                              : _onContinue,
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Continue'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'FlavianoPOS Pro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;
  final Color primaryColor;

  const _ModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: selected ? primaryColor : Colors.black12,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            // Visual indicator only (no deprecated Radio API).
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? primaryColor : Colors.black38,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
