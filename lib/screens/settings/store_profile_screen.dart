// lib/screens/settings/store_profile_screen.dart
// FULLY WIRED TO DATABASE - with logo upload!

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../helpers/database_helper.dart';

class StoreProfileScreen extends StatefulWidget {
  final String branch;
  const StoreProfileScreen({super.key, required this.branch});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _tinController = TextEditingController();
  final _ownerController = TextEditingController();
  final _receiptHeaderController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  
  String _businessType = 'Retail Store';
  bool _vatRegistered = false;
  String _logoPath = '';
  bool _loading = true;
  bool _saving = false;

  final List<String> _businessTypes = [
    'Retail Store', 'Grocery', 'Convenience Store', 'Sari-Sari Store',
    'Pharmacy', 'Restaurant', 'Hardware', 'General Merchandise', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _branchNameController.text = widget.branch;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseHelper().getStoreProfile();
    if (profile != null && mounted) {
      setState(() {
        _storeNameController.text = profile['storeName'] ?? '';
        _ownerController.text = profile['owner'] ?? '';
        _addressController.text = profile['address'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _tinController.text = profile['tin'] ?? '';
        _logoPath = profile['logoPath'] ?? '';
        _businessType = profile['businessType'] ?? 'Retail Store';
        _vatRegistered = (profile['vatRegistered'] ?? 0) == 1;
        _receiptHeaderController.text = profile['receiptHeader'] ?? '';
        _receiptFooterController.text = profile['receiptFooter'] ?? 'Thank you for shopping!';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _branchNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tinController.dispose();
    _ownerController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (_logoPath.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(ctx); setState(() => _logoPath = ''); },
                ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final image = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 80);
      if (image == null) return;
      
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'store_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedPath = '${dir.path}/$fileName';
      await File(image.path).copy(savedPath);
      
      if (_logoPath.isNotEmpty) {
        try { await File(_logoPath).delete(); } catch (_) {}
      }
      
      setState(() => _logoPath = savedPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo updated! Tap Save to keep changes.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseHelper().saveStoreProfile({
        'storeName': _storeNameController.text.trim(),
        'branch': _branchNameController.text.trim(),
        'businessType': _businessType,
        'owner': _ownerController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'tin': _tinController.text.trim(),
        'logoPath': _logoPath,
        'receiptHeader': _receiptHeaderController.text.trim(),
        'receiptFooter': _receiptFooterController.text.trim(),
        'vatRegistered': _vatRegistered ? 1 : 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Store profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, color: Colors.white),
            label: Text(_saving ? 'Saving...' : 'Save', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.purple[50],
                        border: Border.all(color: Colors.purple, width: 3),
                      ),
                      child: _logoPath.isNotEmpty && File(_logoPath).existsSync()
                        ? ClipOval(child: Image.file(File(_logoPath), fit: BoxFit.cover))
                        : Icon(Icons.store, size: 60, color: Colors.purple[700]),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple[700],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('Change Logo'),
                ),
              ),
              const SizedBox(height: 20),
              _buildField('Store Name *', _storeNameController, Icons.store, required: true),
              const SizedBox(height: 12),
              _buildField('Branch', _branchNameController, Icons.location_on, enabled: false),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _businessType,
                decoration: InputDecoration(
                  labelText: 'Business Type',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _businessType = v!),
              ),
              const SizedBox(height: 12),
              _buildField('Owner Name', _ownerController, Icons.person),
              const SizedBox(height: 12),
              _buildField('Address', _addressController, Icons.location_on, maxLines: 2),
              const SizedBox(height: 12),
              _buildField('Phone', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildField('TIN (Tax ID)', _tinController, Icons.numbers),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('VAT Registered'),
                subtitle: const Text('Apply VAT to receipts'),
                value: _vatRegistered,
                onChanged: (v) => setState(() => _vatRegistered = v),
                activeColor: Colors.purple,
              ),
              const SizedBox(height: 16),
              const Text('Receipt Customization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildField('Receipt Header (optional)', _receiptHeaderController, Icons.format_align_center, maxLines: 2),
              const SizedBox(height: 12),
              _buildField('Receipt Footer (optional)', _receiptFooterController, Icons.format_align_center, maxLines: 2),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('SAVE PROFILE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {bool required = false, bool enabled = true, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }
}
