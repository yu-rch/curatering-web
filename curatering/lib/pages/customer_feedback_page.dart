import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer_feedback.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_message.dart';
import '../widgets/paginated_data_table.dart';

class CustomerFeedbackPage extends StatefulWidget {
  const CustomerFeedbackPage({super.key});

  @override
  State<CustomerFeedbackPage> createState() => _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends State<CustomerFeedbackPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  bool _analyzing = false;
  String? _error;
  String _searchQuery = '';
  List<CustomerFeedbackDto> _items = const [];
  CustomerFeedbackAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SuperAdminApi.instance.listCustomerFeedback(
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );
      if (mounted) setState(() => _items = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load customer feedback.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    try {
      final result = await SuperAdminApi.instance.analyzeCustomerFeedback(
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );
      if (!mounted) return;
      setState(() => _analysis = result);
      showAntdMessage(
        context,
        result.source == 'openai'
            ? 'AI analysis ready.'
            : 'Analysis ready (configure OPENAI_API_KEY on the server for full AI insights).',
      );
    } catch (_) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Failed to analyze feedback.',
        type: AntdMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  List<CustomerFeedbackDto> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((f) {
      return [
        f.orderNo,
        f.customerName,
        f.customerEmail,
        f.remarks,
        '${f.stars}',
      ].any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _starsCell(int stars) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < stars ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber.shade700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged: (query) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          setState(() => _searchQuery = query);
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Customer Feedback',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _fetch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      _analyzing || filtered.isEmpty ? null : _analyze,
                  icon:
                      _analyzing
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.auto_awesome),
                  label: Text(_analyzing ? 'Analyzing…' : 'AI summarize'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Feedback is submitted by customers on delivered restaurant orders. '
              'Use AI summarize for themes, interpretation, and recommendations.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (_analysis != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI insights',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (_analysis!.averageStars != null)
                            Text(
                              'Avg ${_analysis!.averageStars!.toStringAsFixed(1)} ★ · ${_analysis!.feedbackCount} reviews',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _analysis!.summary,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(_analysis!.interpretation),
                      if (_analysis!.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Recommendations',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        ..._analysis!.recommendations.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(r)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                        child: Text(
                          'No customer feedback yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                      : PagedDataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade100,
                        ),
                        columns: const [
                          DataColumn(label: Text('Order')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Rating')),
                          DataColumn(label: Text('Remarks')),
                          DataColumn(label: Text('Submitted')),
                        ],
                        rows:
                            filtered.map((f) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(f.orderNo)),
                                  DataCell(Text(f.customerName)),
                                  DataCell(Text(f.customerEmail)),
                                  DataCell(_starsCell(f.stars)),
                                  DataCell(
                                    SizedBox(
                                      width: 280,
                                      child: Text(
                                        f.remarks.isEmpty ? '—' : f.remarks,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_fmt(f.submittedAt))),
                                ],
                              );
                            }).toList(),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
