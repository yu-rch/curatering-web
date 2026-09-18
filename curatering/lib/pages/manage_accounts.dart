import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/action_permissions.dart';
import '../auth/page_permissions.dart';
import '../auth/roles.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/super_admin_api.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_dialog.dart';
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
  SuperAdminSecurityDto? _security;

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

  bool _isLastActiveSuperAdmin(UserDto user) {
    if (user.role != Role.superAdmin || user.archived) return false;
    return (_security?.activeCount ?? 0) == 1;
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
      SuperAdminSecurityDto? security = _security;
      try {
        security = await SuperAdminApi.instance.getSuperAdminSecurity();
      } catch (_) {
        // Keep last known snapshot; the users list is still usable.
      }
      // Client-side status guard in case API omits archived filtering.
      final filtered =
          _archivedFilter == null
              ? users
              : users.where((u) => u.archived == _archivedFilter).toList();
      setState(() {
        _users = filtered;
        _security = security;
        if (_selectedUser != null) {
          final id = _selectedUser!.id;
          final still = filtered.where((u) => u.id == id).toList();
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
    for (final entry in ActionPermissionKeys.togglesForStaff) {
      final key = entry.$2;
      if (existing != null && existing.containsKey(key)) {
        m[key] = existing[key] == true;
      } else {
        m[key] = true;
      }
    }
    if (AuthSession.instance.currentRole == Role.superAdmin) {
      for (final entry in ActionPermissionKeys.togglesForSuperAdmin) {
        final key = entry.$2;
        if (existing != null && existing.containsKey(key)) {
          m[key] = existing[key] == true;
        } else {
          m[key] = true;
        }
      }
    }
    _pagePermissionDraft = m;
  }

  Widget _permissionToggleRow(String label, String key, bool allowed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            allowed ? 'Allowed' : 'Blocked',
            style: TextStyle(
              color: allowed ? Colors.green.shade800 : Colors.red.shade700,
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
                        _pagePermissionDraft[key] = !allowed;
                      });
                      _persistPagePermissions();
                    },
            child: Text(allowed ? 'Don\'t allow' : 'Allow'),
          ),
        ],
      ),
    );
  }

  Future<String?> _confirmSuperAdminPassword(String actionLabel) async {
    final passwordCtrl = TextEditingController();
    String? errorText;
    final result = await showAntdModal<String>(
      context: context,
      title: 'Confirm password',
      barrierDismissible: false,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your current super admin password to $actionLabel.'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Super admin password',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                onChanged: (_) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
                onSubmitted: (_) {
                  final value = passwordCtrl.text;
                  if (value.isEmpty) {
                    setDialogState(() => errorText = 'Password is required.');
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AntdSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  AntdPrimaryButton(
                    label: 'Confirm',
                    icon: Icons.verified_user_outlined,
                    onPressed: () {
                      final value = passwordCtrl.text;
                      if (value.isEmpty) {
                        setDialogState(
                          () => errorText = 'Password is required.',
                        );
                        return;
                      }
                      Navigator.of(context).pop(value);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    passwordCtrl.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _createUser({Role? presetRole}) async {
    final fullNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final birthdayCtrl = TextEditingController();
    final contactNumberCtrl = TextEditingController();
    Role role = presetRole ?? Role.supervisor;
    final lockRole = presetRole == Role.superAdmin;
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
                    Text(
                      lockRole ? 'ADD SUPER ADMIN' : 'CREATE ACCOUNT',
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
                                    .where((r) => r != Role.manager)
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.displayName),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                lockRole
                                    ? null
                                    : (v) =>
                                        setStateDialog(() => role = v ?? role),
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
                          final superAdminPassword =
                              await _confirmSuperAdminPassword(
                                'create this account',
                              );
                          if (superAdminPassword == null) return;
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
                            superAdminPassword: superAdminPassword,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          final msg =
                              e is ApiError
                                  ? e.message
                                  : 'Failed to create account.';
                          setStateDialog(() => errorMessage = msg);
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

  Future<void> _editRoleLimits() async {
    Map<String, dynamic> existing;
    try {
      existing = await SuperAdminApi.instance.getRoleLimits();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load role limits.')),
        );
      }
      return;
    }

    String capText(String role) {
      final v = existing[role];
      if (v == null) return '';
      return v.toString();
    }

    final adminCtrl = TextEditingController(text: capText('admin'));
    final managerCtrl = TextEditingController(text: capText('manager'));
    final supervisorCtrl = TextEditingController(text: capText('supervisor'));
    final cashierCtrl = TextEditingController(text: capText('cashier'));
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('Role account limits'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum active (non-archived) accounts per role. Leave blank for unlimited. Super admin is never capped.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _limitField('Admin', adminCtrl),
                      _limitField('Manager', managerCtrl),
                      _limitField('Supervisor', supervisorCtrl),
                      _limitField('Cashier', cashierCtrl),
                      if (err != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          err!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    int? parse(String raw) {
                      final t = raw.trim();
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      if (n == null || n < 1) return -1;
                      return n;
                    }

                    final limits = <String, dynamic>{
                      'admin': parse(adminCtrl.text),
                      'manager': parse(managerCtrl.text),
                      'supervisor': parse(supervisorCtrl.text),
                      'cashier': parse(cashierCtrl.text),
                    };
                    if (limits.values.any((v) => v == -1)) {
                      setDialog(
                        () =>
                            err =
                                'Enter positive whole numbers or leave blank.',
                      );
                      return;
                    }
                    for (final e in limits.entries) {
                      if (e.value == null) {
                        limits[e.key] = null;
                      }
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      int? parse(String raw) {
        final t = raw.trim();
        if (t.isEmpty) return null;
        return int.tryParse(t);
      }

      final limits = <String, dynamic>{
        'admin': parse(adminCtrl.text),
        'manager': parse(managerCtrl.text),
        'supervisor': parse(supervisorCtrl.text),
        'cashier': parse(cashierCtrl.text),
      };
      try {
        await SuperAdminApi.instance.putRoleLimits(limits);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Role limits saved.')));
        }
      } catch (e) {
        final msg = e is ApiError ? e.message : 'Failed to save limits.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }

    adminCtrl.dispose();
    managerCtrl.dispose();
    supervisorCtrl.dispose();
    cashierCtrl.dispose();
  }

  Widget _limitField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: 'Unlimited if empty',
        ),
      ),
    );
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
    final lastSa = _isLastActiveSuperAdmin(user);

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
                                    .where((r) => r != Role.manager)
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.displayName),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                lastSa
                                    ? null
                                    : (v) =>
                                        setStateDialog(() => role = v ?? role),
                          ),
                          if (lastSa) ...[
                            const SizedBox(height: 8),
                            Text(
                              'This account is the last active Super Admin. At least one active Super Admin must remain.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
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
                          final superAdminPassword =
                              await _confirmSuperAdminPassword(
                                'modify this account',
                              );
                          if (superAdminPassword == null) return;
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
                            superAdminPassword: superAdminPassword,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          final msg =
                              e is ApiError
                                  ? e.message
                                  : 'Failed to update account.';
                          setStateDialog(() => errorMessage = msg);
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

  Future<void> _transferPrimary() async {
    List<UserDto> candidates;
    try {
      candidates = await SuperAdminApi.instance.listUsers(archived: false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load accounts for transfer.')),
      );
      return;
    }
    final primaryId = _security?.primarySuperAdminId;
    final options =
        candidates.where((u) => !u.archived && u.id != primaryId).toList();
    if (options.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create another staff account before transferring.'),
        ),
      );
      return;
    }

    String selectedId = options.first.id;
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
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: Colors.black),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const Text(
                      'TRANSFER PRIMARY SUPER ADMIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The current Super Admin keeps access. The selected account becomes primary and is promoted if needed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null) ...[
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text('NEW PRIMARY', style: TextStyle(fontSize: 11)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedId,
                      items:
                          options
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(
                                    '${u.fullName} · ${u.role.displayName}',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => selectedId = v);
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final password =
                              await _confirmSuperAdminPassword(
                            'transfer primary Super Admin',
                          );
                          if (password == null) return;
                          await SuperAdminApi.instance.transferPrimarySuperAdmin(
                            targetUserId: selectedId,
                            superAdminPassword: password,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setStateDialog(() {
                            errorMessage =
                                e is ApiError
                                    ? e.message
                                    : 'Failed to transfer primary Super Admin.';
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        'TRANSFER',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
    if (nextValue && _isLastActiveSuperAdmin(user)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot archive the last active Super Admin.'),
        ),
      );
      return;
    }
    try {
      final password = await _confirmSuperAdminPassword(
        nextValue ? 'archive this account' : 'unarchive this account',
      );
      if (password == null) return;
      await SuperAdminApi.instance.setUserArchived(
        userId: user.id,
        archived: nextValue,
        superAdminPassword: password,
      );
      if (!mounted) return;
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiError ? e.message : 'Failed to update archive status.',
          ),
        ),
      );
    }
  }

  Future<void> _persistPagePermissions() async {
    final u = _selectedUser;
    if (u == null || u.role == Role.superAdmin) return;
    setState(() => _savingPermissions = true);
    try {
      final saved = Map<String, dynamic>.from(_pagePermissionDraft);
      await SuperAdminApi.instance.updateUserPagePermissions(
        userId: u.id,
        pagePermissions: saved,
      );
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((x) => x.id == u.id);
        if (idx >= 0) {
          final prev = _users[idx];
          _users[idx] = UserDto(
            id: prev.id,
            email: prev.email,
            fullName: prev.fullName,
            role: prev.role,
            archived: prev.archived,
            isVerified: prev.isVerified,
            pagePermissions: saved,
            birthday: prev.birthday,
            contactNumber: prev.contactNumber,
            employmentType: prev.employmentType,
          );
        }
        _selectedUser = _users.firstWhere((x) => x.id == u.id, orElse: () => u);
        _pagePermissionDraft = Map<String, dynamic>.from(saved);
      });
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
              'Turn pages on or off for this user. Changes apply here immediately. '
              'The affected account will see updated access on their next page navigation, or after they sign out and back in.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...PagePermissionRoutes.togglesForStaff.map((e) {
              final label = e.$1;
              final route = e.$2;
              final allowed = (_pagePermissionDraft[route] as bool?) ?? true;
              return _permissionToggleRow(label, route, allowed);
            }),
            const SizedBox(height: 16),
            const Text(
              'ACTION ACCESS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Control which buttons and actions this user can use on each page.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...ActionPermissionKeys.togglesForStaff.map((e) {
              final label = e.$1;
              final key = e.$2;
              final allowed = (_pagePermissionDraft[key] as bool?) ?? true;
              return _permissionToggleRow(label, key, allowed);
            }),
            if (isCurrentUserSuperAdmin) ...[
              const SizedBox(height: 12),
              const Text(
                'SUPER ADMIN ACTIONS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...ActionPermissionKeys.togglesForSuperAdmin.map((e) {
                final label = e.$1;
                final key = e.$2;
                final allowed = (_pagePermissionDraft[key] as bool?) ?? true;
                return _permissionToggleRow(label, key, allowed);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuperAdminSecurityPanel() {
    final security = _security;
    final members = security?.superAdmins ?? const <SuperAdminMemberDto>[];
    final count = security?.activeCount ?? members.length;
    final primaryId = security?.primarySuperAdminId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Super Admin Security',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Active Super Admins: $count',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            if (members.isEmpty)
              Text(
                'No active Super Admins were returned.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          m.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (primaryId != null &&
                                          primaryId == m.id) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFE0B2),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Text(
                                            'Primary',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    m.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    m.archived ? 'Archived' : 'Active',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _loading
                          ? null
                          : () => _createUser(presetRole: Role.superAdmin),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Super Admin'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _transferPrimary,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer Primary Super Admin'),
                ),
              ],
            ),
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
            _buildSuperAdminSecurityPanel(),
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
                        .where((r) => r != Role.manager)
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
                OutlinedButton.icon(
                  onPressed: _loading ? null : _editRoleLimits,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Role limits'),
                ),
                const SizedBox(width: 8),
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
                                      final lastSa = _isLastActiveSuperAdmin(u);
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
                                                  lastSa
                                                      ? 'Cannot archive the last active Super Admin.'
                                                      : u.archived
                                                      ? 'Unarchive'
                                                      : 'Archive',
                                              icon: Icon(
                                                u.archived
                                                    ? Icons.restore
                                                    : Icons.archive,
                                                size: 20,
                                              ),
                                              onPressed:
                                                  lastSa
                                                      ? null
                                                      : () => _toggleArchived(
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
