import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class LivePerformance extends StatelessWidget {
  const LivePerformance({super.key});

  Widget _buildPlaceholderSection(String title) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Placeholder for live performance visualization',
                  style: TextStyle(color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Performance',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. This is a placeholder layout for live performance metrics.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _buildPlaceholderSection('Performance Overview'),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPlaceholderSection('Top Events')),
                const SizedBox(width: 16),
                Expanded(child: _buildPlaceholderSection('Latest Metrics')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
