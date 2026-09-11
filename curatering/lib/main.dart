import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Placeholder;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:supabase_flutter/supabase_flutter.dart' deferred as supabase
    show Supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config.dart';
import 'config/site_routes.dart';
import 'customer_page_loader.dart';
import 'staff_app.dart' deferred as staff_app show staffPageFor;
import 'pages/login.dart' deferred as staff_login show Login;
import 'widgets/app_root_route.dart';
import 'widgets/brand_splash_placeholder.dart';
import 'widgets/external_host_redirect.dart';
import 'widgets/legacy_path_redirect.dart';
import 'auth/auth_session.dart';
import 'auth/roles.dart';
import 'auth/staff_permission_refresh.dart';
import 'data_store.dart';
import 'utils/web_boot_bridge.dart';

const _customerExtraPaths = {
  '/gallery',
  '/contact-us',
  '/inquire',
  '/my-inquiries',
  '/my-orders',
  '/my-profile',
  '/my-tracking',
  '/track-order',
  '/restaurant',
  '/restaurant-feedback',
  '/catering-menu',
  '/checkout',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  try {
    // Web uses compile-time --dart-define; skip AssetManifest .env fetch (404).
    if (!kIsWeb) {
      await dotenv.load(fileName: ".env");
    }
  } catch (e) {
    // Ignore .env loading error for deployments without a local file.
  }

  if (!isCustomerSiteHost &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty) {
    await supabase.loadLibrary();
    await supabase.Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else if (kDebugMode && !isCustomerSiteHost) {
    debugPrint(
      'Supabase not initialized — set SUPABASE_URL and SUPABASE_ANON_KEY for storage features.',
    );
  }

  if (redirectApexHostToSubdomain(currentWebPath())) return;

  if (bootstrapWebRouting()) return;

  if (!isCustomerSiteHost) {
    await DataStore.loadTheme();
  }

  if (kIsWeb) {
    BrowserContextMenu.enableContextMenu();
  }

  runApp(const MyApp());
}

Widget _customerPage(Widget child, String path) {
  return HostRouteGuard(routePath: path, child: child);
}

Widget _staffPage(Widget child, String path) {
  return HostRouteGuard(routePath: path, child: child);
}

String _startupRoutePath() => resolveAppInitialRoute();

String _routePathFromSettings(RouteSettings settings) {
  var path = normalizeRoutePath(settings.name ?? rawWebPath());
  final raw = settings.name ?? rawWebPath();
  path = stripLegacyCustomerPrefix(path);
  if (isStaffSiteHost && (path == '/' || isLegacyBookmarkPath(raw))) {
    return '/login';
  }
  return path;
}

Route<dynamic>? _buildRouteForPath(String path) {
  if (needsRedirectToCustomerSite(path)) {
    // CMS draft preview on staff: stay here and edit, don't bounce to live site.
    if (!isCmsDraftPreviewOnStaff) {
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: path),
        builder:
            (_) => ExternalHostRedirect(
              origin: customerSiteOrigin,
              path: customerRoute(path),
            ),
      );
    }
  }
  if (needsRedirectToStaffSite(path)) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: path),
      builder: (_) => ExternalHostRedirect(origin: staffSiteOrigin, path: path),
    );
  }

  if (path == '/') {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const AppRootRoute(),
    );
  }

  if (_customerExtraPaths.contains(path) ||
      (path.startsWith('/p/') && path.length > 3)) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: path),
      builder:
          (_) => _customerPage(
            _CustomerExtraPage(path: path),
            path,
          ),
    );
  }

  if (isStaffRoute(path)) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: path),
      builder:
          (_) => _staffPage(_DeferredStaffPage(path: path), path),
    );
  }

  return null;
}

class _DeferredStaffPage extends StatefulWidget {
  const _DeferredStaffPage({required this.path});

  final String path;

  @override
  State<_DeferredStaffPage> createState() => _DeferredStaffPageState();
}

class _DeferredStaffPageState extends State<_DeferredStaffPage> {
  static Future<void>? _staffAppLoading;
  static Future<void>? _staffLoginLoading;
  bool _ready = false;
  Object? _error;

  bool get _isLogin => widget.path == '/login';

  Future<void> _loadForPath() {
    if (_isLogin) {
      return _staffLoginLoading ??= staff_login.loadLibrary();
    }
    return _staffAppLoading ??= staff_app.loadLibrary();
  }

  @override
  void initState() {
    super.initState();
    _loadForPath()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          signalCurateringUiReady();
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const BrandSplashPlaceholder(
        error: true,
        message: 'Failed to load staff page. Please refresh.',
      );
    }
    if (!_ready) {
      return const BrandSplashPlaceholder();
    }
    if (_isLogin) {
      return staff_login.Login();
    }
    return staff_app.staffPageFor(widget.path);
  }
}

class _CustomerExtraPage extends StatefulWidget {
  const _CustomerExtraPage({required this.path});

  final String path;

  @override
  State<_CustomerExtraPage> createState() => _CustomerExtraPageState();
}

class _CustomerExtraPageState extends State<_CustomerExtraPage> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    ensureCustomerRouteLoaded(widget.path)
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          signalCurateringUiReady();
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const BrandSplashPlaceholder(
        error: true,
        message: 'Failed to load page. Please refresh.',
      );
    }
    if (!_ready) {
      return const BrandSplashPlaceholder();
    }
    return buildCustomerExtraPage(widget.path);
  }
}

const _staffPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _SmoothPageTransitionsBuilder(),
    TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
    TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
    TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
    TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
    TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
  },
);

ThemeData _staffAppTheme({required bool dark}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFFC024),
    brightness: brightness,
  ).copyWith(
    primary: const Color(0xFFFFC024),
    onPrimary: const Color(0xFF1E1E1E),
    secondary: const Color(0xFFFFC024),
    onSecondary: const Color(0xFF1E1E1E),
    surface: dark ? const Color(0xFF141414) : const Color(0xFFF5F7FA),
    onSurface: dark ? const Color(0xFFF5F5F5) : const Color(0xFF262626),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF141414) : const Color(0xFFF5F7FA),
    canvasColor: dark ? const Color(0xFF141414) : const Color(0xFFF5F7FA),
    cardColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
    dividerColor: dark ? const Color(0xFF434343) : const Color(0xFFE8E8E8),
    pageTransitionsTheme: _staffPageTransitions,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC024),
        foregroundColor: const Color(0xFF1E1E1E),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFC024),
        foregroundColor: const Color(0xFF1E1E1E),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFFFC024);
        }
        return dark ? const Color(0xFF5C5C5C) : const Color(0xFFBFBFBF);
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFFFC024);
        }
        return dark ? const Color(0xFFD9D9D9) : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFFFC024).withValues(alpha: 0.45);
        }
        return dark ? const Color(0xFF434343) : const Color(0xFFBFBFBF);
      }),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1F1F1F) : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dark ? const Color(0xFF434343) : const Color(0xFFE8E8E8),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const Duration _staffIdleTimeout = Duration(minutes: 5);

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _staffIdleTimer;
  bool _showingTimeoutDialog = false;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.isLoggedIn.addListener(_handleSessionChanged);
    AuthSession.instance.currentUser.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  @override
  void dispose() {
    AuthSession.instance.isLoggedIn.removeListener(_handleSessionChanged);
    AuthSession.instance.currentUser.removeListener(_handleSessionChanged);
    _staffIdleTimer?.cancel();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (_shouldTrackStaffIdle()) {
      _armStaffIdleTimer();
    } else {
      _staffIdleTimer?.cancel();
      _staffIdleTimer = null;
    }
  }

  /// Inactivity logout applies only to manager / supervisor / super admin —
  /// not cashiers and not customer sessions (customers use a separate token).
  bool _shouldTrackStaffIdle() {
    if (!AuthSession.instance.hasToken) return false;
    final role = AuthSession.instance.currentRole;
    if (role == null || role == Role.cashier) return false;
    return role == Role.manager ||
        role == Role.supervisor ||
        role == Role.superAdmin;
  }

  void _recordStaffActivity() {
    if (_shouldTrackStaffIdle()) {
      _armStaffIdleTimer();
    }
  }

  void _armStaffIdleTimer() {
    if (!_shouldTrackStaffIdle()) {
      _staffIdleTimer?.cancel();
      _staffIdleTimer = null;
      return;
    }
    _staffIdleTimer?.cancel();
    _staffIdleTimer = Timer(_staffIdleTimeout, _expireStaffSessionForIdle);
  }

  Future<void> _expireStaffSessionForIdle() async {
    if (!_shouldTrackStaffIdle()) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    final context = _navigatorKey.currentContext;
    if (context != null && !_showingTimeoutDialog) {
      _showingTimeoutDialog = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Account timed out'),
              content: const Text(
                'Your account has timed out, login to continue access.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      _showingTimeoutDialog = false;
    }
    if (!_shouldTrackStaffIdle()) return;
    AuthSession.instance.clear();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataStore.isDarkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          title: 'Curatering',
          navigatorKey: _navigatorKey,
          navigatorObservers: [StaffPermissionRefreshObserver.instance],
          builder:
              (context, child) => Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _recordStaffActivity(),
                onPointerMove: (_) => _recordStaffActivity(),
                onPointerHover: (_) => _recordStaffActivity(),
                onPointerSignal: (_) => _recordStaffActivity(),
                child: child ?? const SizedBox.shrink(),
              ),
          theme: _staffAppTheme(dark: false),
          darkTheme: _staffAppTheme(dark: true),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          onGenerateInitialRoutes: (_) {
            final path = _startupRoutePath();
            final built = _buildRouteForPath(path);
            return [
              built ??
                  MaterialPageRoute<void>(
                    settings: RouteSettings(name: path),
                    builder: (_) => const AppRootRoute(),
                  ),
            ];
          },
          onGenerateRoute: (settings) {
            final path = _routePathFromSettings(settings);
            final built = _buildRouteForPath(path);
            if (built != null) return built;
            return null;
          },
          onUnknownRoute: (settings) {
            final name = stripLegacyCustomerPrefix(
              settings.name ?? resolveAppInitialRoute(),
            );
            if (isStaffSiteHost) {
              if (isStaffRoute(name)) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder:
                      (_) => _staffPage(
                        const _DeferredStaffPage(path: '/login'),
                        '/login',
                      ),
                );
              }
              if (needsRedirectToCustomerSite(name)) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder:
                      (_) => ExternalHostRedirect(
                        origin: customerSiteOrigin,
                        path: customerRoute(name),
                      ),
                );
              }
            }
            if (needsRedirectToStaffSite(name)) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => ExternalHostRedirect(
                      origin: staffSiteOrigin,
                      path: name,
                    ),
              );
            }
            if (isStaffRoute(name)) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => _staffPage(
                      const _DeferredStaffPage(path: '/login'),
                      '/login',
                    ),
              );
            }
            final rawName = settings.name ?? name;
            if (isLegacyBookmarkPath(rawName)) {
              if (isStaffSiteHost) {
                return MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/login'),
                  builder:
                      (_) => _staffPage(
                        const _DeferredStaffPage(path: '/login'),
                        '/login',
                      ),
                );
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => LegacyPathRedirect(
                      target: stripLegacyCustomerPrefix(rawName),
                    ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const AppRootRoute(),
            );
          },
        );
      },
    );
  }
}

/// Smooths route changes without making staff navigation feel slow.
class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeOutQuart));
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.995, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.012, 0.008),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
