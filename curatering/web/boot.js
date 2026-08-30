(function () {
  var VIEWPORT =
    'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes';
  var SPLASH_TIMEOUT_MS = 14000;
  var UI_READY_FALLBACK_MS = 8000;
  var staffHost = false;
  var pageBgApplied = false;
  var uiReadyTimer = null;

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
    return staffHost ? 'splash-staff.png' : 'splash-customer.png';
  }

  function splashLogoWebpSrc() {
    return splashLogoSrc().replace('.png', '.webp');
  }

  function ensurePreload(href, type) {
    var existing = document.querySelector(
      'link[rel="preload"][as="image"][href="' + href + '"]',
    );
    if (existing) return;
    var link = document.createElement('link');
    link.rel = 'preload';
    link.as = 'image';
    link.href = href;
    link.fetchPriority = 'high';
    if (type) link.type = type;
    document.head.appendChild(link);
  }

  function setupSplashLogo() {
    var png = splashLogoSrc();
    var webp = splashLogoWebpSrc();
    ensurePreload(webp, 'image/webp');
    ensurePreload(png);
    var img = document.getElementById('app-splash-logo');
    if (!img) return;
    img.alt = staffHost
      ? 'CURATERING'
      : "Macrina's Kitchen and Catering";
    img.onerror = function () {
      if (img.dataset.fallback !== '1') {
        img.dataset.fallback = '1';
        img.src = png;
      }
    };
    img.src = webp;
  }

  function setPageBackground(color) {
    document.documentElement.style.background = color;
    document.body.style.background = color;
  }

  function applyLightPageBackground() {
    if (pageBgApplied) return;
    pageBgApplied = true;
    if (uiReadyTimer) {
      clearTimeout(uiReadyTimer);
      uiReadyTimer = null;
    }
    setPageBackground('#f5f5f5');
  }

  function holdBlackUntilUiReady() {
    setPageBackground('#000000');
    if (uiReadyTimer) clearTimeout(uiReadyTimer);
    uiReadyTimer = setTimeout(applyLightPageBackground, UI_READY_FALLBACK_MS);
  }

  staffHost = isStaffHost(location.hostname);
  applyViewport();
  setupSplashLogo();

  // Flutter often rewrites viewport to user-scalable=no — keep locking it.
  if (typeof MutationObserver !== 'undefined') {
    var headObserver = new MutationObserver(function () {
      applyViewport();
    });
    headObserver.observe(document.head, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['content'],
    });
  }
  setInterval(applyViewport, 1500);

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
    applyViewport();
    var el = document.getElementById('app-splash');
    if (!el) {
      holdBlackUntilUiReady();
      return;
    }
    el.classList.add('app-splash-hide');
    el.setAttribute('aria-busy', 'false');
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
      // Stay black until deferred UI (staff login / customer home) signals ready.
      holdBlackUntilUiReady();
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
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
      applyLightPageBackground();
    }, 2500);
  }

  window.addEventListener('flutter-first-frame', function () {
    applyViewport();
    hideSplash();
  });

  window.addEventListener('curatering-ui-ready', function () {
    applyLightPageBackground();
  });

  window.addEventListener('error', function (event) {
    var src = event.filename || '';
    if (src.indexOf('main.dart.js') >= 0 || src.indexOf('flutter') >= 0) {
      event.preventDefault();
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
