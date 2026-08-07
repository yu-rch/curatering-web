part of 'catering.dart';

extension _ManageEventsDetailExt on _ManageEventsState {
  String get _activeManageEventsStage => _ManageEventsState._stageKeys[
      _tabController.index.clamp(0, _ManageEventsState._stageKeys.length - 1)];

  /// Resolves catering_orders vs event_orders for manager API patches.
  String _managerOrderKind(EventOrderDto order) {
    final kind = order.orderKind.trim().toLowerCase();
    if (kind == 'catering' || kind == 'event') return kind;
    final t = order.orderType.trim().toLowerCase();
    if (t == 'catering' || t == 'catering_only') return 'catering';
    return 'event';
  }

  List<Map<String, dynamic>> _checklistRowsFromOrder(EventOrderDto order) {
    if (order.checklist.isNotEmpty) {
      return order.checklist
          .map(
            (c) => {
              'item': c.title,
              'description': c.description,
              'quantity': c.quantity,
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
    final tx = order.transactionNo;
    final total = order.totalCost > 0 ? order.totalCost : computeOrderTotalCost(order);
    final isCancelled = stage == 'cancelled' || order.status == 'cancelled';
    final isReadOnlyStage =
        isCancelled || stage == 'completed' || stage == 'for_full_payment';
    final canEditTheme = _isManager &&
        !isCancelled &&
        stage != 'for_full_payment' &&
        stage != 'completed' &&
        (order.orderType == 'catering_event' ||
            order.orderType.contains('event') ||
            order.includeMinimalEventStyling == true);
    final showSeating = stage == 'for_down_payment' ||
        stage == 'on_going' ||
        stage == 'for_full_payment' ||
        stage == 'completed';

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
                    _amberStageButton(
                      label: 'Move to Down Payment',
                      onPressed: () => _openFinalizeOnlineInquiryDialog(
                        order,
                        initialTabIndex: 2,
                      ),
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
                        _detailInfoRow('Venue', order.address),
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
                  const SizedBox(height: 12),
                  _detailSection(
                    'Menu & allergens',
                    child: _buildMenuAllergensDetail(order),
                  ),
                  if (stage == 'on_going' && !isCancelled) ...[
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
                            label: Text(
                              (_isManager || _isSupervisor)
                                  ? 'Edit checklist'
                                  : 'View checklist',
                            ),
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
                    if (_isManager || _isSupervisor) ...[
                      const SizedBox(height: 12),
                      _detailSection(
                        'Task assignment',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showTaskAssignmentEditor(order),
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Task Assignment Editor'),
                            ),
                            const SizedBox(height: 6),
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
                    ],
                  ],
                  if (!_isSupervisor) ...[
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
                      'Seating layout',
                      child: isReadOnlyStage || !_isManager
                          ? Text(
                              order.seatingPlan.tables.isEmpty
                                  ? 'No seating plan saved.'
                                  : '${order.seatingPlan.tables.length} table(s) configured.',
                              style: const TextStyle(fontSize: 12),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openSeatingEditor(order),
                                  icon: const Icon(Icons.event_seat, size: 18),
                                  label: const Text('Edit seating layout'),
                                ),
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
    final rows = List<Map<String, dynamic>>.from(_taskRowsFromOrder(order));
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> editRowDialog(int index) async {
              final row = rows[index];
              final employee = TextEditingController(text: '${row['employee'] ?? ''}');
              final task = TextEditingController(text: '${row['tasks'] ?? ''}');
              final schedule = TextEditingController(
                text: '${row['schedule_of_tasks'] ?? ''}',
              );
              final budget = TextEditingController(text: '${row['budget'] ?? ''}');
              var status = '${row['status'] ?? 'not done'}';
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
                          decoration: const InputDecoration(
                            labelText: 'Schedule',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
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
                            DropdownMenuItem(value: 'done', child: Text('done')),
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
                          row['status'] = status;
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
              return DataCell(
                SizedBox(
                  width: width,
                  child: TextFormField(
                    initialValue: '${row[key] ?? ''}',
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(8),
                    ),
                    onChanged: (v) => row[key] = v,
                  ),
                ),
              );
            }

            return AlertDialog(
              title: Text('Task assignment — ${order.transactionNo}'),
              content: SizedBox(
                width: size.width * 0.9 > 1000 ? 1000 : size.width * 0.9,
                height: size.height * 0.78 > 640 ? 640 : size.height * 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: PagedDataTable(
                                title: 'Task assignment',
                                maxTableHeight: constraints.maxHeight,
                                forceVerticalScroll: true,
                                toolbarActions: [
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
                                columnSpacing: 12,
                                horizontalMargin: 8,
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 76,
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
                                          child: DropdownButtonFormField<String>(
                                            value: '${row['status'] ?? 'not done'}',
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                              contentPadding: EdgeInsets.all(8),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'not done',
                                                child: Text('not done'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'done',
                                                child: Text('done'),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) {
                                                setModal(() => row['status'] = v);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
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
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder:
                          (dctx) => AlertDialog(
                            title: const Text('Save task assignment'),
                            content: const Text(
                              'Apply changes to task assignment rows?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dctx).pop(true),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                        patch: {'task_assignment_rows': rows},
                      );
                      if (loaderCtx != null && Navigator.of(loaderCtx!).canPop()) {
                        Navigator.of(loaderCtx!).pop();
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _selectManageEventsOrder(order);
                    } catch (e) {
                      if (loaderCtx != null && Navigator.of(loaderCtx!).canPop()) {
                        Navigator.of(loaderCtx!).pop();
                      }
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
          final parts = <String>[m.dishName];
          if (m.paxOption.trim().isNotEmpty) parts.add(m.paxOption);
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
                  parts.join(' · '),
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

  Future<void> _openSeatingEditor(EventOrderDto order) async {
    await _openSeatingAssignmentEditor(order);
  }

  Future<void> _openSeatingAssignmentEditor(EventOrderDto order) async {
    final email = AuthSession.instance.currentUser.value?.email ?? '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 980,
              maxHeight: 760,
            ),
            // The editor screen internally uses a Scaffold; constraining it
            // matches the "smaller window" UX without rewriting the editor.
            child: SeatingLayoutEditorScreen(
              apiBase: apiBaseUrl,
              userEmail: email,
              orderId: order.id,
              orderKind: order.orderKind.isNotEmpty ? order.orderKind : 'event',
              initialPlan: order.seatingPlan,
              eventTitle: order.eventTitle,
              transactionNo: order.transactionNo,
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    await _selectManageEventsOrder(order);
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

  Widget _detailInfoRow(String label, String value) {
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
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                          : Image.memory(
                              Uint8List.fromList(imageUrl.codeUnits),
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
