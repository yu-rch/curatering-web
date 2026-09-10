/* Early boot helpers for Flutter web.
   - Suppress noisy console messages
   - Polyfill Intl.v8BreakIterator on top of Intl.Segmenter so Flutter text
     layout keeps working without calling the deprecated native API
*/
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

  if (typeof Intl === 'undefined' || typeof Intl.Segmenter !== 'function') {
    return;
  }

  function granularityForType(type) {
    var t = String(type || 'grapheme').toLowerCase();
    if (t === 'word') return 'word';
    if (t === 'sentence') return 'sentence';
    // "line" / "character" / unknown → grapheme boundaries (safe for layout)
    return 'grapheme';
  }

  function V8BreakIteratorPolyfill(locales, options) {
    this._granularity = granularityForType(options && options.type);
    this._text = '';
    this._breaks = [0];
    this._index = 0;
    this._current = 0;
  }

  V8BreakIteratorPolyfill.prototype.adoptText = function (text) {
    this._text = text == null ? '' : String(text);
    var breaks = [0];
    try {
      var segmenter = new Intl.Segmenter(undefined, {
        granularity: this._granularity,
      });
      var iter = segmenter.segment(this._text);
      // for..of over segments
      if (typeof iter[Symbol.iterator] === 'function') {
        var it = iter[Symbol.iterator]();
        var step;
        while (!(step = it.next()).done) {
          var part = step.value;
          if (!part) continue;
          var end = (part.index || 0) + String(part.segment || '').length;
          if (end > breaks[breaks.length - 1]) breaks.push(end);
        }
      }
    } catch (_) {
      // Fallback: break on whitespace / string end.
      breaks = [0];
      for (var i = 0; i < this._text.length; i++) {
        var ch = this._text.charCodeAt(i);
        if (ch === 32 || ch === 9 || ch === 10 || ch === 13) {
          if (i + 1 > breaks[breaks.length - 1]) breaks.push(i + 1);
        }
      }
    }
    if (breaks[breaks.length - 1] !== this._text.length) {
      breaks.push(this._text.length);
    }
    this._breaks = breaks;
    this._index = 0;
    this._current = 0;
  };

  V8BreakIteratorPolyfill.prototype.first = function () {
    this._index = 0;
    this._current = this._breaks.length ? this._breaks[0] : 0;
    return this._current;
  };

  V8BreakIteratorPolyfill.prototype.next = function () {
    if (this._index >= this._breaks.length - 1) {
      this._current = -1;
      return -1;
    }
    this._index += 1;
    this._current = this._breaks[this._index];
    return this._current;
  };

  V8BreakIteratorPolyfill.prototype.current = function () {
    return this._current;
  };

  V8BreakIteratorPolyfill.prototype.breakType = function () {
    return 'letter';
  };

  try {
    Object.defineProperty(Intl, 'v8BreakIterator', {
      configurable: true,
      enumerable: false,
      writable: true,
      value: V8BreakIteratorPolyfill,
    });
  } catch (_) {
    try {
      Intl.v8BreakIterator = V8BreakIteratorPolyfill;
    } catch (__) {}
  }
})();
