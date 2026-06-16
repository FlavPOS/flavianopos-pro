// lib/screens/customers/customer_profile_screen.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../../models/customer_directory_model.dart';
import 'add_customer_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final DirectoryCustomer customer;
  final Function(DirectoryCustomer) onUpdate;

  const CustomerProfileScreen({
    super.key,
    required this.customer,
    required this.onUpdate,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late DirectoryCustomer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  void _editCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(customer: _customer),
      ),
    );
    if (result != null && result is DirectoryCustomer) {
      setState(() => _customer = result);
      widget.onUpdate(_customer);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editCustomer),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.cyan[700]!, Colors.cyan[500]!],
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withAlpha(50),
                      child: Text(
                        _customer.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _customer.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _customer.id,
                      style: TextStyle(color: Colors.white.withAlpha(180)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_customer.group} Customer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          'Total Spent',
                          _customer.totalSpent.toStringAsFixed(0),
                        ),
                        _buildStat('Visits', '${_customer.totalVisits}'),
                        _buildStat(
                          'Avg/Visit',
                          _customer.averagePerVisit.toStringAsFixed(0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _editCustomer,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_customer.phone.isNotEmpty) {
                        final uri = Uri.parse('tel:${_customer.phone}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number'), behavior: SnackBarBehavior.floating)); }
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_customer.phone.isNotEmpty) {
                        final uri = Uri.parse('sms:${_customer.phone}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number'), behavior: SnackBarBehavior.floating)); }
                    },
                    icon: const Icon(Icons.sms),
                    label: const Text('SMS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact Info
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildContactRow(Icons.phone, 'Phone', _customer.phone),
                    if (_customer.email.isNotEmpty)
                      _buildContactRow(Icons.email, 'Email', _customer.email),
                    if (_customer.address.isNotEmpty)
                      _buildContactRow(
                        Icons.location_on,
                        'Address',
                        _customer.address,
                      ),
                    if (_customer.birthday != null)
                      _buildContactRow(
                        Icons.cake,
                        'Birthday',
                        '${_customer.birthday!.month}/${_customer.birthday!.day}/${_customer.birthday!.year}',
                      ),
                    _buildContactRow(
                      Icons.calendar_today,
                      'Member Since',
                      '${_customer.joinDate.month}/${_customer.joinDate.day}/${_customer.joinDate.year}',
                    ),
                    if (_customer.lastVisitDate != null)
                      _buildContactRow(
                        Icons.access_time,
                        'Last Visit',
                        '${_customer.lastVisitDate!.month}/${_customer.lastVisitDate!.day}/${_customer.lastVisitDate!.year}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            if (_customer.notes.isNotEmpty) ...[
              _buildSectionTitle('Notes', Icons.notes),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _customer.notes,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Purchase History
            _buildSectionTitle(
              'Purchase History (${_customer.purchases.length})',
              Icons.receipt_long,
            ),
            const SizedBox(height: 8),

            if (_customer.purchases.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No purchase records yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ..._customer.purchases.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt,
                            color: Colors.cyan[700],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.date.month}/${p.date.day}/${p.date.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${p.itemCount} items',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              p.amount.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.cyan[800],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.paymentMethod,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
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
}
