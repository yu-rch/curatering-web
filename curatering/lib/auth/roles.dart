enum Role {
  admin,
  manager,
  supervisor,
  superAdmin,
}

extension RoleX on Role {
  String get displayName {
    return switch (this) {
      Role.admin => 'Admin',
      Role.manager => 'Manager',
      Role.supervisor => 'Supervisor',
      Role.superAdmin => 'Super Admin',
    };
  }
}

Role roleFromString(String raw) {
  final normalized = raw.trim().toLowerCase();
  return switch (normalized) {
    'admin' => Role.admin,
    'manager' => Role.manager,
    'supervisor' => Role.supervisor,
    'super_admin' || 'superadmin' || 'super-admin' => Role.superAdmin,
    _ => Role.supervisor,
  };
}

String roleToString(Role role) {
  return switch (role) {
    Role.admin => 'admin',
    Role.manager => 'manager',
    Role.supervisor => 'supervisor',
    Role.superAdmin => 'super_admin',
  };
}

