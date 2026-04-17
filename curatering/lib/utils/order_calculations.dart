import '../models/event_order.dart';

double _parseDoubleLoose(String raw) {
  // Removes any non-numeric separators except '.' and '-' so we can parse
  // strings like "₱100.00" or "100.00".
  final cleaned = raw
      .replaceAll('₱', '')
      .replaceAll(',', '')
      .trim();
  return double.tryParse(cleaned) ?? 0.0;
}

double _parsePaxQuantity(String paxOption) {
  // Examples:
  // - "1 pax" -> 1
  // - "10 pax" -> 10
  // - "10-15 pax" -> (10+15)/2
  final raw = paxOption.toLowerCase().replaceAll('pax', '').trim();
  if (raw.contains('-')) {
    final parts = raw.split('-').map((e) => e.trim()).toList();
    if (parts.length == 2) {
      final a = double.tryParse(parts[0]) ?? 0.0;
      final b = double.tryParse(parts[1]) ?? 0.0;
      if (a == 0.0 && b == 0.0) return 0.0;
      return (a + b) / 2.0;
    }
  }

  return double.tryParse(raw.split(' ').first.trim()) ?? 0.0;
}

double computeOrderTotalCost(EventOrderDto order) {
  var total = 0.0;
  for (final item in order.menu) {
    final price = _parseDoubleLoose(item.price);
    final qty = _parsePaxQuantity(item.paxOption);
    total += price * qty;
  }
  return total;
}

int computeLoyaltyPointsFromCost(double totalCost) {
  // Dev/test heuristic until backend stores points explicitly.
  if (totalCost <= 0) return 0;
  return (totalCost / 205.0).round();
}

String formatPesos(double amount) {
  return '₱${amount.toStringAsFixed(2)}';
}

