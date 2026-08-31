(function () {
  var suppressPatterns = [
    /v8BreakIterator/i,
    /deprecated/i,
    /service worker/i,
    /Exception while loading service worker/i,
  ];

  function shouldSuppress(args) {
    try {
      var msg = Array.prototype.join.call(args, ' ');
      for (var i = 0; i < suppressPatterns.length; i++) {
        if (suppressPatterns[i].test(msg)) return true;
      }
    } catch (_) {}
    return false;
  }

  ['warn', 'error', 'info', 'debug'].forEach(function (level) {
    var original = console[level];
    if (typeof original !== 'function') return;
    console[level] = function () {
      if (shouldSuppress(arguments)) return;
      return original.apply(console, arguments);
    };
  });

  // Prevent deprecated Intl.v8BreakIterator from being touched at runtime.
  if (typeof Intl !== 'undefined' && typeof Intl.Segmenter === 'function') {
    try {
      Object.defineProperty(Intl, 'v8BreakIterator', {
        configurable: true,
        get: function () {
          return undefined;
        },
      });
    } catch (_) {}
  }
})();
