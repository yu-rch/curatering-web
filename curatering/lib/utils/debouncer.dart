import 'dart:async';
import 'dart:ui';

/// Utility class for debouncing function calls.
/// Prevents rapid-fire API calls or expensive operations.
class Debouncer {
  final Duration delay;
  Timer? _timer;
  VoidCallback? _pendingCallback;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Debounce a callback - only executes after delay expires without new calls
  void debounce(VoidCallback callback) {
    _pendingCallback = callback;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _pendingCallback?.call();
      _pendingCallback = null;
    });
  }

  /// Cancel any pending debounced call
  void cancel() {
    _timer?.cancel();
    _pendingCallback = null;
  }

  /// Flush pending call immediately
  void flush() {
    if (_pendingCallback != null) {
      _timer?.cancel();
      _pendingCallback?.call();
      _pendingCallback = null;
    }
  }

  void dispose() {
    cancel();
  }
}

/// Throttler - ensures function is only called once per duration period
class Throttler {
  final Duration duration;
  DateTime? _lastExecution;

  Throttler({this.duration = const Duration(milliseconds: 500)});

  /// Execute callback if enough time has passed since last execution
  void throttle(VoidCallback callback) {
    final now = DateTime.now();
    if (_lastExecution == null || now.difference(_lastExecution!) >= duration) {
      _lastExecution = now;
      callback();
    }
  }

  void reset() {
    _lastExecution = null;
  }
}
