import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class Placeholder extends StatelessWidget {
  final String title;
  final String subtitle;

  const Placeholder({
    super.key,
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Container(
                  width: 560,
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: Text(
                      'Layout placeholder – content will go here',
                      style: TextStyle(color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
