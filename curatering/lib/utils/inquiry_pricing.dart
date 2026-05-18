/// Default per-guest rate for catering inquiry estimates (PHP).
const double kCateringInquiryPricePerGuest = 500;

/// Catering food estimate: ₱500 × number of guests.
double estimateInquiryCateringTotal(int guestCount) {
  if (guestCount <= 0) return 0;
  return guestCount * kCateringInquiryPricePerGuest;
}

String formatInquiryCateringDishPrice() => '₱${kCateringInquiryPricePerGuest.toStringAsFixed(0)}';
