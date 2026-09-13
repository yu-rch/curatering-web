import '../models/event_order.dart';
import '../services/loyalty_rewards_store.dart';
import 'inquiry_pricing.dart';

double _parseDoubleLoose(String raw) {
  final cleaned = raw.replaceAll('₱', '').replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 0.0;
}

double _parsePaxQuantity(String paxOption) {
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

int _paxBufferFromOrder(EventOrderDto order) {
  final raw = order.postAnalysisRaw['pax_buffer'] ?? order.postAnalysisRaw['paxBuffer'];
  if (raw is num) return raw.round();
  return int.tryParse('$raw') ?? 0;
}

double _themeDesignCostFromOrder(EventOrderDto order) {
  final raw = order.postAnalysisRaw['theme_design_cost'] ??
      order.postAnalysisRaw['themeDesignCost'];
  if (raw is num) return raw.toDouble();
  final parsed = double.tryParse('$raw');
  if (parsed != null && parsed > 0) return parsed;
  return 0;
}

double _menuAdditionalChargesFromOrder(EventOrderDto order) {
  final raw = order.postAnalysisRaw['menu_additional_charge_total'] ??
      order.postAnalysisRaw['menuAdditionalChargeTotal'];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw') ?? 0;
}

double _additionalCostsTotal(EventOrderDto order) {
  var total = 0.0;
  final groups = order.postAnalysisRaw['additional_costs_groups'];
  if (groups is List) {
    for (final group in groups) {
      if (group is! Map) continue;
      final items = group['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            total += double.tryParse('${item['amount'] ?? item['cost'] ?? 0}') ?? 0;
          }
        }
      } else {
        total += double.tryParse('${group['total'] ?? 0}') ?? 0;
      }
    }
    return total;
  }
  final flat = order.postAnalysisRaw['additional_costs'];
  if (flat is List) {
    for (final item in flat) {
      if (item is Map) {
        total += double.tryParse('${item['amount'] ?? item['cost'] ?? 0}') ?? 0;
      }
    }
  }
  return total;
}

/// Mobile-aligned total: (pax × ₱500) + pax buffer + theme + labor + travel + additional costs.
double computeOrderTotalCost(EventOrderDto order) {
  if (order.totalCost > 0) return order.totalCost;

  final guests = order.guestCount > 0 ? order.guestCount : 0;
  final paxBuffer = _paxBufferFromOrder(order);
  var total = (guests + paxBuffer) * cateringPricePerGuest();
  total += _menuAdditionalChargesFromOrder(order);
  total += _themeDesignCostFromOrder(order);
  total += order.themeDesign.laborCost ?? 0;
  total += order.themeDesign.travelCost ?? 0;
  total += _additionalCostsTotal(order);

  if (total > 0) return total;

  // Legacy fallback when structured pricing fields are missing.
  var menuSum = 0.0;
  for (final item in order.menu) {
    final price = _parseDoubleLoose(item.price);
    final qty = _parsePaxQuantity(item.paxOption);
    menuSum += price * qty;
  }
  return menuSum;
}

int computeLoyaltyPointsFromCost(
  double totalCost, {
  String orderType = 'restaurant',
}) {
  if (totalCost <= 0) return 0;
  return LoyaltyRewardsStore.instance.getPointsForOrder(
    totalCost,
    orderType: orderType,
  );
}

String formatPesos(double amount) {
  return '₱${amount.toStringAsFixed(2)}';
}

/// Shared peso formatter for UI and report/PDF summaries.
String formatPhp(double amount) {
  return formatPesos(amount);
}
