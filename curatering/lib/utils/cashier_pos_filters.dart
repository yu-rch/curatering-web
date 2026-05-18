/// Client-side filters for cashier POS online order queues (mobile parity).
class PosOrderView {
  final Map<String, dynamic> raw;

  PosOrderView(this.raw);

  String get status => (raw['status'] ?? '').toString().trim();
  String get fulfillmentStage =>
      (raw['fulfillment_stage'] ?? '').toString().trim();
  String get orderSource => (raw['order_source'] ?? '').toString().trim();
  bool get balanceProofPending =>
      raw['balance_proof_pending_review'] == true;
  String? get supplementalProof =>
      raw['supplemental_payment_proof']?.toString();

  String get orderNo =>
      (raw['order_no'] ?? raw['order_id'] ?? raw['id'] ?? '').toString();
  double get total {
    final v = raw['total'] ?? raw['total_cost'] ?? raw['total_amount'];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}

String statusReadable(PosOrderView o) => o.status;

bool matchesPendingFilter(PosOrderView o, String mode) {
  final u = statusReadable(o).toUpperCase();
  switch (mode) {
    case 'wait_payment':
      return u.contains('WAITING FOR PAYMENT CONFIRMATION') ||
          u.contains('WAITING FOR ORDER CONFIRMATION') ||
          u.contains('WAITING FOR ORDER');
    case 'payment_insufficient':
      return u.contains('INSUFFICIENT') || u.contains('PAYMENT INSUFFICIENT');
    case 'wait_balance':
      return u.contains('BALANCE PAYMENT CONFIRMATION') ||
          u.contains('WAITING FOR BALANCE') ||
          (o.balanceProofPending &&
              (o.supplementalProof?.trim().isNotEmpty ?? false));
    default:
      return true;
  }
}

bool matchesPreparingFilter(PosOrderView o, String mode) {
  final u = o.status.toUpperCase();
  if (mode == 'payment_confirmed') {
    return u.contains('ORDER CONFIRMED') && !u.contains('OVERPAYMENT');
  }
  if (mode == 'overpayment') return u.contains('OVERPAYMENT');
  return true;
}

bool isWalkIn(PosOrderView o) => o.orderSource.toUpperCase() == 'POS';
