import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../models/product_model.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  final bool readOnly;
  const AddEditProductScreen({super.key, this.product, this.readOnly = false});
  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockQtyController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _barcodeController;
  String _selectedCategory = 'Beverages';
  String _selectedUnit = 'pcs';
  Uint8List? _imageBytes;
  String? _existingImagePath;

  bool get _isEditing => widget.product != null;

  List<String> _categories = [
    'Beverages', 'Snacks', 'Rice & Grains', 'Canned Goods', 'Personal Care',
    'Dairy', 'Frozen Foods', 'Condiments', 'Household', 'Others',
  ];

  List<String> _units = [
    'pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'bottle', 'can', 'sachet', 'dozen',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _costPriceController = TextEditingController(text: p?.costPrice.toString() ?? '');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice.toString() ?? '');
    _stockQtyController = TextEditingController(text: p?.stockQty.toString() ?? '0');
    _reorderLevelController = TextEditingController(text: p?.reorderLevel.toString() ?? '10');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    if (p != null) {
      _selectedCategory = p.category;
      if (!_categories.contains(_selectedCategory)) {
        _categories.insert(0, _selectedCategory);
      }
      _selectedUnit = p.unit;
      if (!_units.contains(_selectedUnit)) {
        _units.insert(0, _selectedUnit);
      }
      _existingImagePath = p.imagePath;
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockQtyController.dispose();
    _reorderLevelController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source, maxWidth: 400, maxHeight: 400, imageQuality: 50,
      );
      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() { _imageBytes = bytes; });
        } else {
          final cropped = await _cropImage(picked.path);
          if (cropped != null) {
            final bytes = await cropped.readAsBytes();
            setState(() { _imageBytes = bytes; });
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
          toolbarTitle: 'Crop Product Photo',
          toolbarColor: Colors.orange[700],
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.orange[700],
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Product Photo',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),

      ],
    );
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Product Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.camera_alt, color: Colors.blue[700])),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Use camera to take a photo'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.photo_library, color: Colors.green[700])),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick an existing photo'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            if (_imageBytes != null || _existingImagePath != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.delete, color: Colors.red[700])),
                title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
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
    return Column(children: [
      GestureDetector(
        onTap: _showImagePickerDialog,
        child: Container(
          width: double.infinity, height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[100], borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _imageBytes != null ? Colors.orange[400]! : Colors.grey[300]!, width: _imageBytes != null ? 2 : 1)),
          child: ClipRRect(borderRadius: BorderRadius.circular(15), child: _buildImageContent()),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: Icon(Icons.camera_alt, size: 16, color: Colors.orange[700]),
          label: Text('Camera', style: TextStyle(fontSize: 12, color: Colors.orange[700]))),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: Icon(Icons.photo_library, size: 16, color: Colors.orange[700]),
          label: Text('Gallery', style: TextStyle(fontSize: 12, color: Colors.orange[700]))),
        if (_imageBytes != null || _existingImagePath != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() { _imageBytes = null; _existingImagePath = null; }),
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            label: const Text('Remove', style: TextStyle(fontSize: 12, color: Colors.red))),
        ],
      ]),
    ]);
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
      ]);
    }
    if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      try {
        String b64 = _existingImagePath!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        if (b64.length > 200) {
          final bytes = base64Decode(b64);
          return Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
        }
        if (!kIsWeb) {
          return Image.file(File(_existingImagePath!), fit: BoxFit.cover);
        }
      } catch (_) {}
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 8),
      Text('Tap to add product photo', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      Text('Camera or Gallery', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
    ]);
  }

  void _saveProduct() {
    if (widget.readOnly) {
      debugPrint("🔒 EDIT BLOCKED: widget.readOnly=true");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔒 Master products are managed by Head Office only."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      String? imgPath = _existingImagePath;
      if (_imageBytes != null) {
        imgPath = base64Encode(_imageBytes!);
      }
      final product = Product(
        id: widget.product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        sku: _skuController.text.trim(),
        name: _nameController.text.trim(),
        category: _selectedCategory,
        unit: _selectedUnit,
        costPrice: double.tryParse(_costPriceController.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
        stockQty: int.tryParse(_stockQtyController.text) ?? 0,
        reorderLevel: int.tryParse(_reorderLevelController.text) ?? 10,
        barcode: _barcodeController.text.trim(),
        imagePath: imgPath,
      );
      Navigator.pop(context, product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add New Product',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[700], foregroundColor: Colors.white,
        actions: [
          TextButton.icon(onPressed: _saveProduct,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSectionHeader('Product Photo', Icons.photo_camera),
            const SizedBox(height: 12),
            _buildImageSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Basic Information', Icons.info_outline),
            const SizedBox(height: 12),
            TextFormField(controller: _skuController,
              decoration: _buildInputDecoration('SKU Code', Icons.qr_code),
              validator: (v) => (v == null || v.isEmpty) ? 'SKU is required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _nameController,
              decoration: _buildInputDecoration('Product Name', Icons.shopping_bag),
              validator: (v) => (v == null || v.isEmpty) ? 'Product name is required' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _buildInputDecoration('Category', Icons.category),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!))),
              const SizedBox(width: 12),
              SizedBox(width: 120, child: DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration: _buildInputDecoration('Unit', Icons.straighten),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _selectedUnit = v!))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _barcodeController,
              decoration: InputDecoration(labelText: 'Barcode (Optional)',
                prefixIcon: const Icon(Icons.barcode_reader),
                suffixIcon: IconButton(icon: const Icon(Icons.camera_alt),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Barcode scanner coming soon!'), behavior: SnackBarBehavior.floating))),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            _buildSectionHeader('Pricing', Icons.attach_money),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _costPriceController,
                decoration: _buildInputDecoration('Cost Price (P)', Icons.money),
                keyboardType: TextInputType.number, onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid';
                  return null;
                })),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _sellingPriceController,
                decoration: _buildInputDecoration('Selling Price (P)', Icons.sell),
                keyboardType: TextInputType.number, onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid';
                  return null;
                })),
            ]),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8),
              child: Builder(builder: (context) {
                final cost = double.tryParse(_costPriceController.text) ?? 0;
                final sell = double.tryParse(_sellingPriceController.text) ?? 0;
                final profit = sell - cost;
                final margin = sell > 0 ? (profit / sell) * 100 : 0;
                return Text('Profit: ${profit.toStringAsFixed(2)} | Margin: ${margin.toStringAsFixed(1)}%',
                  style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w500, fontSize: 13));
              })),
            const SizedBox(height: 16),
            _buildSectionHeader('Stock Information', Icons.inventory),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _stockQtyController,
                decoration: _buildInputDecoration('Stock Qty', Icons.numbers),
                keyboardType: TextInputType.number, enabled: !_isEditing,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _reorderLevelController,
                decoration: _buildInputDecoration('Reorder Level', Icons.low_priority),
                keyboardType: TextInputType.number)),
            ]),
            if (_isEditing)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('Use Stock Adjustment to change stock quantity',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic))),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(onPressed: _saveProduct,
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? 'UPDATE PRODUCT' : 'ADD PRODUCT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: Colors.orange[700]), const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[800])),
    ]);
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
  }
}

