import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../models/branch_model.dart';

class AddBranchScreen extends StatefulWidget {
  final Branch? branch;
  const AddBranchScreen({super.key, this.branch});
  @override
  State<AddBranchScreen> createState() => _AddBranchScreenState();
}

class _AddBranchScreenState extends State<AddBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _managerCtrl;
  bool _isActive = true;
  Uint8List? _imageBytes;
  String? _existingImagePath;

  bool get _isEditing => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _addressCtrl = TextEditingController(text: b?.address ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
    _emailCtrl = TextEditingController(text: b?.email ?? '');
    _managerCtrl = TextEditingController(text: b?.manager ?? '');
    if (b != null) {
      _isActive = b.isActive;
      _existingImagePath = b.imagePath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _managerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source, maxWidth: 400, maxHeight: 400, imageQuality: 50);
      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() => _imageBytes = bytes);
        } else {
          final cropped = await _cropImage(picked.path);
          if (cropped != null) {
            final bytes = await cropped.readAsBytes();
            setState(() => _imageBytes = bytes);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<CroppedFile?> _cropImage(String path) async {
    return await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Branch Photo',
          toolbarColor: Colors.indigo[700],
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.indigo[700],
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Branch Photo',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Branch Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.camera_alt, color: Colors.blue[700])),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.photo_library, color: Colors.green[700])),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            if (_imageBytes != null || _existingImagePath != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.delete, color: Colors.red[700])),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() { _imageBytes = null; _existingImagePath = null; });
                },
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        width: double.infinity, height: 160,
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageBytes != null ? Colors.indigo[400]! : Colors.grey[300]!,
            width: _imageBytes != null ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_imageBytes != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.memory(_imageBytes!, fit: BoxFit.cover),
        Positioned(top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text('New Photo', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        Positioned(bottom: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.edit, size: 16, color: Colors.white),
          ),
        ),
      ]);
    }
    if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      try {
        String b64 = _existingImagePath!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        if (b64.length > 200) {
          final bytes = base64Decode(b64);
          return Stack(fit: StackFit.expand, children: [
            Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover),
            Positioned(bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ]);
        }
      } catch (_) {}
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_photo_alternate, size: 48, color: Colors.indigo[300]),
      const SizedBox(height: 8),
      Text('Tap to add branch photo', style: TextStyle(color: Colors.indigo[400], fontSize: 13)),
      Text('Logo or storefront photo', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
    ]);
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      String? imgPath = _existingImagePath;
      if (_imageBytes != null) {
        imgPath = base64Encode(_imageBytes!);
      }
      final branch = Branch(
        id: widget.branch?.id ?? 'BR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        manager: _managerCtrl.text.trim(),
        isActive: _isActive,
        createdDate: widget.branch?.createdDate ?? DateTime.now(),
        userCount: widget.branch?.userCount ?? 0,
        todaySales: widget.branch?.todaySales ?? 0,
        totalProducts: widget.branch?.totalProducts ?? 0,
        imagePath: imgPath,
      );
      Navigator.pop(context, branch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Branch' : 'Add Branch',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[700], foregroundColor: Colors.white,
        actions: [
          TextButton.icon(onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header('Branch Photo', Icons.photo_camera),
            const SizedBox(height: 12),
            _buildImageSection(),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: Icon(Icons.camera_alt, size: 16, color: Colors.indigo[700]),
                label: Text('Camera', style: TextStyle(fontSize: 12, color: Colors.indigo[700]))),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library, size: 16, color: Colors.indigo[700]),
                label: Text('Gallery', style: TextStyle(fontSize: 12, color: Colors.indigo[700]))),
              if (_imageBytes != null || _existingImagePath != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() { _imageBytes = null; _existingImagePath = null; }),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(fontSize: 12, color: Colors.red))),
              ],
            ]),
            const SizedBox(height: 24),
            _header('Branch Information', Icons.store),
            const SizedBox(height: 12),
            TextFormField(controller: _nameCtrl,
              decoration: _dec('Branch Name', Icons.store),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _addressCtrl,
              decoration: _dec('Address', Icons.location_on), maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 24),
            _header('Contact Details', Icons.contact_phone),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl,
              decoration: _dec('Phone (Optional)', Icons.phone),
              keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl,
              decoration: _dec('Email (Optional)', Icons.email),
              keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),
            _header('Management', Icons.manage_accounts),
            const SizedBox(height: 12),
            TextFormField(controller: _managerCtrl,
              decoration: _dec('Branch Manager (Optional)', Icons.person),
              textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(_isActive ? 'Branch is operational' : 'Branch is closed', style: const TextStyle(fontSize: 12)),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isActive ? Colors.green : Colors.grey).withAlpha(25),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(_isActive ? Icons.check_circle : Icons.block,
                  color: _isActive ? Colors.green : Colors.grey, size: 20),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(onPressed: _save,
                icon: Icon(_isEditing ? Icons.save : Icons.add_business),
                label: Text(_isEditing ? 'UPDATE BRANCH' : 'ADD BRANCH',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ),
      ),
    );
  }

  Widget _header(String t, IconData i) => Row(children: [
    Icon(i, size: 20, color: Colors.indigo[700]), const SizedBox(width: 8),
    Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo[800])),
  ]);

  InputDecoration _dec(String l, IconData i) => InputDecoration(
    labelText: l, prefixIcon: Icon(i),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}
