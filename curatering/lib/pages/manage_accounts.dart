import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/roles.dart';
import '../models/user.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';

class ManageAccounts extends StatefulWidget {
  const ManageAccounts({super.key});

  @override
  State<ManageAccounts> createState() => _ManageAccountsState();
}

class _ManageAccountsState extends State<ManageAccounts> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  String? _error;

  String _searchQuery = '';
  Role? _roleFilter;
  bool? _archivedFilter; // null = all

  List<UserDto> _users = const <UserDto>[];

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

  Role? _apiRoleFilter() => _roleFilter;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await SuperAdminApi.instance.listUsers(
        search: _searchQuery,
        role: _apiRoleFilter() == null ? null : roleToString(_apiRoleFilter()!),
        archived: _archivedFilter,
      );
      setState(() => _users = users);
    } catch (e) {
      setState(() => _error = 'Failed to load users.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUser() async {
    final fullNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    Role role = Role.supervisor;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Account'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                    TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                    TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                    const SizedBox(height: 10),
                    DropdownButton<Role>(
                      value: role,
                      items: Role.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.displayName)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => role = v ?? role),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await SuperAdminApi.instance.createUser(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        fullName: fullNameCtrl.text.trim(),
                        role: roleToString(role),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create account.')));
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) await _fetch();
  }

  Future<void> _editUser(UserDto user) async {
    final fullNameCtrl = TextEditingController(text: user.fullName);
    Role role = user.role;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Account'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                    const SizedBox(height: 10),
                    DropdownButton<Role>(
                      value: role,
                      items: Role.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.displayName)))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => role = v ?? role),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await SuperAdminApi.instance.updateUser(
                        userId: user.id,
                        fullName: fullNameCtrl.text.trim(),
                        role: roleToString(role),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update account.')));
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) await _fetch();
  }

  Future<void> _toggleArchived(UserDto user, bool nextValue) async {
    try {
      await SuperAdminApi.instance.setUserArchived(userId: user.id, archived: nextValue);
      if (!mounted) return;
      await _fetch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update archive status.')));
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
          _fetch();
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Accounts',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DropdownButton<Role?>(
                  value: _roleFilter,
                  items: [
                    const DropdownMenuItem<Role?>(value: null, child: Text('All Roles')),
                    ...Role.values.map(
                      (r) => DropdownMenuItem<Role?>(value: r, child: Text(r.displayName)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _roleFilter = v);
                    _fetch();
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<bool?>(
                  value: _archivedFilter,
                  items: const [
                    DropdownMenuItem<bool?>(value: null, child: Text('All Statuses')),
                    DropdownMenuItem<bool?>(value: false, child: Text('Active')),
                    DropdownMenuItem<bool?>(value: true, child: Text('Archived')),
                  ],
                  onChanged: (v) {
                    setState(() => _archivedFilter = v);
                    _fetch();
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _createUser,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Account'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _loading && _users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? Center(child: Text('No users found.', style: TextStyle(color: Colors.grey.shade600)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _users.map((u) {
                              return DataRow(cells: [
                                DataCell(Text(u.fullName)),
                                DataCell(Text(u.email)),
                                DataCell(Text(u.role.displayName)),
                                DataCell(
                                  Text(
                                    u.archived ? 'Archived' : 'Active',
                                    style: TextStyle(
                                      color: u.archived ? Colors.grey : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _editUser(u),
                                      ),
                                      IconButton(
                                        tooltip: u.archived ? 'Unarchive' : 'Archive',
                                        icon: Icon(u.archived ? Icons.restore : Icons.archive, size: 18),
                                        onPressed: () => _toggleArchived(u, !u.archived),
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
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
