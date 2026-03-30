import 'dart:async';

import 'package:flutter/material.dart';

import '../models/action_log.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';

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
  String _featureFilter = 'All';

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

  List<String> get _features {
    final set = <String>{};
    for (final l in _logs) {
      final f = l.feature.trim();
      if (f.isNotEmpty) set.add(f);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<ActionLogDto> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _logs.where((l) {
      final matchesFeature = _featureFilter == 'All' || l.feature == _featureFilter;
      final matchesSearch = q.isEmpty
          ? true
          : [
              l.userName,
              l.feature,
              l.action,
              l.other,
            ].any((v) => v.toLowerCase().contains(q));
      return matchesFeature && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Action Logs',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DropdownButton<String>(
                  value: _featureFilter,
                  items: _features
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _featureFilter = v);
                  },
                ),
                const Spacer(),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _loading ? 'Loading...' : 'No action logs found.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Feature')),
                          DataColumn(label: Text('Action')),
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Other')),
                        ],
                        rows: _filtered.map((l) {
                          return DataRow(
                            cells: [
                              DataCell(Text(l.userName)),
                              DataCell(Text(l.feature)),
                              DataCell(Text(l.action)),
                              DataCell(Text(l.createdAt.toString())),
                              DataCell(Text(l.other)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

