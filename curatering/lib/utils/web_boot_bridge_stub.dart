void signalCurateringUiReadyImpl() {}

void scheduleWhenIdleImpl(
  void Function() callback,
  Duration fallbackDelay,
) {
  Future<void>.delayed(fallbackDelay, callback);
}
