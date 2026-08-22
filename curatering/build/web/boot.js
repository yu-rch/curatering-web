(function () {
  var VIEWPORT =
    'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes';
  var SPLASH_TIMEOUT_MS = 14000;

  function applyViewport() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      document.head.appendChild(meta);
    }
    if (meta.getAttribute('content') !== VIEWPORT) {
      meta.setAttribute('content', VIEWPORT);
    }
  }

  function normalizeHost(host) {
    var h = (host || '').toLowerCase().trim();
    while (h.indexOf('www.') === 0) {
      h = h.slice(4);
    }
    return h;
  }

  function isStaffHost(host) {
    var h = normalizeHost(host);
    if (h === 'staff.curatering.com') return true;
    var parts = h.split('.');
    return parts.length > 0 && parts[0] === 'staff';
  }

  function splashLogoSrc() {
    return isStaffHost(location.hostname)
      ? 'splash-staff.png'
      : 'splash-customer.png';
  }

  function ensurePreload(href) {
    var existing = document.querySelector('link[rel="preload"][as="image"][href="' + href + '"]');
    if (existing) return;
    var link = document.createElement('link');
    link.rel = 'preload';
    link.as = 'image';
    link.href = href;
    document.head.appendChild(link);
  }

  function setupSplashLogo() {
    var src = splashLogoSrc();
    ensurePreload(src);
    var img = document.getElementById('app-splash-logo');
    if (!img) return;
    img.src = src;
    img.alt = isStaffHost(location.hostname)
      ? "CURATERING"
      : "Macrina's Kitchen and Catering";
  }

  applyViewport();
  setupSplashLogo();

  // Drop stale service workers that can serve broken cached bundles.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (reg) {
        reg.unregister();
      });
    });
  }

  var splashHidden = false;
  var splashTimer = null;

  function hideSplash() {
    if (splashHidden) return;
    splashHidden = true;
    if (splashTimer) {
      clearTimeout(splashTimer);
      splashTimer = null;
    }
    var el = document.getElementById('app-splash');
    if (!el) return;
    el.classList.add('app-splash-hide');
    el.setAttribute('aria-busy', 'false');
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
      document.documentElement.style.background = '#f5f5f5';
      document.body.style.background = '#f5f5f5';
    }, 280);
  }

  function showLoadError(message) {
    var el = document.getElementById('app-splash');
    if (!el || splashHidden) return;
    splashHidden = true;
    if (splashTimer) {
      clearTimeout(splashTimer);
      splashTimer = null;
    }
    el.classList.add('has-error');
    el.setAttribute('aria-busy', 'false');
    var err = document.getElementById('app-splash-error');
    if (err) {
      err.textContent =
        message ||
        'The app is taking longer than expected. Please refresh the page.';
    }
    // Uncover Flutter if it mounted under the splash.
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
      document.documentElement.style.background = '#f5f5f5';
      document.body.style.background = '#f5f5f5';
    }, 2500);
  }

  window.addEventListener('flutter-first-frame', hideSplash);

  window.addEventListener('error', function (event) {
    var src = event.filename || '';
    if (src.indexOf('main.dart.js') >= 0 || src.indexOf('flutter') >= 0) {
      showLoadError('A script failed to load. Try a hard refresh (Ctrl+F5).');
    }
  });

  splashTimer = setTimeout(function () {
    if (splashHidden) return;
    var flutterView = document.querySelector('flutter-view, flt-glass-pane');
    if (flutterView) {
      hideSplash();
      return;
    }
    showLoadError(
      'The app is taking longer than expected. Check your connection and refresh.',
    );
  }, SPLASH_TIMEOUT_MS);
})();
