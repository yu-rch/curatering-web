import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/help_request_features.dart';
import '../models/help_request.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/antd_form_field.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/paginated_data_table.dart';
class HelpRequestsPage extends StatefulWidget {
  const HelpRequestsPage({super.key});
  @override
  State<HelpRequestsPage> createState() => _HelpRequestsPageState();
}
class _HelpRequestsPageState extends State<HelpRequestsPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusOptions = ['All', 'Unresolved', 'Resolved'];
  String _statusFilter = 'All';
  String _featureFilter = 'All';
  String _sourceFilter = 'All';
  String _dateFilter = 'All';
  String _searchQuery = '';
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<HelpRequestDto> _requests = const <HelpRequestDto>[];
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
  String? _apiStatusFilter() {
    return switch (_statusFilter) {
      'Unresolved' => 'unresolved',
      'Resolved' => 'resolved',
      _ => null,
    };
  }
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SuperAdminApi.instance.listHelpRequests(
        status: _apiStatusFilter(),
      );
      setState(() {
        _requests = data;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load help requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  bool _featureMatches(HelpRequestDto request, String filter) {
    if (filter == 'All') return true;
    final feature = request.feature.trim().toLowerCase();
    final needle = filter.trim().toLowerCase();
    return feature == needle;
  }
  List<HelpRequestDto> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _requests.where((r) {
      if (!_featureMatches(r, _featureFilter)) return false;
      if (_sourceFilter == 'Customer' && !_isPublicRequest(r)) return false;
      if (_sourceFilter == 'Staff' && _isPublicRequest(r)) return false;
      if (!_matchesDateFilter(r.createdAt)) return false;
      if (q.isEmpty) return true;
      return [
        r.userName,
        r.feature,
        r.problem,
        r.request,
      ].any((v) => v.toLowerCase().contains(q));
    }).toList();
  }
  bool _isPublicRequest(HelpRequestDto request) {
    final id = request.userId.trim().toLowerCase();
    return id.isEmpty || id == 'null';
  }
  String _sourceLabel(HelpRequestDto request) {
    return _isPublicRequest(request) ? 'Customer' : 'Staff';
  }
  bool _matchesDateFilter(DateTime value) {
    if (_dateFilter == 'All') return true;
    final now = DateTime.now();
    final local = value.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    if (_dateFilter == 'Today') return !local.isBefore(today);
    if (_dateFilter == 'Last 7 days') {
      return !local.isBefore(now.subtract(const Duration(days: 7)));
    }
    if (_dateFilter == 'Last 30 days') {
      return !local.isBefore(now.subtract(const Duration(days: 30)));
    }
    return true;
  }
  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _featureFilter = 'All';
      _sourceFilter = 'All';
      _dateFilter = 'All';
    });
    _fetch();
  }
  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AntdTokens.labelMuted,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
  Future<void> _showHelpRequestDetail(HelpRequestDto req) async {
    await showAntdModal<void>(
      context: context,
      title: 'Help request',
      maxWidth: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailRow('Feature', req.feature),
          _detailRow('Source', _sourceLabel(req)),
          _detailRow('Requester', req.userName),
          _detailRow('Problem', req.problem),
          _detailRow('Request details', req.request),
          _detailRow('Status', req.status == HelpRequestStatus.unresolved ? 'Unresolved' : 'Resolved'),
          _detailRow('Submitted', _formatDateTime(req.createdAt)),
          if (req.resolutionNotes.trim().isNotEmpty)
            _detailRow('Resolution notes', req.resolutionNotes),
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
  Future<void> _confirmResolve(HelpRequestDto req) async {
    final resolutionCtrl = TextEditingController();
    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Resolve help request?',
      maxWidth: 560,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm that this software issue has been resolved. Describe how it was fixed — the requester will be notified.',
          ),
          const SizedBox(height: 12),
          AntdFieldShell(
            label: 'How was this resolved?',
            child: AntdOutlineInput(
              controller: resolutionCtrl,
              hintText: 'Describe the fix or resolution steps',
              maxLines: 6,
            ),
          ),
        ],
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AntdPrimaryButton(
          label: 'Resolve',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    final notes = resolutionCtrl.text.trim();
    resolutionCtrl.dispose();
    if (ok != true || !mounted) return;
    try {
      await SuperAdminApi.instance.resolveHelpRequest(
        requestId: req.id,
        resolutionNotes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      showAntdMessage(context, 'Help request resolved; notification sent.');
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(
        context,
        'Failed to resolve request.',
        type: AntdMessageType.error,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      searchHint: 'Search help requests',
      searchController: _searchController,
      onSearchChanged: (query) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          setState(() => _searchQuery = query);
        });
      },
      child: AntdPage(
        title: 'Help Requests Management',
        subtitle:
            'Review software support requests from staff and customers.',
        filters: AntdToolbar(
          elevated: false,
          padding: EdgeInsets.zero,
          children: [
            AntdSelect<String>(
              label: 'Status',
              value: _statusFilter,
              items:
                  _statusOptions
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _statusFilter = value);
                _fetch();
              },
            ),
            AntdSelect<String>(
              label: 'Feature',
              value: _featureFilter,
              items:
                  kHelpRequestFeatureFilterOptions
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _featureFilter = value);
              },
            ),
            AntdSelect<String>(
              label: 'Source',
              value: _sourceFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All sources')),
                DropdownMenuItem(value: 'Customer', child: Text('Customer')),
                DropdownMenuItem(value: 'Staff', child: Text('Staff')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _sourceFilter = value);
              },
            ),
            AntdSelect<String>(
              label: 'Date',
              value: _dateFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All dates')),
                DropdownMenuItem(value: 'Today', child: Text('Today')),
                DropdownMenuItem(
                  value: 'Last 7 days',
                  child: Text('Last 7 days'),
                ),
                DropdownMenuItem(
                  value: 'Last 30 days',
                  child: Text('Last 30 days'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _dateFilter = value);
              },
            ),
            AntdSecondaryButton(
              label: 'Clear filters',
              icon: Icons.filter_alt_off,
              onPressed: _clearFilters,
            ),
            AntdStatusTag(
              label: '${_filtered.length} shown',
              color: AntdTokens.textSecondary,
            ),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_error != null)
              AntdSecondaryButton(
                label: 'Reload',
                icon: Icons.refresh,
                onPressed: _fetch,
              ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child:
                  _loading
                      ? const AntdLoadingState()
                      : _error != null
                      ? Center(
                        child: AntdSecondaryButton(
                          label: 'Reload',
                          icon: Icons.refresh,
                          onPressed: _fetch,
                        ),
                      )
                      : _filtered.isEmpty
                      ? const AntdEmptyState(message: 'No help requests found.')
                      : PagedDataTable(
                        title: 'Help Requests',
                        enableSearch: false,
                        fullWidth: true,
                        columns: const [
                          DataColumn(label: Text('Feature')),
                          DataColumn(label: Text('Problem')),
                          DataColumn(label: Text('Request')),
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows:
                            _filtered.map((r) {
                              final isUnresolved =
                                  r.status == HelpRequestStatus.unresolved;
                              return DataRow(
                                onSelectChanged: (_) => _showHelpRequestDetail(r),
                                cells: [
                                  DataCell(Text(r.feature)),
                                  DataCell(Text(r.problem)),
                                  DataCell(Text(r.request)),
                                  DataCell(Text(_formatDateTime(r.createdAt))),
                                  DataCell(
                                    AntdStatusTag(
                                      label:
                                          isUnresolved
                                              ? 'Unresolved'
                                              : 'Resolved',
                                      color:
                                          isUnresolved
                                              ? AntdTokens.error
                                              : AntdTokens.success,
                                    ),
                                  ),
                                  DataCell(
                                    isUnresolved
                                        ? AntdPrimaryButton(
                                          label: 'Resolve',
                                          icon: Icons.check,
                                          onPressed: () => _confirmResolve(r),
                                        )
                                        : Text(
                                          '-',
                                          style: TextStyle(
                                            color: AntdTokens.labelMuted,
                                          ),
                                        ),
                                  ),
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
