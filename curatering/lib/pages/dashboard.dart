import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../services/dashboard_api.dart';
import '../utils/order_calculations.dart';
import '../widgets/app_scaffold.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _isLoading = false;
  String? _errorMessage;
  DashboardSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!AuthSession.instance.hasToken) {
      if (mounted) {
        setState(() => _errorMessage = 'Please log in to view the dashboard.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await DashboardApi.instance.loadSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load dashboard data.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _metricCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _metricsRow(List<Widget> children) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;

    return AppScaffold(
      showSearch: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Manager Dashboard',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : () => _load(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (s != null) ...[
              _sectionTitle('Restaurant'),
              _metricsRow([
                _metricCard(
                  'Pending confirmations',
                  '${s.restaurant.pendingConfirmations}',
                  Colors.orange.shade400,
                ),
                _metricCard(
                  'Delivered',
                  '${s.restaurant.delivered}',
                  Colors.green.shade600,
                ),
                _metricCard(
                  'Cancelled',
                  '${s.restaurant.cancelled}',
                  Colors.red.shade400,
                ),
                _metricCard(
                  'Sales today',
                  formatPhp(s.restaurant.salesToday),
                  Colors.blue.shade700,
                ),
              ]),
              const SizedBox(height: 20),
              _sectionTitle('Catering / Events'),
              _metricsRow([
                _metricCard(
                  'Inquiries this month',
                  '${s.catering.inquiriesThisMonth}',
                  Colors.deepPurple.shade300,
                ),
                _metricCard(
                  'Accepted',
                  '${s.catering.acceptedTransactions}',
                  Colors.indigo.shade400,
                ),
                _metricCard(
                  'For down payment',
                  '${s.catering.forDownPayment}',
                  Colors.amber.shade700,
                ),
                _metricCard(
                  'Ongoing',
                  '${s.catering.ongoing}',
                  Colors.teal.shade600,
                ),
              ]),
              const SizedBox(height: 12),
              _metricsRow([
                _metricCard(
                  'For full payment',
                  '${s.catering.forFullPayment}',
                  Colors.cyan.shade700,
                ),
                _metricCard(
                  'Completed',
                  '${s.catering.completed}',
                  Colors.green.shade700,
                ),
                _metricCard(
                  'Cancelled',
                  '${s.catering.cancelled}',
                  Colors.red.shade300,
                ),
                _metricCard(
                  'Sales today',
                  formatPhp(s.catering.salesToday),
                  Colors.blueGrey.shade600,
                ),
              ]),
              const SizedBox(height: 20),
              _sectionTitle('Sales this year'),
              _metricsRow([
                _metricCard(
                  'Restaurant',
                  formatPhp(s.salesThisYear.restaurant),
                  const Color(0xFF1E1E1E),
                ),
                _metricCard(
                  'Catering / Events',
                  formatPhp(s.salesThisYear.catering),
                  const Color(0xFF455A64),
                ),
                _metricCard(
                  'All',
                  formatPhp(s.salesThisYear.all),
                  const Color(0xFF2E7D32),
                ),
              ]),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/restaurant-orders'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Restaurant orders'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
