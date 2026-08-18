(function () {
  var VIEWPORT =
    'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes';

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

  applyViewport();

  // Drop stale service workers that can serve broken cached bundles.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (reg) {
        reg.unregister();
      });
    });
  }

  function hideSplash() {
    var el = document.getElementById('app-splash');
    if (!el || el.dataset.hidden === '1') return;
    el.dataset.hidden = '1';
    el.classList.add('app-splash-hide');
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, 280);
  }

  function showLoadError(message) {
    var el = document.getElementById('app-splash');
    if (!el) return;
    var title = el.querySelector('h1');
    var subtitle = el.querySelector('p');
    if (title) title.textContent = 'Unable to load the app';
    if (subtitle) {
      subtitle.textContent =
        message ||
        'Please refresh the page. If this continues, clear your browser cache.';
    }
    el.classList.remove('app-splash-hide');
    el.style.opacity = '1';
    el.style.pointerEvents = 'auto';
  }

  window.addEventListener('flutter-first-frame', hideSplash);

  window.addEventListener('error', function (event) {
    var src = event.filename || '';
    if (src.indexOf('main.dart.js') >= 0 || src.indexOf('flutter') >= 0) {
      showLoadError('A script failed to load. Try a hard refresh (Ctrl+F5).');
    }
  });

  // Do not hide the splash on a timer — that caused a blank black screen when
  // Flutter was still downloading or blocked by CSP.
  setTimeout(function () {
    if (document.getElementById('app-splash')?.dataset.hidden === '1') return;
    var flutterView = document.querySelector('flutter-view, flt-glass-pane');
    if (flutterView) return;
    showLoadError(
      'The app is taking longer than expected. Check your connection and refresh.',
    );
  }, 45000);
})();
