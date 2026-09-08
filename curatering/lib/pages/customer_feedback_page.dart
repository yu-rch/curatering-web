import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer_feedback.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_dialog.dart';
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
      final result = await SuperAdminApi.instance.analyzeCustomerFeedback();
      if (!mounted) return;
      await _showAnalysisDialog(result);
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

  Future<void> _showAnalysisDialog(CustomerFeedbackAnalysis analysis) async {
    await showAntdModal<void>(
      context: context,
      title: 'NLP feedback analysis',
      maxWidth: 720,
      scrollBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (analysis.sentiment.trim().isNotEmpty) ...[
                AntdStatusTag(
                  label: analysis.sentiment,
                  color: AntdTokens.info,
                ),
                const SizedBox(width: 8),
              ],
              if (analysis.averageStars != null)
                AntdStatusTag(
                  label:
                      'Avg ${analysis.averageStars!.toStringAsFixed(1)} stars · ${analysis.feedbackCount} reviews',
                  color: AntdTokens.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analysis.summary,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(analysis.interpretation),
          _analysisListSection('Key topics', analysis.keyTopics),
          _analysisListSection('Complaints', analysis.complaints),
          _analysisListSection('Praises', analysis.praises),
          _analysisListSection('Insights', analysis.insights),
          _analysisListSection('Recommendations', analysis.recommendations),
        ],
      ),
      actions: [
        AntdPrimaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _showFeedbackDetail(CustomerFeedbackDto feedback) async {
    await showAntdModal<void>(
      context: context,
      title: 'Customer feedback',
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Order', feedback.orderNo),
          _detailRow('Customer', feedback.customerName),
          _detailRow('Email', feedback.customerEmail),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rating',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AntdTokens.labelMuted,
                  ),
                ),
                const SizedBox(height: 4),
                _starsCell(feedback.stars),
              ],
            ),
          ),
          _detailRow('Remarks', feedback.remarks.isEmpty ? '—' : feedback.remarks),
          _detailRow('Submitted', _fmt(feedback.submittedAt)),
        ],
      ),
      actions: [
        AntdPrimaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AntdTokens.labelMuted,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
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
            'Feedback is submitted from completed restaurant/catering orders and the Contact Us page.',
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
            onPressed: _analyzing || _items.isEmpty ? null : _analyze,
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
                    Row(
                      children: [
                        Expanded(
                          child: AntdStatusTag(
                            label: _error!,
                            color: AntdTokens.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AntdSecondaryButton(
                          label: 'Reload',
                          icon: Icons.refresh,
                          onPressed: _fetch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                                      onSelectChanged: (_) => _showFeedbackDetail(f),
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
