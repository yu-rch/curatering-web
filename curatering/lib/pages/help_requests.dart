import 'dart:async';

import 'package:flutter/material.dart';

import '../models/help_request.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';

class HelpRequestsPage extends StatefulWidget {
  const HelpRequestsPage({super.key});

  @override
  State<HelpRequestsPage> createState() => _HelpRequestsPageState();
}

class _HelpRequestsPageState extends State<HelpRequestsPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = ['All', 'Unresolved', 'Resolved'];
  String _statusFilter = 'Unresolved';
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
    if (q.isEmpty) return _requests;
    return _requests.where((r) {
      return [
        r.userName,
        r.feature,
        r.problem,
        r.request,
      ].any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _resolve(HelpRequestDto req) async {
    try {
      await SuperAdminApi.instance.resolveHelpRequest(requestId: req.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Help request resolved; notification sent.')),
      );
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resolve request.')),
      );
    }
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
              'Help Requests',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DropdownButton<String>(
                  value: _statusFilter,
                  items: _statusOptions
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
                const SizedBox(width: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
                        _loading ? 'Loading...' : 'No help requests found.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Feature')),
                          DataColumn(label: Text('Problem')),
                          DataColumn(label: Text('Request')),
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _filtered.map((r) {
                          final isUnresolved = r.status == HelpRequestStatus.unresolved;
                          return DataRow(
                            cells: [
                              DataCell(Text(r.feature)),
                              DataCell(Text(r.problem)),
                              DataCell(Text(r.request)),
                              DataCell(Text(r.createdAt.toString())),
                              DataCell(
                                Text(
                                  r.status == HelpRequestStatus.unresolved ? 'Unresolved' : 'Resolved',
                                  style: TextStyle(
                                    color: isUnresolved ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                isUnresolved
                                    ? ElevatedButton(
                                        onPressed: () => _resolve(r),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Resolve'),
                                      )
                                    : const Text('-', style: TextStyle(color: Colors.grey)),
                              ),
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

