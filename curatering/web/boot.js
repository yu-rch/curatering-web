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
})();
