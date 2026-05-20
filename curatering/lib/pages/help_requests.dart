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
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_error != null)
                  const AntdStatusTag(
                    label: 'Failed to load',
                    color: AntdTokens.error,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _loading
                      ? const AntdLoadingState()
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
