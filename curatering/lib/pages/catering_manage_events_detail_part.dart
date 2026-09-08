part of 'catering.dart';

extension _ManageEventsDetailExt on _ManageEventsState {
  String get _activeManageEventsStage {
    // Supervisor only has the On Going tab (index 0); do not map that to
    // `_stageKeys[0]` (`new_event`) or checklist/task sections stay hidden.
    if (_isSupervisor) return 'on_going';
    return _ManageEventsState._stageKeys[_tabController.index
        .clamp(0, _ManageEventsState._stageKeys.length - 1)];
  }

  /// Resolves catering_orders vs event_orders for manager API patches.
  String _managerOrderKind(EventOrderDto order) {
    final kind = order.orderKind.trim().toLowerCase();
    if (kind == 'catering' || kind == 'event') return kind;
    final t = order.orderType.trim().toLowerCase();
    if (t == 'catering' || t == 'catering_only') return 'catering';
    return 'event';
  }

  String _paymentMethodLabel(EventOrderDto order) {
    final raw = order.postAnalysisRaw;
    for (final key in [
      'paymentMethod',
      'payment_method',
      'down_payment_method',
      'modeOfPayment',
      'mode_of_payment',
    ]) {
      final v = '${raw[key] ?? ''}'.trim();
      if (v.isNotEmpty) return v;
    }
    return '—';
  }

  List<Map<String, dynamic>> _checklistRowsFromOrder(EventOrderDto order) {
    if (order.checklist.isNotEmpty) {
      return order.checklist
          .map(
            (c) => {
              'item': c.title.trim().isEmpty ? c.description : c.title,
              'description': c.description,
              'quantity': c.quantity,
              'cost': c.price,
              'status': c.isCompleted ? 'completed' : 'not done',
            },
          )
          .where((row) => '${row['item']}'.trim().isNotEmpty)
          .toList();
    }
    return _buildChecklistFromMenuWithIngredients(order.menu)
        .map(
          (c) => {
            'item': c.item,
            'description': c.description,
            'quantity': c.quantity,
            'cost': c.cost,
            'status': c.isCompleted ? 'completed' : 'not done',
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _blankTaskAssignmentRows() {
    return List.generate(
      5,
      (_) => <String, dynamic>{
        'employee': '',
        'tasks': '',
        'schedule_of_tasks': '',
        'budget': '',
        'status': 'not done',
      },
    );
  }

  String _normalizeTaskRowStatus(dynamic status) {
    final s = '$status'.trim().toLowerCase();
    if (s.contains('not')) return 'not done';
    if (s == 'done' || s == 'completed' || s.contains('completed') || s.contains('done')) {
      return 'completed';
    }
    return 'not done';
  }

  List<Map<String, dynamic>> _taskRowsFromOrder(EventOrderDto order) {
    final raw = order.postAnalysisRaw['task_assignment_rows'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            m['status'] = _normalizeTaskRowStatus(m['status']);
            return m;
          })
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
    await printPdfBytes(bytes, name: name);
  }

  Future<void> _runPdfExport(
    Future<Uint8List> Function() build, {
    required String fileName,
  }) async {
    if (_pdfExportBusy) return;
    setState(() => _pdfExportBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparing PDF…'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      await Future<void>.delayed(Duration.zero);
      final bytes = await build();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      await _printPdfBytes(bytes, name: fileName);
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfExportBusy = false);
    }
  }

  Future<void> _generateOrderSummaryPdf(
    EventOrderDto order,
    OrderSummaryPdfVariant variant,
  ) async {
    final groups = variant == OrderSummaryPdfVariant.additionalCosts
        ? _additionalCostGroupsFromOrder(order)
        : const <Map<String, dynamic>>[];
    await _runPdfExport(
      () => buildManagerOrderSummaryPdf(
        order: order,
        variant: variant,
        additionalCostGroups: groups,
      ),
      fileName: 'order-summary.pdf',
    );
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
    final tx = order.transactionNo;
    final total = order.totalCost > 0 ? order.totalCost : computeOrderTotalCost(order);
    final isCancelled = stage == 'cancelled' || order.status == 'cancelled';
    // Theme design editing is exclusive to online_inquiries; otherwise view-only.
    final canEditTheme = _isManager &&
        !isCancelled &&
        (order.status == 'online_inquiries' || stage == 'online_inquiries') &&
        (order.orderType == 'catering_event' ||
            order.orderType.contains('event') ||
            order.includeMinimalEventStyling == true);
    final isCateringPlusEvent = _isCateringPlusEventOrder(order);
    final canEditSeating =
        isCateringPlusEvent && _canManageSeatingAssignmentsForStatus(order.status);
    final showSeating = isCateringPlusEvent &&
        (stage == 'for_down_payment' ||
            stage == 'on_going' ||
            stage == 'for_full_payment' ||
            stage == 'completed');

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
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isManager &&
                      !isCancelled &&
                      (stage == 'online_inquiries' || stage == 'new_event')) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _amberStageButton(
                            label: 'Move to Down Payment',
                            onPressed: () => _openFinalizeOnlineInquiryDialog(
                              order,
                              initialTabIndex: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel order'),
                                    content: const Text(
                                      'Cancel this online inquiry?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('No'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Cancel order'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true || !mounted) return;
                                try {
                                  await EventsApi.instance.managerFinalizeOnlineInquiry(
                                    orderId: order.id,
                                    payload: {'action': 'cancel_event'},
                                  );
                                  if (!mounted) return;
                                  await _refreshOrders();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Inquiry cancelled.'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to cancel: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Cancel order'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                backgroundColor: const Color(0xFFFFC107),
                                side: const BorderSide(color: Color(0xFFFFC107)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openFinalizeOnlineInquiryDialog(order),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E1E1E),
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                  if (stage == 'on_going' && !isCancelled && canEditSeating)
                    _amberStageButton(
                      label: 'Seating assignment',
                      icon: Icons.event_seat_outlined,
                      onPressed: () => _showSeatingAssignmentEditor(order),
                    ),
                  if (_isManager && stage == 'on_going' && !isCancelled)
                    _amberStageButton(
                      label: 'Move to Full Payment',
                      onPressed: () => _markOrderForFinalPayment(order),
                    ),
                  if (_isManager && stage == 'for_down_payment' && !isCancelled) ...[
                    _detailSection(
                      'Down payment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Amount due (50%): ${formatPesos(total / 2)}'),
                          const SizedBox(height: 8),
                          Text(
                            'Mode of payment: ${_paymentMethodLabel(order)}',
                            style: const TextStyle(fontSize: 13),
                          ),
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
                    const SizedBox(height: 12),
                  ],
                  if (_isManager && stage == 'for_full_payment' && !isCancelled) ...[
                    _detailSection(
                      'Full payment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Balance due: ${formatPesos(_fullPaymentRemainingAmount(order))}',
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
                            onPressed: order.fullPaymentStatus == 'paid'
                                ? () => _completeOrderWithConfirm(order)
                                : null,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Complete order'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                          ),
                          if (order.fullPaymentStatus != 'paid')
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Confirm full payment before completing this order.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isCancelled &&
                      stage != 'completed' &&
                      stage != 'cancelled' &&
                      !_isSupervisor) ...[
                    _detailSection(
                      'Additional costs',
                      child: _buildAdditionalCostsSection(
                        order,
                        editable: _isManager,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _detailSection(
                    'Event information',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailInfoRow('Transaction #', tx),
                        _detailInfoRow('Event', order.eventTitle),
                        if (!_isSupervisor) ...[
                          _detailInfoRow('Customer', order.customerName),
                          _detailInfoRow('Contact', order.contactPerson),
                          _detailInfoRow('Contact number', order.contactNumber),
                          _detailInfoRow('Email', order.emailAddress),
                        ],
                        _detailInfoRow('Event type', order.eventType),
                        if (!_isSupervisor)
                          _detailInfoRow('Guests', '${order.guestCount}'),
                        _detailInfoRow(
                          'Mode of payment',
                          _paymentMethodLabel(order),
                        ),
                        _detailInfoRow(
                          'Venue',
                          order.address,
                          onTap: order.address.trim().isEmpty
                              ? null
                              : () => showVenueMapDialog(context, order.address),
                        ),
                        _detailInfoRow('Schedule', _formatOrderSchedule(order)),
                        if (!_isSupervisor) ...[
                          _detailInfoRow('Total cost', formatPesos(total)),
                          if ((order.themeDesign.laborCost ?? 0) > 0)
                            _detailInfoRow(
                              'Labor cost',
                              formatPesos(order.themeDesign.laborCost!),
                            ),
                          if ((order.themeDesign.travelCost ?? 0) > 0)
                            _detailInfoRow(
                              'Travel cost',
                              formatPesos(order.themeDesign.travelCost!),
                            ),
                          if (_additionalCostsTotal(order) > 0)
                            _detailInfoRow(
                              'Additional costs',
                              formatPesos(_additionalCostsTotal(order)),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if ((stage == 'on_going' ||
                          stage == 'for_full_payment' ||
                          stage == 'completed') &&
                      !isCancelled) ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Checklist',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (stage == 'on_going')
                            const Text(
                              'Ingredients are loaded from the selected menu dishes.',
                              style: TextStyle(fontSize: 12),
                            ),
                          if (stage == 'on_going') const SizedBox(height: 8),
                          if (stage == 'on_going')
                            OutlinedButton.icon(
                              onPressed: () => _showChecklistDialog(order),
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: Text(
                                (_isManager || _isSupervisor)
                                    ? 'Edit checklist'
                                    : 'View checklist',
                              ),
                            ),
                          if (stage == 'on_going' && _isManager) const SizedBox(height: 6),
                          if (_isManager)
                            OutlinedButton.icon(
                              onPressed: _pdfExportBusy
                                  ? null
                                  : () async {
                                      final rows = _checklistRowsFromOrder(order);
                                      await _runPdfExport(
                                        () => buildChecklistPdf(
                                          order: order,
                                          stageLabel: stage
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                          checklistRows: rows,
                                        ),
                                        fileName: 'checklist.pdf',
                                      );
                                    },
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                              label: Text(
                                _pdfExportBusy
                                    ? 'Preparing PDF…'
                                    : 'Generate Checklist PDF',
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isManager || _isSupervisor) ...[
                      const SizedBox(height: 12),
                      _detailSection(
                        'Task assignment',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (stage == 'on_going')
                              OutlinedButton.icon(
                                onPressed: () => _showTaskAssignmentEditor(order),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text('Task Assignment Editor'),
                              ),
                            if (stage == 'on_going' && _isManager) const SizedBox(height: 6),
                            if (_isManager)
                              OutlinedButton.icon(
                                onPressed: _pdfExportBusy
                                    ? null
                                    : () async {
                                        final rows = _taskRowsFromOrder(order);
                                        await _runPdfExport(
                                          () => buildTaskAssignmentPdf(
                                            order: order,
                                            stageLabel: stage
                                                .replaceAll('_', ' ')
                                                .toUpperCase(),
                                            taskRows: rows,
                                          ),
                                          fileName: 'task-assignment.pdf',
                                        );
                                      },
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                label: Text(
                                  _pdfExportBusy
                                      ? 'Preparing PDF…'
                                      : 'Generate Task Assignment PDF',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  _detailSection(
                    'Menu & allergens',
                    child: _buildMenuAllergensDetail(order),
                  ),
                  if (!_isSupervisor) ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Order summary',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _pdfExportBusy
                                ? null
                                : () => _generateOrderSummaryPdf(
                                      order,
                                      OrderSummaryPdfVariant.beforeDownPayment,
                                    ),
                            child: const Text('Order Summary before Down Payment'),
                          ),
                          if (stage != 'new_event' && stage != 'online_inquiries')
                            OutlinedButton(
                              onPressed: _pdfExportBusy
                                  ? null
                                  : () => _generateOrderSummaryPdf(
                                        order,
                                        OrderSummaryPdfVariant.afterDownPayment,
                                      ),
                              child: const Text('Order Summary after Down Payment'),
                            ),
                          if ((stage == 'for_down_payment' ||
                                  stage == 'on_going' ||
                                  stage == 'for_full_payment') &&
                              _additionalCostsTotal(order) > 0)
                            OutlinedButton(
                              onPressed: _pdfExportBusy
                                  ? null
                                  : () => _generateOrderSummaryPdf(
                                        order,
                                        OrderSummaryPdfVariant.additionalCosts,
                                      ),
                              child: const Text('Order Summary | Additional Costs'),
                            ),
                          if (stage == 'completed')
                            OutlinedButton(
                              onPressed: _pdfExportBusy
                                  ? null
                                  : () => _generateOrderSummaryPdf(
                                        order,
                                        OrderSummaryPdfVariant.fullyPaid,
                                      ),
                              child: const Text('Order Summary Fully Paid'),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_orderHasEventDesign(order) || canEditTheme) ...[
                    const SizedBox(height: 12),
                    _buildEventDesignDetailSection(order, readOnly: !canEditTheme),
                  ],
                  if (stage == 'for_full_payment' &&
                      !isCancelled &&
                      _isCateringPlusEventOrder(order)) ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Actual event photos',
                      child: _buildActualEventPhotosSection(order),
                    ),
                  ],
                  if (showSeating) ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      'Seating assignment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            order.seatingPlan.tables.isEmpty
                                ? 'No seating plan saved yet.'
                                : '${order.seatingPlan.tables.length} table(s) · '
                                    '${order.seatingPlan.tables.fold<int>(0, (n, t) => n + t.seatCount)} seat(s) configured.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (canEditSeating) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () =>
                                  _showSeatingAssignmentEditor(order),
                              icon: const Icon(Icons.event_seat, size: 18),
                              label: Text(
                                order.seatingPlan.tables.isEmpty
                                    ? 'Create seating assignment'
                                    : 'Edit seating assignment',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOrderWithConfirm(EventOrderDto order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete order'),
        content: const Text(
          'Are you sure you want to mark this transaction complete?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await EventsApi.instance.completeOrder(
        orderId: order.id,
      );
      if (!mounted) return;
      await _refreshOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked completed.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _showTaskAssignmentEditor(EventOrderDto order) async {
    _checklistTaskEditorOpen = true;
    final existing = _taskRowsFromOrder(order);
    final rows = List<Map<String, dynamic>>.from(
      existing.isEmpty ? _blankTaskAssignmentRows() : existing,
    );
    final size = MediaQuery.sizeOf(context);
    final modalHeight = (size.height * 0.58).clamp(320.0, 520.0);
    var isEditingTasks = false;
    try {
    await showAntdModal<void>(
      context: context,
      title: 'Task assignment — ${order.transactionNo}',
      maxWidth: 1000,
      scrollBody: false,
      body: StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> editRowDialog(int index) async {
              if (!isEditingTasks) return;
              final row = rows[index];
              final employee = TextEditingController(text: '${row['employee'] ?? ''}');
              final task = TextEditingController(text: '${row['tasks'] ?? ''}');
              final schedule = TextEditingController(
                text: '${row['schedule_of_tasks'] ?? ''}',
              );
              final budget = TextEditingController(text: '${row['budget'] ?? ''}');
              var status = _normalizeTaskRowStatus(row['status']);
              await showDialog<void>(
                context: ctx,
                builder: (dctx) => AlertDialog(
                  title: const Text('Edit task row'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: employee,
                          decoration: const InputDecoration(
                            labelText: 'Employee',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: task,
                          decoration: const InputDecoration(
                            labelText: 'Task',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: schedule,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Schedule',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          onTap: () async {
                            final now = DateTime.now();
                            DateTime initial = now;
                            final existing = schedule.text.trim();
                            if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(existing)) {
                              final p = existing.split('-');
                              initial = DateTime(
                                int.parse(p[0]),
                                int.parse(p[1]),
                                int.parse(p[2]),
                              );
                            }
                            final picked = await showDatePicker(
                              context: dctx,
                              initialDate: initial,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (picked == null) return;
                            final y = picked.year.toString().padLeft(4, '0');
                            final m = picked.month.toString().padLeft(2, '0');
                            final d = picked.day.toString().padLeft(2, '0');
                            schedule.text = '$y-$m-$d';
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: budget,
                          decoration: const InputDecoration(
                            labelText: 'Budget',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(value: 'not done', child: Text('not done')),
                            DropdownMenuItem(value: 'completed', child: Text('completed')),
                          ],
                          onChanged: (v) => status = v ?? status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        setModal(() {
                          row['employee'] = employee.text.trim();
                          row['tasks'] = task.text.trim();
                          row['schedule_of_tasks'] = schedule.text.trim();
                          row['budget'] = budget.text.trim();
                          row['status'] = _normalizeTaskRowStatus(status);
                        });
                        Navigator.pop(dctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              );
              employee.dispose();
              task.dispose();
              schedule.dispose();
              budget.dispose();
            }

            DataCell taskCell(
              String label,
              String key,
              Map<String, dynamic> row, {
              double width = 150,
            }) {
              final value = '${row[key] ?? ''}';
              return DataCell(
                SizedBox(
                  width: width,
                  child: isEditingTasks
                      ? TextFormField(
                          initialValue: value,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: label,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          onChanged: (v) => row[key] = v,
                        )
                      : Text(
                          value.isEmpty ? '—' : value,
                          style: const TextStyle(fontSize: 13),
                        ),
                ),
              );
            }

            return SizedBox(
                height: modalHeight,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return PagedDataTable(
                                title: 'Task assignment',
                                maxTableHeight: constraints.maxHeight,
                                forceVerticalScroll: true,
                                fullWidth: true,
                                minTableWidth: 860,
                                enablePrint: false,
                                toolbarActions: [
                                  if (!isEditingTasks)
                                    AntdSecondaryButton(
                                      onPressed: () => setModal(
                                        () => isEditingTasks = true,
                                      ),
                                      icon: Icons.edit_outlined,
                                      label: 'Edit',
                                    ),
                                  if (isEditingTasks) ...[
                                    AntdSecondaryButton(
                                      onPressed: () => setModal(
                                        () => isEditingTasks = false,
                                      ),
                                      icon: Icons.visibility_outlined,
                                      label: 'View only',
                                    ),
                                    AntdSecondaryButton(
                                      onPressed: () {
                                        setModal(() {
                                          rows.add({
                                            'employee': '',
                                            'tasks': '',
                                            'schedule_of_tasks': '',
                                            'budget': '',
                                            'status': 'not done',
                                          });
                                        });
                                      },
                                      icon: Icons.add,
                                      label: 'Add row',
                                    ),
                                  ],
                                ],
                                columnSpacing: 8,
                                horizontalMargin: 6,
                                dataRowMinHeight: 40,
                                dataRowMaxHeight: 48,
                                headingRowHeight: 40,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade200,
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text('Employee'),
                                    columnWidth: FixedColumnWidth(150),
                                  ),
                                  DataColumn(
                                    label: Text('Task'),
                                    columnWidth: FixedColumnWidth(200),
                                  ),
                                  DataColumn(
                                    label: Text('Schedule'),
                                    columnWidth: FixedColumnWidth(160),
                                  ),
                                  DataColumn(
                                    label: Text('Budget'),
                                    columnWidth: FixedColumnWidth(110),
                                  ),
                                  DataColumn(
                                    label: Text('Status'),
                                    columnWidth: FixedColumnWidth(120),
                                  ),
                                  DataColumn(
                                    label: Text('Actions'),
                                    columnWidth: FixedColumnWidth(104),
                                  ),
                                ],
                                rows: rows.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  return DataRow(
                                    cells: [
                                      taskCell('Employee', 'employee', row),
                                      taskCell('Task', 'tasks', row, width: 190),
                                      taskCell(
                                        'Schedule',
                                        'schedule_of_tasks',
                                        row,
                                        width: 150,
                                      ),
                                      taskCell('Budget', 'budget', row, width: 100),
                                      DataCell(
                                        SizedBox(
                                          width: 110,
                                          child: isEditingTasks
                                              ? DropdownButtonFormField<String>(
                                            value: _normalizeTaskRowStatus(row['status']),
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'not done',
                                                child: Text('not done'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'completed',
                                                child: Text('completed'),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) {
                                                setModal(() => row['status'] = _normalizeTaskRowStatus(v));
                                              }
                                            },
                                          )
                                              : Text(
                                            _normalizeTaskRowStatus(row['status']),
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        isEditingTasks
                                            ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit row',
                                              onPressed: () => editRowDialog(index),
                                              icon: const Icon(Icons.edit_outlined),
                                            ),
                                            IconButton(
                                              tooltip: 'Remove row',
                                              onPressed: () {
                                                setModal(() => rows.removeAt(index));
                                              },
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ],
                                        )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AntdCancelButton(
                          label: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 8),
                        AntdPrimaryButton(
                          label: 'Save',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: const Text('Save task assignment'),
                                content: const Text(
                                  'Apply changes to task assignment rows?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(true),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            BuildContext? loaderCtx;
                            try {
                              showDialog<void>(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (dctx) {
                                  loaderCtx = dctx;
                                  return const AlertDialog(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Saving task assignment...'),
                                      ],
                                    ),
                                  );
                                },
                              );
                              await ManagerCateringApi.instance.patchStageData(
                                id: order.id,
                                orderKind: _managerOrderKind(order),
                                patch: {
                                  'task_assignment_rows': rows
                                      .map((r) {
                                        final m = Map<String, dynamic>.from(r);
                                        m['status'] = _normalizeTaskRowStatus(m['status']);
                                        return m;
                                      })
                                      .toList(),
                                },
                              );
                              if (loaderCtx != null &&
                                  Navigator.of(loaderCtx!).canPop()) {
                                Navigator.of(loaderCtx!).pop();
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _selectManageEventsOrder(order);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Task assignment saved.'),
                                    backgroundColor: Color(0xFF1DB954),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (loaderCtx != null &&
                                  Navigator.of(loaderCtx!).canPop()) {
                                Navigator.of(loaderCtx!).pop();
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Save failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
            );
          },
      ),
      actions: const [],
    );
    } finally {
      _checklistTaskEditorOpen = false;
    }
  }

  Widget _buildMenuAllergensDetail(EventOrderDto order) {
    if (order.menu.isEmpty) {
      return Text(
        'No menu selected.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      );
    }
    final orderAllergens = order.allergens.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (orderAllergens.isNotEmpty) ...[
          Text(
            'Order allergens: $orderAllergens',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...order.menu.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.setMenuName.trim().isNotEmpty)
                  Text(
                    m.setMenuName.trim(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                Text(
                  m.dishName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (m.additionalChargeAmount > 0)
                  Text(
                    'Extra dish fee: ${formatPesos(m.additionalChargeAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (m.dishAllergens.trim().isNotEmpty)
                  Text(
                    'Allergens: ${m.dishAllergens.trim()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Map<String, dynamic> _themeDesignMap(EventOrderDto order) {
    final td = order.themeDesign;
    return {
      'picksBase64': td.picksBase64,
      'tintEnabled': td.tintEnabled,
      if (td.tintColorHex != null) 'tintColorHex': td.tintColorHex,
      if (td.colorPrompt != null) 'colorPrompt': td.colorPrompt,
      'wantsCustomDesign': td.wantsCustomDesign,
      if (td.customerThemeRequest != null) 'customerThemeRequest': td.customerThemeRequest,
      if (td.generatedImageUrl != null) 'generatedImageUrl': td.generatedImageUrl,
      if (td.customInstructions != null) 'customInstructions': td.customInstructions,
      if (td.eventDesignSource != null) 'eventDesignSource': td.eventDesignSource,
      if (td.macrinaColorPalette != null) 'macrinaColorPalette': td.macrinaColorPalette,
      if (td.macrinaTheme != null) 'macrinaTheme': td.macrinaTheme,
      if (td.macrinaTheme != null) 'style': td.macrinaTheme,
      if (td.macrinaColorPalette != null) 'colorPalette': [td.macrinaColorPalette],
    };
  }

  Widget _amberStageButton({
    required String label,
    required VoidCallback onPressed,
    IconData icon = Icons.arrow_forward,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC024),
            foregroundColor: const Color(0xFF242424),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  double _additionalCostsTotal(EventOrderDto order) {
    var total = 0.0;
    for (final group in _additionalCostGroupsFromOrder(order)) {
      final items = group['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            total += double.tryParse('${item['amount'] ?? item['cost'] ?? 0}') ?? 0;
          }
        }
      }
      final groupTotal = group['total'];
      if (groupTotal is num && items is! List) {
        total += groupTotal.toDouble();
      }
    }
    final flat = order.postAnalysisRaw['additional_costs'];
    if (flat is List && _additionalCostGroupsFromOrder(order).isEmpty) {
      for (final item in flat) {
        if (item is Map) {
          total += double.tryParse('${item['amount'] ?? item['cost'] ?? 0}') ?? 0;
        }
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _additionalCostsFlatFromOrder(EventOrderDto order) {
    final groups = _additionalCostGroupsFromOrder(order);
    if (groups.isNotEmpty) {
      final out = <Map<String, dynamic>>[];
      for (final group in groups) {
        final items = group['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map) continue;
          out.add({
            'label': '${item['label'] ?? item['name'] ?? 'Item'}',
            'amount': double.tryParse('${item['amount'] ?? item['cost'] ?? 0}') ?? 0,
          });
        }
      }
      if (out.isNotEmpty) return out;
    }
    final flat = order.postAnalysisRaw['additional_costs'];
    if (flat is! List) return [];
    return flat
        .whereType<Map>()
        .map(
          (e) => {
            'label': '${e['label'] ?? e['name'] ?? 'Item'}',
            'amount': double.tryParse('${e['amount'] ?? e['cost'] ?? 0}') ?? 0,
          },
        )
        .toList();
  }

  Widget _buildAdditionalCostsSection(
    EventOrderDto order, {
    bool editable = false,
  }) {
    final rows = _additionalCostsFlatFromOrder(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isEmpty)
          Text(
            'No additional costs recorded yet.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          )
        else
          ...rows.map((row) {
            final label = '${row['label']}'.trim();
            final amount = (row['amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '$label — ${formatPesos(amount)}',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }),
        const SizedBox(height: 6),
        Text(
          'Total additional costs: ${formatPesos(_additionalCostsTotal(order))}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        if (editable) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAdditionalCostsEditor(order),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Edit additional costs'),
          ),
        ],
      ],
    );
  }

  Future<void> _showAdditionalCostsEditor(EventOrderDto order) async {
    final rows = List<Map<String, dynamic>>.from(
      _additionalCostsFlatFromOrder(order),
    );
    final labelController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            void addRow() {
              final label = labelController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (label.isEmpty || amount == null) return;
              setModal(() {
                rows.add({'label': label, 'amount': amount});
                labelController.clear();
                amountController.clear();
              });
            }

            return AlertDialog(
              title: Text('Additional costs — ${order.transactionNo}'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: labelController,
                            decoration: const InputDecoration(
                              labelText: 'Label',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => addRow(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixText: 'PHP ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => addRow(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add line',
                          onPressed: addRow,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      Text(
                        'No line items yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      )
                    else
                      ...rows.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;
                        final label = '${row['label']}';
                        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(label, style: const TextStyle(fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatPesos(amount),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () => setModal(() => rows.removeAt(idx)),
                                icon: const Icon(Icons.delete_outline, size: 20),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await ManagerCateringApi.instance.patchStageData(
                        id: order.id,
                        orderKind: _managerOrderKind(order),
                        patch: {'additional_costs': rows},
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _selectManageEventsOrder(order);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    labelController.dispose();
    amountController.dispose();
  }

  Future<void> _openThemeDesignEditor(EventOrderDto order) async {
    final email = AuthSession.instance.currentUser.value?.email ?? '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 920,
              maxHeight: 680,
            ),
            child: EventThemeDesignScreen(
              apiBase: apiBaseUrl,
              userEmail: email,
              orderId: order.id,
              orderKind: order.orderKind.isNotEmpty ? order.orderKind : 'event',
              initialEventType:
                  order.eventType.isNotEmpty ? order.eventType : 'other',
              initialThemeDesign: _themeDesignMap(order),
              eventTitle: order.eventTitle,
              formalityLevel: order.formalityLevel,
              persistToOrder: true,
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    await _selectManageEventsOrder(order);
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

  Widget _detailInfoRow(String label, String value, {VoidCallback? onTap}) {
    final display = value.trim().isEmpty ? '—' : value;
    final valueWidget = Text(
      display,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onTap != null ? const Color(0xFF1E1E1E) : null,
        decoration: onTap != null ? TextDecoration.underline : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 156,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: onTap == null
                ? valueWidget
                : InkWell(
                    onTap: onTap,
                    child: Row(
                      children: [
                        Expanded(child: valueWidget),
                        const Icon(Icons.map_outlined, size: 16, color: Color(0xFFFFC024)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActualEventPhotosSection(EventOrderDto order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.actualEventImages.isEmpty)
          Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'No event photos uploaded yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _uploadEventPhotos(order),
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Upload photos'),
              ),
            ],
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: order.actualEventImages.asMap().entries.map((entry) {
              final index = entry.key;
              final imageUrl = entry.value;
              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : CachedBase64Image(
                              base64String: imageUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  if (_isManager)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeEventPhoto(order, index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _uploadEventPhotos(order),
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('Add more photos'),
          ),
        ],
      ],
    );
  }
}
