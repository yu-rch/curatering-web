import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/page_permissions.dart';
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
  UserDto? _selectedUser;

  /// Working copy for toggles; keys are routes from [PagePermissionRoutes.togglesForStaff].
  Map<String, dynamic> _pagePermissionDraft = {};
  bool _savingPermissions = false;

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

  void _initPermissionDraft(UserDto user) {
    final m = <String, dynamic>{};
    final existing = user.pagePermissions;
    for (final entry in PagePermissionRoutes.togglesForStaff) {
      final route = entry.$2;
      if (existing != null && existing.containsKey(route)) {
        m[route] = existing[route] == true;
      } else {
        m[route] = true;
      }
    }
    _pagePermissionDraft = m;
  }

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
      setState(() {
        _users = users;
        if (_selectedUser != null) {
          final id = _selectedUser!.id;
          final still = users.where((u) => u.id == id).toList();
          _selectedUser = still.isEmpty ? null : still.first;
          if (_selectedUser != null) _initPermissionDraft(_selectedUser!);
        }
      });
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
    final birthdayCtrl = TextEditingController();
    final contactNumberCtrl = TextEditingController();
    Role role = Role.supervisor;
    String employmentType = 'regular';
    String? errorMessage;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: Colors.black),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Form fields
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'FULL NAME',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: fullNameCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'EMAIL',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: emailCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'PASSWORD',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: passwordCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  obscureText: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'BIRTHDAY',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: birthdayCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    hintText: 'YYYY-MM-DD',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'CONTACT NUMBER',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: contactNumberCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('ROLE:', style: TextStyle(fontSize: 11)),
                          DropdownButton<Role>(
                            isExpanded: true,
                            value: role,
                            items:
                                Role.values
                                    .where((r) => r != Role.admin)
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.displayName),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setStateDialog(() => role = v ?? role),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'EMPLOYMENT TYPE:',
                            style: TextStyle(fontSize: 11),
                          ),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: employmentType,
                            items: const [
                              DropdownMenuItem(
                                value: 'regular',
                                child: Text('Regular'),
                              ),
                              DropdownMenuItem(
                                value: 'part_time',
                                child: Text('Part-time'),
                              ),
                            ],
                            onChanged:
                                (v) => setStateDialog(
                                  () => employmentType = v ?? employmentType,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit button
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await SuperAdminApi.instance.createUser(
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text,
                            fullName: fullNameCtrl.text.trim(),
                            role: roleToString(role),
                            birthday:
                                birthdayCtrl.text.trim().isEmpty
                                    ? null
                                    : birthdayCtrl.text.trim(),
                            contactNumber:
                                contactNumberCtrl.text.trim().isEmpty
                                    ? null
                                    : contactNumberCtrl.text.trim(),
                            employmentType: employmentType,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (_) {
                          if (!context.mounted) return;
                          setStateDialog(
                            () => errorMessage = 'Failed to create account.',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CREATE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _fetch();
  }

  Future<void> _editUser(UserDto user) async {
    final fullNameCtrl = TextEditingController(text: user.fullName);
    final birthdayCtrl = TextEditingController(text: user.birthday ?? '');
    final contactNumberCtrl = TextEditingController(
      text: user.contactNumber ?? '',
    );
    Role role = user.role;
    String employmentType = user.employmentType ?? 'regular';
    String? errorMessage;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: Colors.black),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    const Text(
                      'EDIT ACCOUNT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Form fields
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'FULL NAME',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: fullNameCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'BIRTHDAY',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: birthdayCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    hintText: 'YYYY-MM-DD',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  'CONTACT NUMBER',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: contactNumberCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('ROLE:', style: TextStyle(fontSize: 11)),
                          DropdownButton<Role>(
                            isExpanded: true,
                            value: role,
                            items:
                                Role.values
                                    .where((r) => r != Role.admin)
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.displayName),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setStateDialog(() => role = v ?? role),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'EMPLOYMENT TYPE:',
                            style: TextStyle(fontSize: 11),
                          ),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: employmentType,
                            items: const [
                              DropdownMenuItem(
                                value: 'regular',
                                child: Text('Regular'),
                              ),
                              DropdownMenuItem(
                                value: 'part_time',
                                child: Text('Part-time'),
                              ),
                            ],
                            onChanged:
                                (v) => setStateDialog(
                                  () => employmentType = v ?? employmentType,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit button
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await SuperAdminApi.instance.updateUser(
                            userId: user.id,
                            fullName: fullNameCtrl.text.trim(),
                            role: roleToString(role),
                            birthday:
                                birthdayCtrl.text.trim().isEmpty
                                    ? null
                                    : birthdayCtrl.text.trim(),
                            contactNumber:
                                contactNumberCtrl.text.trim().isEmpty
                                    ? null
                                    : contactNumberCtrl.text.trim(),
                            employmentType: employmentType,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (_) {
                          if (!context.mounted) return;
                          setStateDialog(
                            () => errorMessage = 'Failed to update account.',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'SAVE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) await _fetch();
  }

  Future<void> _toggleArchived(UserDto user, bool nextValue) async {
    try {
      await SuperAdminApi.instance.setUserArchived(
        userId: user.id,
        archived: nextValue,
      );
      if (!mounted) return;
      await _fetch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update archive status.')),
      );
    }
  }

  Future<void> _persistPagePermissions() async {
    final u = _selectedUser;
    if (u == null || u.role == Role.superAdmin) return;
    setState(() => _savingPermissions = true);
    try {
      await SuperAdminApi.instance.updateUserPagePermissions(
        userId: u.id,
        pagePermissions: Map<String, dynamic>.from(_pagePermissionDraft),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Page access updated.')));
      await _fetch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save page access.')),
      );
    } finally {
      if (mounted) setState(() => _savingPermissions = false);
    }
  }

  Widget _buildUserAccessPanel() {
    final u = _selectedUser;
    if (u == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text('Select an account to view details and page access.'),
          ),
        ),
      );
    }

    final isCurrentUserSuperAdmin =
        AuthSession.instance.currentRole == Role.superAdmin;

    if (u.role == Role.superAdmin) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(u.email, style: TextStyle(color: Colors.grey.shade700)),
              if (isCurrentUserSuperAdmin) ...[
                const SizedBox(height: 4),
                Text(
                  'ID: ${u.id}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Super Admin accounts always have full access to all areas.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              u.fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(u.email, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(
              'Role: ${u.role.displayName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (u.birthday != null && u.birthday!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Birthday: ${u.birthday}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (u.contactNumber != null && u.contactNumber!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Contact: ${u.contactNumber}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (u.employmentType != null && u.employmentType!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Employment: ${u.employmentType == 'part_time' ? 'Part-time' : 'Regular'}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (isCurrentUserSuperAdmin) ...[
              const SizedBox(height: 4),
              Text(
                'ID: ${u.id}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'USER ACCESS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn pages on or off for this user. They must sign out and back in for changes to apply everywhere.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...PagePermissionRoutes.togglesForStaff.map((e) {
              final label = e.$1;
              final route = e.$2;
              final allowed = (_pagePermissionDraft[route] as bool?) ?? true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      allowed ? 'Allowed' : 'Blocked',
                      style: TextStyle(
                        color:
                            allowed
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed:
                          _savingPermissions
                              ? null
                              : () {
                                setState(() {
                                  _pagePermissionDraft[route] = !allowed;
                                });
                                _persistPagePermissions();
                              },
                      child: Text(allowed ? 'Don\'t allow' : 'Allow'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
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
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Create staff accounts and manage page-level permissions.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DropdownButton<Role?>(
                  value: _roleFilter,
                  items: [
                    const DropdownMenuItem<Role?>(
                      value: null,
                      child: Text('All Roles'),
                    ),
                    ...Role.values
                        .where((r) => r != Role.admin)
                        .map(
                          (r) => DropdownMenuItem<Role?>(
                            value: r,
                            child: Text(r.displayName),
                          ),
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
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: false,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text('Archived'),
                    ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
            ],
            Expanded(
              child:
                  _loading && _users.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _users.isEmpty
                      ? Center(
                        child: Text(
                          'No users found.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                      : LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 900;
                          final list = Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Text(
                                    'USER ACCOUNTS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _users.length,
                                    itemBuilder: (context, i) {
                                      final u = _users[i];
                                      final sel = _selectedUser?.id == u.id;
                                      return ListTile(
                                        selected: sel,
                                        selectedTileColor: Colors.grey.shade300,
                                        title: Text(u.fullName),
                                        subtitle: Text(
                                          '${u.role.displayName} · ${u.email}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit',
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 20,
                                              ),
                                              onPressed: () => _editUser(u),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  u.archived
                                                      ? 'Unarchive'
                                                      : 'Archive',
                                              icon: Icon(
                                                u.archived
                                                    ? Icons.restore
                                                    : Icons.archive,
                                                size: 20,
                                              ),
                                              onPressed:
                                                  () => _toggleArchived(
                                                    u,
                                                    !u.archived,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedUser = u;
                                            _initPermissionDraft(u);
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );

                          final detail = _buildUserAccessPanel();

                          if (!wide) {
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: 400, child: list),
                                  const SizedBox(height: 16),
                                  detail,
                                ],
                              ),
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: list),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 6,
                                child: SingleChildScrollView(child: detail),
                              ),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
