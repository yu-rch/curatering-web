import '../services/catering_pricing_store.dart';

export '../services/catering_pricing_store.dart'
    show kDefaultCateringInquiryPricePerGuest;

/// Default / fallback — prefer [cateringPricePerGuest] for live estimates.
const double kCateringInquiryPricePerGuest =
    kDefaultCateringInquiryPricePerGuest;

/// Extra dish beyond a set menu: ₱100 per guest.
const double kExtraSetMenuDishFeePerPax = 100;

/// Live catering price per guest (falls back to [kDefaultCateringInquiryPricePerGuest]).
double cateringPricePerGuest() =>
    CateringPricingStore.instance.pricePerGuest;

/// Alias used by mobile handoff / wizard copy (live).
double pesosPerPax() => cateringPricePerGuest();

/// Deprecated const alias — use [pesosPerPax] / [cateringPricePerGuest].
const double kPesosPerPax = kDefaultCateringInquiryPricePerGuest;

const int kMinCateringOnlyPax = 10;
const int kMinCateringEventPax = 50;

/// Inquiry landing: 49 or below → catering-only; 50+ → catering with event styling.
const int kInquiryLandingEventStylingMinPax = 50;

const String kInquiryTypeCatering = 'CATERING';
const String kInquiryTypeCateringWithEventStyling =
    'CATERING WITH EVENT STYLING';
const String kLegacyInquiryTypeCateringAndEvent = 'CATERING AND EVENT';

/// Extra styling charge per guest when styling is selected below the 50-pax threshold.
double eventStylingSurchargePerPaxBelow50() => cateringPricePerGuest();

/// Deprecated const alias — use [eventStylingSurchargePerPaxBelow50].
const double kEventStylingSurchargePerPaxBelow50 =
    kDefaultCateringInquiryPricePerGuest;

bool isInquiryCateringWithEventStyling(String inquiryType) {
  final u = inquiryType.trim().toUpperCase();
  return u == kInquiryTypeCateringWithEventStyling ||
      u == kLegacyInquiryTypeCateringAndEvent;
}

String inquiryTypeDisplayLabel(String inquiryType) {
  if (isInquiryCateringWithEventStyling(inquiryType)) {
    return 'Catering with Event Styling';
  }
  if (inquiryType.trim().toUpperCase() == kInquiryTypeCatering) {
    return 'Catering';
  }
  return inquiryType;
}

/// `service_included` stores event-styling choice: yes = with styling, no = without.
bool inquiryIncludesEventStyling({
  required String inquiryType,
  String serviceIncluded = '',
}) {
  if (isInquiryCateringWithEventStyling(inquiryType)) return true;
  return serviceIncluded.trim().toLowerCase() == 'yes';
}

String inquiryEventStylingChoiceLabel({
  required String inquiryType,
  String serviceIncluded = '',
}) {
  return inquiryIncludesEventStyling(
        inquiryType: inquiryType,
        serviceIncluded: serviceIncluded,
      )
      ? 'With event styling'
      : 'Without event styling';
}

/// Catering food estimate: price-per-guest × number of guests.
double estimateInquiryCateringTotal(int guestCount) {
  if (guestCount <= 0) return 0;
  return guestCount * cateringPricePerGuest();
}

double estimateInquiryPaxBufferTotal(int paxBuffer) {
  if (paxBuffer <= 0) return 0;
  return paxBuffer * pesosPerPax();
}

/// Styling surcharge when opted-in below [kInquiryLandingEventStylingMinPax].
double estimateInquiryStylingSurcharge({
  required int guestCount,
  required String inquiryType,
  required String serviceIncluded,
}) {
  if (guestCount <= 0) return 0;
  if (guestCount >= kInquiryLandingEventStylingMinPax) return 0;
  if (!inquiryIncludesEventStyling(
    inquiryType: inquiryType,
    serviceIncluded: serviceIncluded,
  )) {
    return 0;
  }
  return guestCount * eventStylingSurchargePerPaxBelow50();
}

/// Package type after landing guest count (or when form guests cross 50).
String inquiryTypeForLandingPax(int pax) {
  if (pax >= kInquiryLandingEventStylingMinPax) {
    return kInquiryTypeCateringWithEventStyling;
  }
  return kInquiryTypeCatering;
}

String serviceIncludedForLandingPax(int pax) {
  return pax >= kInquiryLandingEventStylingMinPax ? 'yes' : 'no';
}

List<Map<String, dynamic>> buildInquiryCostBreakdownLines({
  required int guestCount,
  int paxBuffer = 0,
  double menuModificationsExtra = 0,
  int extraSetMenuDishCount = 0,
  required String inquiryType,
  required String serviceIncluded,
}) {
  final rate = pesosPerPax();
  final lines = <Map<String, dynamic>>[];
  final base = estimateInquiryCateringTotal(guestCount);
  if (guestCount > 0) {
    lines.add({
      'label': 'Base food cost',
      'detail': '₱${rate.toStringAsFixed(0)} × $guestCount guests',
      'amount': base,
    });
  }
  final buffer = estimateInquiryPaxBufferTotal(paxBuffer);
  if (buffer > 0) {
    lines.add({
      'label': 'Pax buffer',
      'detail': '₱${rate.toStringAsFixed(0)} × $paxBuffer',
      'amount': buffer,
    });
  }
  if (menuModificationsExtra > 0) {
    lines.add({
      'label': 'Menu modifications',
      'detail': 'Extra charges from set-menu changes',
      'amount': menuModificationsExtra,
    });
  }
  if (extraSetMenuDishCount > 0 && guestCount > 0) {
    lines.add({
      'label': 'Extra set-menu dish fee',
      'detail':
          '₱${kExtraSetMenuDishFeePerPax.toStringAsFixed(0)} × $guestCount guests × $extraSetMenuDishCount extra dish(es)',
      'amount': extraSetMenuDishCount * guestCount * kExtraSetMenuDishFeePerPax,
    });
  }
  final surcharge = estimateInquiryStylingSurcharge(
    guestCount: guestCount,
    inquiryType: inquiryType,
    serviceIncluded: serviceIncluded,
  );
  if (surcharge > 0) {
    lines.add({
      'label': 'Event styling surcharge',
      'detail':
          '₱${eventStylingSurchargePerPaxBelow50().toStringAsFixed(0)} × $guestCount guests (below $kInquiryLandingEventStylingMinPax)',
      'amount': surcharge,
    });
  }
  return lines;
}

double sumInquiryCostBreakdown(List<Map<String, dynamic>> lines) {
  var total = 0.0;
  for (final line in lines) {
    final amount = line['amount'];
    if (amount is num) total += amount.toDouble();
  }
  return total;
}

String formatInquiryCateringDishPrice() =>
    CateringPricingStore.instance.formatPesoAmount();

String formatInquiryCateringPerPaxLabel() =>
    CateringPricingStore.instance.formatPerPaxLabel();
