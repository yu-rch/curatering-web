import 'package:flutter/material.dart';

import '../config/site_routes.dart';
import '../customer_home.dart' deferred as customer_home
    show CustomerWebsiteScreen;
import '../utils/browser_tab_title.dart';
import '../utils/web_boot_bridge.dart';
import 'brand_splash_placeholder.dart';

/// Host-aware `/` entry.
class AppRootRoute extends StatefulWidget {
  const AppRootRoute({super.key});

  @override
  State<AppRootRoute> createState() => _AppRootRouteState();
}

class _AppRootRouteState extends State<AppRootRoute> {
  static Future<void>? _homeLoading;
  bool _homeReady = false;
  Object? _homeError;

  @override
  void initState() {
    super.initState();
    if (isStaffSiteHost) {
      setBrowserTabTitle('Login', staff: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }
    setBrowserTabTitle('Home', staff: false);
    _homeLoading ??= customer_home.loadLibrary();
    _homeLoading!
        .then((_) {
          if (!mounted) return;
          setState(() => _homeReady = true);
          signalCurateringUiReady();
        })
        .catchError((Object e) {
          if (mounted) setState(() => _homeError = e);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (isStaffSiteHost) {
      return const BrandSplashPlaceholder();
    }
    if (_homeError != null) {
      return const BrandSplashPlaceholder(
        error: true,
        message: 'Failed to load home. Please refresh.',
      );
    }
    if (!_homeReady) {
      return const BrandSplashPlaceholder();
    }
    return customer_home.CustomerWebsiteScreen(
      contentEditable: false,
      showStaffChrome: false,
    );
  }
}
