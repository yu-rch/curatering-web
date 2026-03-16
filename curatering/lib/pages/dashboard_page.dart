import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales Performance',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          // stats row
          Row(
            children: [
              _buildStatCard('Total Sales (Today)', '₱7,657',
                  const Color(0xFF1976D2)),
              const SizedBox(width: 16),
              _buildStatCard('Total Sales (This Month)', '₱159,583',
                  const Color(0xFF388E3C)),
              const SizedBox(width: 16),
              _buildStatCard('Total Sales (This Year)', '₱1.9M',
                  const Color(0xFFFFA000)),
            ],
          ),
          const SizedBox(height: 32),
          // placeholder charts
          Container(
            height: 300,
            color: Colors.grey.shade200,
            child: const Center(child: Text('Charts go here')),
          ),
        ],
      ),
    );
    return AppScaffold(
      showSearch: true,
      child: content,
    );
  }
}
