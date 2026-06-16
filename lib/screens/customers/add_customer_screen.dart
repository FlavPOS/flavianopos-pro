// lib/screens/customers/add_customer_screen.dart
import 'package:flutter/material.dart';
import '../../models/customer_directory_model.dart';

class AddCustomerScreen extends StatefulWidget {
  final DirectoryCustomer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  String _selectedGroup = 'Regular';
  DateTime? _birthday;

  bool get _isEditing => widget.customer != null;

  final List<String> _groups = ['VIP', 'Regular', 'New', 'Wholesale'];

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    if (c != null) {
      _selectedGroup = c.group;
      _birthday = c.birthday;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.cyan[700]!),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _saveCustomer() {
    if (_formKey.currentState!.validate()) {
      final customer = DirectoryCustomer(
        id:
            widget.customer?.id ??
            'DIR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        group: _selectedGroup,
        notes: _notesController.text.trim(),
        totalSpent: widget.customer?.totalSpent ?? 0,
        totalVisits: widget.customer?.totalVisits ?? 0,
        lastVisitDate: widget.customer?.lastVisitDate,
        joinDate: widget.customer?.joinDate ?? DateTime.now(),
        birthday: _birthday,
        purchases: widget.customer?.purchases ?? [],
      );
      Navigator.pop(context, customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Customer' : 'Add Customer',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _saveCustomer,
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
              _buildSectionHeader('Personal Information', Icons.person),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: _inputDecor('Full Name', Icons.person_outline),
                textCapitalization: TextCapitalization.words,
                validator:
                    (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                decoration: _inputDecor('Phone Number', Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone is required';
                  if (v.length < 11) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Contact Details', Icons.contact_mail),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                decoration: _inputDecor(
                  'Email (Optional)',
                  Icons.email_outlined,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: _inputDecor(
                  'Address (Optional)',
                  Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Customer Group', Icons.group),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedGroup,
                decoration: _inputDecor('Group', Icons.category),
                items:
                    _groups
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                onChanged: (v) => setState(() => _selectedGroup = v!),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _selectBirthday,
                child: InputDecorator(
                  decoration: _inputDecor('Birthday (Optional)', Icons.cake),
                  child: Text(
                    _birthday != null
                        ? '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}'
                        : 'Tap to select birthday',
                    style: TextStyle(
                      color:
                          _birthday != null ? Colors.black87 : Colors.grey[500],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Additional Info', Icons.notes),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                decoration: _inputDecor('Notes (Optional)', Icons.edit_note),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveCustomer,
                  icon: Icon(_isEditing ? Icons.save : Icons.person_add),
                  label: Text(
                    _isEditing ? 'UPDATE CUSTOMER' : 'ADD CUSTOMER',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[700],
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.cyan[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.cyan[800],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
