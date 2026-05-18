import 'roles.dart';

/// Fine-grained action keys stored in [UserDto.pagePermissions] alongside route keys.
class ActionPermissionKeys {
  ActionPermissionKeys._();

  static const manageEventsViewDetails = 'action:manage_events:view_details';
  static const manageEventsConfirmDownpayment =
      'action:manage_events:confirm_downpayment';
  static const manageEventsChecklist = 'action:manage_events:checklist';
  static const manageEventsFinalize = 'action:manage_events:finalize';
  static const manageEventsComplete = 'action:manage_events:complete';

  static const menuCreateDish = 'action:menu:create_dish';
  static const menuEditDish = 'action:menu:edit_dish';
  static const menuArchiveDish = 'action:menu:archive_dish';

  static const inventoryEdit = 'action:inventory:edit';
  static const inventoryArchive = 'action:inventory:archive';

  static const loyaltyEditProgram = 'action:loyalty:edit_program';
  static const loyaltyViewCustomers = 'action:loyalty:view_customers';

  static const accountsCreate = 'action:accounts:create';
  static const accountsEdit = 'action:accounts:edit';
  static const accountsArchive = 'action:accounts:archive';
  static const accountsSetPermissions = 'action:accounts:set_permissions';

  static const List<(String label, String key)> togglesForStaff = [
    ('Manage Events — view details', manageEventsViewDetails),
    ('Manage Events — confirm downpayment', manageEventsConfirmDownpayment),
    ('Manage Events — checklist', manageEventsChecklist),
    ('Manage Events — finalize inquiry', manageEventsFinalize),
    ('Manage Events — complete event', manageEventsComplete),
    ('Menu — create dish', menuCreateDish),
    ('Menu — edit dish', menuEditDish),
    ('Menu — archive dish', menuArchiveDish),
    ('Inventory — edit items', inventoryEdit),
    ('Inventory — archive items', inventoryArchive),
    ('Loyalty — edit program rules', loyaltyEditProgram),
    ('Loyalty — view customer points', loyaltyViewCustomers),
  ];

  static const List<(String label, String key)> togglesForSuperAdmin = [
    ('Accounts — create user', accountsCreate),
    ('Accounts — edit user', accountsEdit),
    ('Accounts — archive user', accountsArchive),
    ('Accounts — set permissions', accountsSetPermissions),
  ];
}

bool actionAllowed(
  String actionKey,
  Map<String, dynamic>? pagePermissions, {
  Role? role,
}) {
  if (role == Role.superAdmin) return true;
  if (pagePermissions == null || pagePermissions.isEmpty) return true;
  final v = pagePermissions[actionKey];
  if (v == null) return true;
  if (v is bool) return v;
  return true;
}
