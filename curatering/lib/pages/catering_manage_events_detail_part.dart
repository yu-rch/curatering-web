part of 'catering.dart';

extension _ManageEventsDetailExt on _ManageEventsState {
  String get _activeManageEventsStage => _ManageEventsState._stageKeys[
      _tabController.index.clamp(0, _ManageEventsState._stageKeys.length - 1)];

  List<Map<String, dynamic>> _checklistRowsFromOrder(EventOrderDto order) {
    if (order.checklist.isNotEmpty) {
      return order.checklist
          .map(
            (c) => {
              'item': c.title,
              'description': c.description,
              'quantity': 1,
              'cost': c.price,
              'status': c.isCompleted ? 'done' : 'not done',
            },
          )
          .toList();
    }
    return _buildChecklistFromMenuWithIngredients(order.menu)
        .map(
          (c) => {
            'item': c.item,
            'description': c.description,
            'quantity': c.quantity,
            'cost': c.cost,
            'status': c.isCompleted ? 'done' : 'not done',
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _taskRowsFromOrder(EventOrderDto order) {
    final raw = order.postAnalysisRaw['task_assignment_rows'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _additionalCostGroupsFromOrder(EventOrderDto order) {
    final raw = order.postAnalysisRaw['additional_costs_groups'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final flat = order.postAnalysisRaw['additional_costs'];
    if (flat is List && flat.isNotEmpty) {
      return [
        {
          'stage': 'Additional costs',
          'items': flat,
          'total': flat.fold<double>(0, (s, e) {
            if (e is Map) {
              return s + (double.tryParse('${e['amount'] ?? e['cost'] ?? 0}') ?? 0);
            }
            return s;
          }),
        },
      ];
    }
    return const [];
  }

  Future<void> _printPdfBytes(Uint8List bytes, {String name = 'document.pdf'}) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }

  Future<void> _generateOrderSummaryPdf(
    EventOrderDto order,
    OrderSummaryPdfVariant variant,
  ) async {
    final groups = variant == OrderSummaryPdfVariant.additionalCosts
        ? _additionalCostGroupsFromOrder(order)
        : const <Map<String, dynamic>>[];
    final bytes = await buildManagerOrderSummaryPdf(
      order: order,
      variant: variant,
      additionalCostGroups: groups,
    );
    await _printPdfBytes(bytes, name: 'order-summary.pdf');
  }

  Widget _buildManageEventsDetailPanel() {
    if (_manageEventsDetailLoading) {
      return Card(
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_manageEventsDetailError != null) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_manageEventsDetailError!, style: TextStyle(color: Colors.red.shade700)),
          ),
        ),
      );
    }
    final order = _selectedManageEventsOrder;
    if (order == null) {
      return Card(
        child: Center(
          child: Text(
            'Select an inquiry or transaction to view details.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final stage = _activeManageEventsStage;
    final tx = order.cateringId.isNotEmpty ? order.cateringId : order.id;
    final total = order.totalCost > 0 ? order.totalCost : computeOrderTotalCost(order);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_ManageEventsState._stageLabels[_tabController.index]} — $tx',
                    style: const TextStyle(
                      color: Color(0xFFFFC024),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (stage == 'online_inquiries' || stage == 'new_event')
                  TextButton(
                    onPressed: () => _openFinalizeOnlineInquiryDialog(order),
                    child: const Text('Move to Down Payment', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailSection(
                    'Event information',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailInfoRow('Event', order.eventTitle),
                        _detailInfoRow('Customer', order.customerName),
                        _detailInfoRow('Contact', order.contactPerson),
                        _detailInfoRow('Contact number', order.contactNumber),
                        _detailInfoRow('Email', order.emailAddress),
                        _detailInfoRow('Event type', order.eventType),
                        _detailInfoRow('Guests', '${order.guestCount}'),
                        _detailInfoRow('Venue', order.address),
                        _detailInfoRow('Schedule', _formatOrderSchedule(order)),
                        _detailInfoRow('Total cost', formatPesos(total)),
                      ],
                    ),
                  ),
                  if (stage == 'for_down_payment') ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Down payment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Amount due (50%): ${formatPesos(total / 2)}'),
                          const SizedBox(height: 8),
                          if (order.downPaymentStatus == 'paid')
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'DOWN PAYMENT CONFIRMED — ${formatPesos(order.downPaymentAmount)}',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showConfirmDownpaymentDialog(order),
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Confirm down payment'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (stage == 'on_going') ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Checklist',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ingredients are loaded from the selected menu dishes.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _showChecklistDialog(order),
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Edit checklist'),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final rows = _checklistRowsFromOrder(order);
                              final bytes = await buildChecklistPdf(
                                order: order,
                                stageLabel: stage.replaceAll('_', ' ').toUpperCase(),
                                checklistRows: rows,
                              );
                              await _printPdfBytes(bytes, name: 'checklist.pdf');
                            },
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Generate Checklist PDF'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailSection(
                      'Task assignment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final rows = _taskRowsFromOrder(order);
                              final bytes = await buildTaskAssignmentPdf(
                                order: order,
                                stageLabel: stage.replaceAll('_', ' ').toUpperCase(),
                                taskRows: rows,
                              );
                              await _printPdfBytes(bytes, name: 'task-assignment.pdf');
                            },
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Generate Task Assignment PDF'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _markOrderForFinalPayment(order),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to For Full Payment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        foregroundColor: const Color(0xFFFFC024),
                      ),
                    ),
                  ],
                  if (stage == 'for_full_payment') ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Full payment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Balance due: ${formatPesos((total - order.downPaymentAmount).clamp(0, double.infinity))}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showFinalizeFullPaymentDialog(order),
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Confirm full payment'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _openFullPaymentCompleteModal(order),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Complete order'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _detailSection(
                    'Order summary',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _generateOrderSummaryPdf(
                            order,
                            OrderSummaryPdfVariant.beforeDownPayment,
                          ),
                          child: const Text('Order Summary before Down Payment'),
                        ),
                        if (stage != 'new_event' && stage != 'online_inquiries')
                          OutlinedButton(
                            onPressed: () => _generateOrderSummaryPdf(
                              order,
                              OrderSummaryPdfVariant.afterDownPayment,
                            ),
                            child: const Text('Order Summary after Down Payment'),
                          ),
                        if (stage == 'for_down_payment' ||
                            stage == 'on_going' ||
                            stage == 'for_full_payment')
                          OutlinedButton(
                            onPressed: () => _generateOrderSummaryPdf(
                              order,
                              OrderSummaryPdfVariant.additionalCosts,
                            ),
                            child: const Text('Order Summary | Additional Costs'),
                          ),
                        if (stage == 'completed')
                          OutlinedButton(
                            onPressed: () => _generateOrderSummaryPdf(
                              order,
                              OrderSummaryPdfVariant.fullyPaid,
                            ),
                            child: const Text('Order Summary Fully Paid'),
                          ),
                      ],
                    ),
                  ),
                  if (_orderHasEventDesign(order)) ...[
                    const SizedBox(height: 12),
                    _buildEventDesignDetailSection(order),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, {required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3D0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  Widget _detailInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
