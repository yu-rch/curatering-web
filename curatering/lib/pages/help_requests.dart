import 'dart:async';

import 'package:flutter/material.dart';

import '../models/help_request.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
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
  String _statusFilter = 'Unresolved';
  String _featureFilter = 'All';
  String _requesterFilter = 'All';
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

  List<HelpRequestDto> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _requests.where((r) {
      if (_featureFilter != 'All' && r.feature != _featureFilter) {
        return false;
      }
      if (_requesterFilter != 'All' && r.userName != _requesterFilter) {
        return false;
      }
      if (_sourceFilter == 'Public' && !_isPublicRequest(r)) return false;
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

  List<String> _distinct(Iterable<String> values) {
    final set = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) set.add(trimmed);
    }
    final out = set.toList()..sort((a, b) => a.compareTo(b));
    return ['All', ...out];
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'Unresolved';
      _featureFilter = 'All';
      _requesterFilter = 'All';
      _sourceFilter = 'All';
      _dateFilter = 'All';
    });
    _fetch();
  }

  Future<void> _resolve(HelpRequestDto req) async {
    try {
      await SuperAdminApi.instance.resolveHelpRequest(requestId: req.id);

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
    final featureOptions = _distinct(_requests.map((r) => r.feature));
    final requesterOptions = _distinct(_requests.map((r) => r.userName));
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
        subtitle: 'Review support requests and mark resolved items.',
        child: Column(
          children: [
            AntdToolbar(
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
                  value:
                      featureOptions.contains(_featureFilter)
                          ? _featureFilter
                          : 'All',
                  items:
                      featureOptions
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
                  label: 'Requester',
                  value:
                      requesterOptions.contains(_requesterFilter)
                          ? _requesterFilter
                          : 'All',
                  items:
                      requesterOptions
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _requesterFilter = value);
                  },
                ),
                AntdSelect<String>(
                  label: 'Source',
                  value: _sourceFilter,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All sources')),
                    DropdownMenuItem(value: 'Public', child: Text('Public')),
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
            const SizedBox(height: 16),
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
                                cells: [
                                  DataCell(Text(r.feature)),
                                  DataCell(Text(r.problem)),
                                  DataCell(Text(r.request)),
                                  DataCell(Text(r.createdAt.toString())),
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
                                          onPressed: () => _resolve(r),
                                        )
                                        : const Text(
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
