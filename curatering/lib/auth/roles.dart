enum Role {
  manager,
  supervisor,
  superAdmin,
  cashier,
}

extension RoleX on Role {
  String get displayName {
    return switch (this) {
      Role.manager => 'Manager',
      Role.supervisor => 'Supervisor',
      Role.superAdmin => 'Super Admin',
      Role.cashier => 'Cashier',
    };
  }
}

Role roleFromString(String raw) {
  final normalized = raw.trim().toLowerCase();
  return switch (normalized) {
    'manager' => Role.manager,
    'supervisor' => Role.supervisor,
    'super_admin' || 'superadmin' || 'super-admin' => Role.superAdmin,
    'cashier' => Role.cashier,
    _ => Role.supervisor,
  };
}

String roleToString(Role role) {
  return switch (role) {
    Role.manager => 'manager',
    Role.supervisor => 'supervisor',
    Role.superAdmin => 'super_admin',
    Role.cashier => 'cashier',
  };
}

