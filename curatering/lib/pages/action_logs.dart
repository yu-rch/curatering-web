import 'dart:async';

import 'package:flutter/material.dart';

import '../models/action_log.dart';
import '../models/user.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/paginated_data_table.dart';

enum _DateFilterPreset { all, today, yesterday, last7Days, thisMonth, custom }

/// Fixed Action filter options (matched fuzzily against logged action text).
const _kActionFilterOptions = <String>[
  'All',
  'Delete / Remove',
  'Archive',
  'Unarchive',
  'Upload / Image / File upload',
  'Super admin password confirmation',
  'Payment confirmation',
  'Confirmation',
  'Create account',
  'Create order',
  'Create event',
];

/// All modules from Dashboard through POS (sidebar + related admin pages).
const _kFeatureFilterOptions = <String>[
  'All',
  'Dashboard',
  'Manage Events',
  'Loyalty Rewards',
  'Catering/Restaurant Menu',
  'Inventory',
  'Restaurant Orders',
  'Reports',
  'Order History',
  'Archive',
  'Help Requests Management',
  'Customer Feedback',
  'Website CMS',
  'Manage Accounts',
  'Customer Management',
  'Action Logs',
  'POS',
  'Settings',
  'Catering',
  'Events',
];

class ActionLogsPage extends StatefulWidget {
  const ActionLogsPage({super.key});

  @override
  State<ActionLogsPage> createState() => _ActionLogsPageState();
}

class _ActionLogsPageState extends State<ActionLogsPage> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  String? _error;

  String _searchQuery = '';
  String _userFilter = 'All';
  String _featureFilter = 'All';
  String _actionFilter = 'All';
  _DateFilterPreset _datePreset = _DateFilterPreset.all;
  DateTimeRange? _customDateRange;

  List<ActionLogDto> _logs = const <ActionLogDto>[];
  List<String> _staffUsers = const <String>['All'];

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
      // Load logs first so a users-filter failure cannot blank the page.
      final data = await SuperAdminApi.instance.listActionLogs();
      var staffNames = <String>['All'];
      try {
        final users = await SuperAdminApi.instance.listUsers(archived: false);
        final names =
            users
                .map((u) => u.fullName.trim())
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        // Also include names present only in logs (deleted / unmatched users).
        final fromLogs =
            data
                .map((l) => l.userName.trim())
                .where((n) => n.isNotEmpty && n != 'Unknown user')
                .toSet();
        staffNames = ['All', ...{...names, ...fromLogs}.toList()..sort()];
      } catch (_) {
        final fromLogs =
            data
                .map((l) => l.userName.trim())
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        staffNames = ['All', ...fromLogs];
      }

      if (!mounted) return;
      setState(() {
        _logs = data;
        _staffUsers = staffNames;
        if (_userFilter != 'All' && !_staffUsers.contains(_userFilter)) {
          _userFilter = 'All';
        }
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load action logs.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesActionFilter(String actionText, String filter) {
    if (filter == 'All') return true;
    final a = actionText.toLowerCase();
    switch (filter) {
      case 'Delete / Remove':
        return a.contains('delete') ||
            a.contains('remove') ||
            a.contains('removed');
      case 'Archive':
        return a.contains('archive') && !a.contains('unarchive');
      case 'Unarchive':
        return a.contains('unarchive') || a.contains('restore');
      case 'Upload / Image / File upload':
        return a.contains('upload') ||
            a.contains('image') ||
            a.contains('file');
      case 'Super admin password confirmation':
        return a.contains('super admin') ||
            a.contains('password confirm') ||
            a.contains('password confirmation');
      case 'Payment confirmation':
        return a.contains('payment') &&
            (a.contains('confirm') || a.contains('paid') || a.contains('mark'));
      case 'Confirmation':
        return a.contains('confirm') && !a.contains('payment');
      case 'Create account':
        return a.contains('create') && a.contains('account');
      case 'Create order':
        return a.contains('create') && a.contains('order');
      case 'Create event':
        return a.contains('create') && a.contains('event');
      default:
        return a.contains(filter.toLowerCase());
    }
  }

  bool _matchesFeatureFilter(String featureText, String filter) {
    if (filter == 'All') return true;
    final f = featureText.toLowerCase().trim();
    final selected = filter.toLowerCase().trim();
    if (f == selected) return true;
    // Allow loose matching for variant labels used when logging.
    if (selected == 'manage events' &&
        (f.contains('event') || f.contains('manage events'))) {
      return true;
    }
    if (selected == 'pos' &&
        (f.contains('pos') || f.contains('restaurant order'))) {
      return true;
    }
    if (selected == 'catering/restaurant menu' && f.contains('menu')) {
      return true;
    }
    if (selected == 'website cms' && (f.contains('cms') || f.contains('website'))) {
      return true;
    }
    return f.contains(selected) || selected.contains(f);
  }

  DateTimeRange? get _activeDateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_datePreset) {
      case _DateFilterPreset.all:
        return null;
      case _DateFilterPreset.today:
        return DateTimeRange(start: today, end: today);
      case _DateFilterPreset.yesterday:
        final day = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: day, end: day);
      case _DateFilterPreset.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _DateFilterPreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
      case _DateFilterPreset.custom:
        return _customDateRange;
    }
  }

  List<ActionLogDto> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    final range = _activeDateRange;
    return _logs.where((l) {
      final matchesUser = _userFilter == 'All' || l.userName == _userFilter;
      final matchesFeature = _matchesFeatureFilter(l.feature, _featureFilter);
      final matchesAction = _matchesActionFilter(l.action, _actionFilter);
      final localDate = l.createdAt.toLocal();
      final logDay = DateTime(localDate.year, localDate.month, localDate.day);
      final matchesDate =
          range == null ||
          (!logDay.isBefore(range.start) && !logDay.isAfter(range.end));
      final matchesSearch =
          q.isEmpty
              ? true
              : [
                l.userName,
                l.feature,
                l.action,
                l.other,
              ].any((v) => v.toLowerCase().contains(q));
      return matchesUser &&
          matchesFeature &&
          matchesAction &&
          matchesDate &&
          matchesSearch;
    }).toList();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _dateRangeLabel() {
    final range = _customDateRange;
    if (range == null) return 'Pick custom range';
    String d(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return '${d(range.start)} to ${d(range.end)}';
  }

  void _clearFilters() {
    setState(() {
      _userFilter = 'All';
      _featureFilter = 'All';
      _actionFilter = 'All';
      _datePreset = _DateFilterPreset.all;
      _customDateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (picked == null) return;
    setState(() {
      _customDateRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      _datePreset = _DateFilterPreset.custom;
    });
  }

  void _showLogDetails(ActionLogDto log) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Action details'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('User', log.userName),
                  _detailRow('Feature', log.feature.isEmpty ? '—' : log.feature),
                  _detailRow('Action', log.action),
                  _detailRow('Date & time', _formatDateTime(log.createdAt)),
                  _detailRow('Other', log.other.isEmpty ? '—' : log.other),
                  _detailRow('Log ID', log.id),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AntdTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _filterToolbar() {
    final featureItems = <String>{
      ..._kFeatureFilterOptions,
      ..._logs.map((l) => l.feature.trim()).where((f) => f.isNotEmpty),
    }.toList();
    // Keep "All" first, then sort the rest.
    final features = [
      'All',
      ...featureItems.where((f) => f != 'All').toList()..sort(),
    ];

    return AntdToolbar(
      elevated: false,
      padding: EdgeInsets.zero,
      children: [
        AntdSelect<String>(
          label: 'User',
          value: _staffUsers.contains(_userFilter) ? _userFilter : 'All',
          items:
              _staffUsers
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
          onChanged: (v) => setState(() => _userFilter = v ?? 'All'),
        ),
        AntdSelect<String>(
          label: 'Feature',
          value: features.contains(_featureFilter) ? _featureFilter : 'All',
          items:
              features
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
          onChanged: (v) => setState(() => _featureFilter = v ?? 'All'),
        ),
        AntdSelect<String>(
          label: 'Action',
          value:
              _kActionFilterOptions.contains(_actionFilter)
                  ? _actionFilter
                  : 'All',
          items:
              _kActionFilterOptions
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
          onChanged: (v) => setState(() => _actionFilter = v ?? 'All'),
        ),
        AntdSelect<_DateFilterPreset>(
          label: 'Datetime',
          value: _datePreset,
          items: const [
            DropdownMenuItem(value: _DateFilterPreset.all, child: Text('All')),
            DropdownMenuItem(
              value: _DateFilterPreset.today,
              child: Text('Today'),
            ),
            DropdownMenuItem(
              value: _DateFilterPreset.yesterday,
              child: Text('Yesterday'),
            ),
            DropdownMenuItem(
              value: _DateFilterPreset.last7Days,
              child: Text('Last 7 days'),
            ),
            DropdownMenuItem(
              value: _DateFilterPreset.thisMonth,
              child: Text('This month'),
            ),
            DropdownMenuItem(
              value: _DateFilterPreset.custom,
              child: Text('Custom range'),
            ),
          ],
          onChanged:
              (v) => setState(() {
                _datePreset = v ?? _DateFilterPreset.all;
              }),
        ),
        AntdSecondaryButton(
          label: _dateRangeLabel(),
          icon: Icons.date_range,
          onPressed: _pickCustomDateRange,
        ),
        AntdSecondaryButton(
          label: 'Clear filters',
          icon: Icons.filter_alt_off,
          onPressed: _clearFilters,
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
        title: 'Action Logs',
        subtitle: 'Audit staff activity by user, feature, action, and date.',
        filters: _filterToolbar(),
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
                      : filtered.isEmpty
                      ? const AntdEmptyState(message: 'No action logs found.')
                      : PagedDataTable(
                        title: 'Action Logs',
                        enableSearch: false,
                        fullWidth: false,
                        minTableWidth: 1280,
                        columnSpacing: 32,
                        columns: const [
                          DataColumn(
                            label: SizedBox(width: 140, child: Text('User')),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 140,
                              child: Text('Feature'),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 280,
                              child: Text('Action'),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 160,
                              child: Text('Date & Time'),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 320,
                              child: Text('Other'),
                            ),
                          ),
                        ],
                        rows:
                            filtered.map((l) {
                              return DataRow(
                                onSelectChanged: (_) => _showLogDetails(l),
                                cells: [
                                  DataCell(
                                    Text(l.userName),
                                    onTap: () => _showLogDetails(l),
                                  ),
                                  DataCell(
                                    Text(l.feature),
                                    onTap: () => _showLogDetails(l),
                                  ),
                                  DataCell(
                                    Text(l.action),
                                    onTap: () => _showLogDetails(l),
                                  ),
                                  DataCell(
                                    Text(_formatDateTime(l.createdAt)),
                                    onTap: () => _showLogDetails(l),
                                  ),
                                  DataCell(
                                    Text(l.other),
                                    onTap: () => _showLogDetails(l),
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
