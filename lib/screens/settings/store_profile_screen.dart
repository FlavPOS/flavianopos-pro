// lib/screens/settings/store_profile_screen.dart
import 'package:flutter/material.dart';

class StoreProfileScreen extends StatefulWidget {
  final String branch;
  const StoreProfileScreen({super.key, required this.branch});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeNameController;
  late TextEditingController _branchNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _tinController;
  late TextEditingController _ownerController;
  String _businessType = 'Retail Store';

  final List<String> _businessTypes = [
    'Retail Store',
    'Grocery',
    'Convenience Store',
    'Sari-Sari Store',
    'Pharmacy',
    'Restaurant',
    'Hardware',
    'General Merchandise',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(text: 'FlavianoPOS Store');
    _branchNameController = TextEditingController(text: widget.branch);
    _addressController = TextEditingController(
      text: 'Diversion Road, Consolacion, Cebu City',
    );
    _phoneController = TextEditingController(text: '09171234567');
    _emailController = TextEditingController(text: 'store@quickpos.com');
    _tinController = TextEditingController(text: '123-456-789-000');
    _ownerController = TextEditingController(text: 'Flaviano Dagondon Jr.');
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
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Store profile saved!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Store Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withAlpha(50),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.store,
                        size: 48,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed:
                          () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Upload logo coming soon!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          ),
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text(
                        'Change Logo',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildHeader('Business Information', Icons.business),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storeNameController,
                decoration: _decor('Store Name', Icons.storefront),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchNameController,
                decoration: _decor('Branch Name', Icons.location_city),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _businessType,
                decoration: _decor('Business Type', Icons.category),
                items:
                    _businessTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _businessType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerController,
                decoration: _decor('Owner / Manager', Icons.person),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tinController,
                decoration: _decor('TIN Number', Icons.numbers),
              ),
              const SizedBox(height: 24),
              _buildHeader('Contact & Location', Icons.contact_phone),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: _decor('Store Address', Icons.location_on),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: _decor('Phone Number', Icons.phone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: _decor('Email Address', Icons.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              _buildHeader('Operating Hours', Icons.access_time),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildHoursRow('Monday - Friday', '8:00 AM - 9:00 PM'),
                      const Divider(),
                      _buildHoursRow('Saturday', '8:00 AM - 10:00 PM'),
                      const Divider(),
                      _buildHoursRow('Sunday', '9:00 AM - 8:00 PM'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'SAVE PROFILE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: Colors.blue[700]),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    ],
  );

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _buildHoursRow(String day, String hours) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        Text(hours, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    ),
  );
}
