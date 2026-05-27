import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer_feedback.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
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
        result.source == 'runpod_nlp'
            ? 'NLP analysis ready.'
            : 'Analysis ready using ${result.source} insights.',
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

  Widget _analysisListSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Text('• '), Expanded(child: Text(item))],
              ),
            ),
          ),
        ],
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
      child: AntdPage(
        title: 'Customer Feedback',
        subtitle:
            'Feedback is submitted from delivered restaurant orders and the Contact Us page.',
        actions: [
          AntdSecondaryButton(
            label: 'Refresh',
            icon: Icons.refresh,
            onPressed: _loading ? null : _fetch,
          ),
          AntdPrimaryButton(
            label: _analyzing ? 'Analyzing...' : 'NLP Analyze',
            icon: Icons.auto_awesome,
            loading: _analyzing,
            onPressed: _analyzing || filtered.isEmpty ? null : _analyze,
          ),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableHeight =
                constraints.maxHeight.isFinite
                    ? (constraints.maxHeight * 0.72).clamp(360.0, 720.0)
                    : 620.0;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    AntdStatusTag(label: _error!, color: AntdTokens.error),
                    const SizedBox(height: 12),
                  ],
                  if (_analysis != null) ...[
                    AntdCard(
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
                              if (_analysis!.sentiment.trim().isNotEmpty) ...[
                                AntdStatusTag(
                                  label: _analysis!.sentiment,
                                  color: AntdTokens.info,
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (_analysis!.averageStars != null)
                                AntdStatusTag(
                                  label:
                                      'Avg ${_analysis!.averageStars!.toStringAsFixed(1)} stars · ${_analysis!.feedbackCount} reviews',
                                  color: AntdTokens.warning,
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
                          _analysisListSection(
                            'Key topics',
                            _analysis!.keyTopics,
                          ),
                          _analysisListSection(
                            'Complaints',
                            _analysis!.complaints,
                          ),
                          _analysisListSection('Praises', _analysis!.praises),
                          _analysisListSection('Insights', _analysis!.insights),
                          _analysisListSection(
                            'Recommendations',
                            _analysis!.recommendations,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: tableHeight,
                    child:
                        _loading
                            ? const AntdLoadingState()
                            : filtered.isEmpty
                            ? const AntdEmptyState(
                              message: 'No customer feedback yet.',
                            )
                            : PagedDataTable(
                              title: 'Customer Feedback',
                              enableSearch: false,
                              fullWidth: true,
                              maxTableHeight: tableHeight,
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
                                              f.remarks.isEmpty
                                                  ? '—'
                                                  : f.remarks,
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
            );
          },
        ),
      ),
    );
  }
}
