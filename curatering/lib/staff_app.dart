import 'package:flutter/material.dart';

import 'auth/page_permissions.dart';
import 'auth/role_guard.dart';
import 'auth/roles.dart';
import 'pages/action_logs.dart';
import 'pages/archive.dart';
import 'pages/catering.dart';
import 'pages/customer_feedback_page.dart';
import 'pages/customer_management.dart';
import 'customer_page_loader.dart';
import 'pages/dashboard.dart';
import 'pages/help_requests.dart';
import 'pages/inventory.dart';
import 'pages/login.dart';
import 'pages/manage_accounts.dart';
import 'pages/manage_loyalty_rewards.dart';
import 'pages/menu.dart';
import 'pages/reports.dart';
import 'pages/restaurant_orders_route.dart';
import 'pages/settings.dart';
import 'pages/super_admin_dashboard.dart';
import 'pages/transactions.dart';
import 'pages/website_admin_page.dart';
import 'auth/auth_session.dart';
import 'widgets/page_permission_guard.dart';

class _RoleAwareDashboard extends StatelessWidget {
  const _RoleAwareDashboard();

  @override
  Widget build(BuildContext context) {
    if (AuthSession.instance.currentRole == Role.superAdmin) {
      return const SuperAdminDashboardPage();
    }
    return const Dashboard();
  }
}

/// Staff / back-office pages. Loaded as a deferred JS chunk so the customer
/// storefront does not parse this code on first paint.
Widget staffPageFor(String path) {
  switch (path) {
    case '/login':
      return const Login();
    case '/dashboard':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.superAdmin},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.dashboard,
          child: const _RoleAwareDashboard(),
        ),
      );
    case '/super-admin-dashboard':
      return const RoleGuard(
        requiredRole: Role.superAdmin,
        child: _RoleAwareDashboard(),
      );
    case '/manager-dashboard':
      return const RoleGuard(
        requiredRole: Role.superAdmin,
        child: Dashboard(),
      );
    case '/manage-accounts':
      return const RoleGuard(
        requiredRole: Role.superAdmin,
        child: ManageAccounts(),
      );
    case '/help-requests':
      return RoleGuard(
        requiredRole: Role.superAdmin,
        allowedRoles: {Role.manager, Role.supervisor},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.helpRequests,
          child: const HelpRequestsPage(),
        ),
      );
    case '/customer-feedback':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.superAdmin},
        child: CustomerFeedbackPage(),
      );
    case '/action-logs':
      return const RoleGuard(
        requiredRole: Role.superAdmin,
        child: ActionLogsPage(),
      );
    case '/customer-management':
      return const RoleGuard(
        requiredRole: Role.superAdmin,
        child: CustomerManagementPage(),
      );
    case '/manage-events':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.supervisor},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.manageEvents,
          child: const ManageEvents(),
        ),
      );
    case '/loyalty':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.supervisor},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.loyalty,
          child: const ManageLoyaltyRewards(),
        ),
      );
    case '/catering-restaurant-menu':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.menu,
          child: const Menu(),
        ),
      );
    case '/inventory':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.supervisor},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.inventory,
          child: const Inventory(),
        ),
      );
    case '/restaurant-orders':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.supervisor, Role.cashier},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.restaurantOrders,
          child: const RestaurantOrdersRoute(),
        ),
      );
    case '/reports':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.reports,
          child: const Reports(),
        ),
      );
    case '/order-history':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.supervisor},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.orderHistory,
          child: const Transactions(),
        ),
      );
    case '/archive':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.superAdmin},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.archive,
          child: Archive(),
        ),
      );
    case '/website':
      return RoleGuard(
        requiredRole: Role.superAdmin,
        child: buildCustomerWebsiteScreen(
          contentEditable: true,
          showStaffChrome: true,
          returnRoute: '/website-admin',
        ),
      );
    case '/website-admin':
      return const RoleGuard(
        requiredRole: Role.superAdmin,
        child: WebsiteAdminPage(),
      );
    case '/settings':
      return RoleGuard(
        requiredRole: Role.manager,
        allowedRoles: {Role.manager, Role.supervisor, Role.cashier},
        child: PagePermissionGuard(
          route: PagePermissionRoutes.settings,
          child: const Settings(),
        ),
      );
    default:
      return const Login();
  }
}
