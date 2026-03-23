import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class ManageAccounts extends StatelessWidget {
  const ManageAccounts({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Accounts',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            // Option buttons
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildOptionButton('MANAGE ACCOUNTS', isActive: true),
                _buildOptionButton('HELP REQUESTS'),
                _buildOptionButton('ACTION LOGS'),
                _buildOptionButton('WEBSITE'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String label, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFA726) : Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}
