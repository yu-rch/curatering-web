/* Suppress noisy Flutter web console warnings only. Do not shadow Intl APIs. */
(function () {
  var suppressPatterns = [
    /v8BreakIterator/i,
    /Exception while loading service worker/i,
    /Loading the service worker using Flutter bootstrap is deprecated/i,
    /assets\/\.env/i,
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
})();
