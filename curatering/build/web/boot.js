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
  if (window.MutationObserver) {
    new MutationObserver(applyViewport).observe(document.documentElement, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ['content'],
    });
  }

  // Flutter's web engine calls preventDefault on paste. Keep paste enabled
  // for accessibility / password managers on real input fields.
  var preventDefault = Event.prototype.preventDefault;
  Event.prototype.preventDefault = function () {
    var target = this.target;
    var tag = target && target.tagName;
    if (
      this.type === 'paste' &&
      target &&
      (tag === 'INPUT' || tag === 'TEXTAREA' || target.isContentEditable)
    ) {
      return;
    }
    return preventDefault.call(this);
  };

  function hideSplash() {
    var el = document.getElementById('app-splash');
    if (!el) return;
    el.classList.add('app-splash-hide');
    setTimeout(function () {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, 280);
  }

  window.addEventListener('flutter-first-frame', hideSplash);
  setTimeout(hideSplash, 12000);
})();
