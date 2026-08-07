import 'dart:async';

import 'package:flutter/material.dart';

import '../models/action_log.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/paginated_data_table.dart';

enum _DateFilterPreset { all, today, yesterday, last7Days, thisMonth, custom }

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
      final data = await SuperAdminApi.instance.listActionLogs();
      setState(() => _logs = data);
    } catch (e) {
      setState(() => _error = 'Failed to load action logs.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _users => _distinct((l) => l.userName);

  List<String> get _features => _distinct((l) => l.feature);

  List<String> get _actions => _distinct((l) => l.action);

  List<String> _distinct(String Function(ActionLogDto log) pick) {
    final set = <String>{};
    for (final l in _logs) {
      final value = pick(l).trim();
      if (value.isNotEmpty) set.add(value);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
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
      final matchesFeature =
          _featureFilter == 'All' || l.feature == _featureFilter;
      final matchesAction = _actionFilter == 'All' || l.action == _actionFilter;
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

  Widget _filterToolbar() {
    return AntdToolbar(
      children: [
        AntdSelect<String>(
          label: 'User',
          value: _userFilter,
          items:
              _users
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
          onChanged: (v) => setState(() => _userFilter = v ?? 'All'),
        ),
        AntdSelect<String>(
          label: 'Feature',
          value: _featureFilter,
          items:
              _features
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
          onChanged: (v) => setState(() => _featureFilter = v ?? 'All'),
        ),
        AntdSelect<String>(
          label: 'Action',
          value: _actionFilter,
          items:
              _actions
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
        child: Column(
          children: [
            _filterToolbar(),
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
                      : filtered.isEmpty
                      ? const AntdEmptyState(message: 'No action logs found.')
                      : PagedDataTable(
                        title: 'Action Logs',
                        enableSearch: false,
                        fullWidth: true,
                        columns: const [
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Feature')),
                          DataColumn(label: Text('Action')),
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Other')),
                        ],
                        rows:
                            filtered.map((l) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(l.userName)),
                                  DataCell(Text(l.feature)),
                                  DataCell(Text(l.action)),
                                  DataCell(Text(_formatDateTime(l.createdAt))),
                                  DataCell(Text(l.other)),
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
