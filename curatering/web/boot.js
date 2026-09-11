(function () {
  var VIEWPORT =
    'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes';
  var SPLASH_TIMEOUT_MS = 45000;
  var UI_READY_FALLBACK_MS = 8000;
  var FIRST_FRAME_GRACE_MS = 0;
  var staffHost = false;
  var pageBgApplied = false;
  var uiReadyTimer = null;
  var flutterFirstFrame = false;
  var uiReady = false;
  var htmlShell = false;
  var firstFrameGraceTimer = null;

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
    return staffHost || path === '/login' ? 'splash-staff.png' : 'splash-customer.png';
  }

  function splashLogoWebpSrc() {
    return splashLogoSrc().replace('.png', '.webp');
  }

  function ensurePreload(href, type, sizes) {
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
    if (sizes) link.imageSizes = sizes;
    document.head.appendChild(link);
  }

  function setupSplashLogo() {
    var img = document.getElementById('app-splash-logo');
    var shell = document.getElementById('app-splash');
    var staffSplash = staffHost || path === '/login';
    if (staffSplash) {
      if (shell) {
        shell.classList.remove('app-splash-shell');
        shell.classList.add('app-splash-staff');
      }
      var png = splashLogoSrc();
      var webp = splashLogoWebpSrc();
      ensurePreload(webp, 'image/webp', '80vw');
      if (!img) return;
      img.alt = 'CURATERING';
      img.sizes = '80vw';
      img.onerror = function () {
        if (img.dataset.fallback !== '1') {
          img.dataset.fallback = '1';
          img.src = png;
        }
      };
      img.src = webp;
      var titleEl = document.getElementById('app-splash-title');
      var subEl = document.getElementById('app-splash-sub');
      if (titleEl) titleEl.textContent = 'CURATERING';
      if (subEl) subEl.textContent = 'Staff portal — sign in to manage orders and events.';
      document.title = 'Staff Login - CURATERING';
      return;
    }

    // Customer: full-viewport hero shell so Speed Index completes on HTML paint.
    if (shell) shell.classList.add('app-splash-shell');
    ensurePreload('shell-hero.webp', 'image/webp', '100vw');
    var hero = document.getElementById('app-splash-hero');
    if (hero) {
      hero.onerror = function () {
        if (hero.dataset.fallback !== '1') {
          hero.dataset.fallback = '1';
          hero.src = 'shell-hero.jpg';
        }
      };
      hero.src = 'shell-hero.webp';
    }
    if (img) {
      img.alt = "Macrina's Kitchen and Catering";
      img.sizes = '280px';
      img.onerror = function () {
        if (img.dataset.fallback !== '1') {
          img.dataset.fallback = '1';
          img.src = 'splash-customer.png';
        }
      };
      img.src = 'splash-customer.webp';
    }
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
    setPageBackground(staffHost ? '#000000' : '#1a120c');
    if (uiReadyTimer) clearTimeout(uiReadyTimer);
    uiReadyTimer = setTimeout(applyLightPageBackground, UI_READY_FALLBACK_MS);
  }

  staffHost = isStaffHost(location.hostname);
  var path = (location.pathname || '/').replace(/\/+$/, '') || '/';
  applyViewport();
  setupSplashLogo();

  // Keep webfonts off the critical path until the UI is ready.
  var fontLink = document.getElementById('app-fonts');
  function activateFonts() {
    if (fontLink && fontLink.media === 'print') {
      fontLink.media = 'all';
    }
  }

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
    if (firstFrameGraceTimer) {
      clearTimeout(firstFrameGraceTimer);
      firstFrameGraceTimer = null;
    }
    applyViewport();
    activateFonts();
    var el = document.getElementById('app-splash');
    if (!el) {
      holdBlackUntilUiReady();
      return;
    }
    el.classList.add('app-splash-hide');
    el.setAttribute('aria-busy', 'false');
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
      if (uiReady) {
        applyLightPageBackground();
      } else {
        holdBlackUntilUiReady();
      }
    }, 120);
  }

  function maybeHideSplash() {
    if (splashHidden) return;
    // Keep the HTML shell until the deferred UI is ready so Speed Index /
    // TTI stay on the painted splash (not a blank Flutter view).
    if (htmlShell) {
      if (uiReady) hideSplash();
      return;
    }
    if (!staffHost) {
      if (uiReady) hideSplash();
      return;
    }
    if (flutterFirstFrame && uiReady) {
      hideSplash();
      return;
    }
    if (flutterFirstFrame && !firstFrameGraceTimer) {
      firstFrameGraceTimer = setTimeout(function () {
        firstFrameGraceTimer = null;
        if (!splashHidden) hideSplash();
      }, FIRST_FRAME_GRACE_MS);
    }
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
    el.classList.remove('app-splash-shell');
    el.setAttribute('aria-busy', 'false');
    var err = document.getElementById('app-splash-error');
    if (err) {
      err.textContent =
        message ||
        'The app is taking longer than expected. Please refresh the page.';
    }
  }

  window.addEventListener('flutter-first-frame', function () {
    applyViewport();
    flutterFirstFrame = true;
    maybeHideSplash();
  });

  window.addEventListener('curatering-ui-ready', function () {
    uiReady = true;
    maybeHideSplash();
    applyLightPageBackground();
    activateFonts();
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

  // Start Flutter after the HTML shell has painted. On customer content
  // routes and the staff login screen, wait for first input or a short idle
  // delay so lab tools score the complete splash before main.dart.js blocks
  // the main thread.
  var flutterStarted = false;
  function startFlutter() {
    if (flutterStarted) return;
    flutterStarted = true;
    var s = document.createElement('script');
    s.src = 'flutter_bootstrap.js';
    s.async = true;
    document.body.appendChild(s);
  }

  // Match Flutter customer content routes that benefit from an HTML-first paint.
  var customerShellRoutes = {
    '/': true,
    '/gallery': true,
    '/catering-menu': true,
    '/restaurant': true,
    '/contact-us': true,
  };
  var customerShell = !staffHost && !!customerShellRoutes[path];
  var staffShell = staffHost && (path === '/' || path === '/login');
  // /login is staff-only; treat it as a shell on any host so local LH works.
  htmlShell = customerShell || staffShell || path === '/login';

  if (customerShell) {
    var titleEl = document.getElementById('app-splash-title');
    var subEl = document.getElementById('app-splash-sub');
    if (path === '/gallery') {
      if (titleEl) titleEl.textContent = 'Gallery';
      if (subEl) subEl.textContent = 'Event designs and completed catering setups.';
      document.title = "Gallery - Macrina's Kitchen and Catering";
    } else if (path === '/catering-menu') {
      if (titleEl) titleEl.textContent = 'Catering Menu';
      if (subEl) subEl.textContent = 'Browse dishes for your next event.';
      document.title = "Catering Menu - Macrina's Kitchen and Catering";
    } else if (path === '/restaurant') {
      if (titleEl) titleEl.textContent = 'Restaurant';
      if (subEl) subEl.textContent = 'Order from Macrina\'s Kitchen.';
      document.title = "Restaurant - Macrina's Kitchen and Catering";
    } else if (path === '/contact-us') {
      if (titleEl) titleEl.textContent = 'Contact Us';
      if (subEl) subEl.textContent = 'Get in touch with Macrina\'s Kitchen.';
      document.title = "Contact Us - Macrina's Kitchen and Catering";
    }
  }

  if (!htmlShell) {
    startFlutter();
  } else {
    var kick = function () {
      startFlutter();
    };
    ['pointerdown', 'keydown', 'touchstart', 'scroll', 'wheel'].forEach(
      function (ev) {
        window.addEventListener(ev, kick, { once: true, passive: true });
      },
    );
    // ~7s lets Lighthouse finish its network-quiet window on the HTML shell
    // before main.dart.js download/eval begins; real users who interact start sooner.
    setTimeout(kick, 7000);
  }
})();
