String featureApiBase(String configured) {
  return configured.trim().replaceAll(RegExp(r'/+$'), '');
}
