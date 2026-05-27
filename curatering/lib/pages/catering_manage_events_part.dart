part of 'catering.dart';

extension _ManageEventsTableExt on _ManageEventsState {
  bool _canEventAction(String permissionKey) {
    final user = AuthSession.instance.currentUser.value;
    return actionAllowed(
      permissionKey,
      user?.pagePermissions,
      role: user?.role,
    );
  }

  Widget _eventIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required String permissionKey,
    Color? color,
  }) {
    if (!_canEventAction(permissionKey)) return const SizedBox.shrink();
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      visualDensity: VisualDensity.compact,
    );
  }

  List<EventOrderDto> get _downpaymentOrders =>
      _processingOrdersDto
          .where((o) => _isForDownpaymentStatus(o.status))
          .toList();

  List<EventOrderDto> get _ongoingOrders =>
      _processingOrdersDto.where((o) => _isOngoingStatus(o.status)).toList();

  bool _isForDownpaymentStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'for_down_payment' || normalized == 'for_downpayment';
  }

  bool _isOngoingStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'on_going' ||
        normalized == 'ongoing' ||
        normalized == 'for_ongoing';
  }

  bool _canManageSeatingAssignmentsForStatus(String status) {
    final role = AuthSession.instance.currentRole;
    return _isOngoingStatus(status) &&
        (role == Role.manager ||
            role == Role.supervisor ||
            role == Role.superAdmin);
  }

  String _formatOrderSchedule(EventOrderDto dto) {
    if (dto.scheduleSlots.isEmpty) return '—';
    final s = dto.scheduleSlots.first;
    return '${s.date} ${s.startTime}';
  }

  String _orderTypeColumnLabel(EventOrderDto dto) {
    return orderTypeDisplayLabel(dto.orderType, eventTitle: dto.eventTitle);
  }

  String _formatMenuLines(EventOrderDto dto) {
    if (dto.menu.isEmpty) return '—';
    final lines = <String>[];
    String? currentSet;
    for (final m in dto.menu) {
      final set = m.setMenuName.trim();
      if (set.isNotEmpty && set != currentSet) {
        currentSet = set;
        lines.add('Set: $set');
      }
      final parts = <String>[m.dishName];
      if (m.paxOption.trim().isNotEmpty) parts.add(m.paxOption);
      if (m.price.trim().isNotEmpty && m.price != '0') parts.add(m.price);
      if (m.dishAllergens.trim().isNotEmpty) {
        parts.add('allergens: ${m.dishAllergens}');
      }
      lines.add('  • ${parts.join(' · ')}');
    }
    return lines.join('\n');
  }

  String _themeExtrasLine(EventOrderDto dto) {
    final td = dto.themeDesign;
    final parts = <String>[];
    if (td.eventDesignSource == 'customer_ai') {
      parts.add('Customer AI event design');
    } else if (td.eventDesignSource == 'macrina') {
      parts.add('Macrina will design the event');
    }
    if (td.wantsCustomDesign) parts.add('Custom design requested');
    final prompt = (td.customInstructions ?? td.colorPrompt ?? '').trim();
    if (prompt.isNotEmpty) parts.add('Design prompt: $prompt');
    if (td.customerThemeRequest != null &&
        td.customerThemeRequest!.trim().isNotEmpty) {
      parts.add(td.customerThemeRequest!.trim());
    }
    if (td.macrinaColorPalette != null &&
        td.macrinaColorPalette!.trim().isNotEmpty) {
      parts.add('Palette: ${td.macrinaColorPalette}');
    }
    if (td.macrinaTheme != null && td.macrinaTheme!.trim().isNotEmpty) {
      parts.add('Macrina theme: ${td.macrinaTheme}');
    }
    if (td.generatedImageUrl != null &&
        td.generatedImageUrl!.trim().isNotEmpty) {
      parts.add('AI design image submitted');
    }
    if (td.picksBase64.isNotEmpty) {
      parts.add('${td.picksBase64.length} reference photo(s)');
    }
    return parts.isEmpty ? '—' : parts.join('\n');
  }

  bool _orderHasEventDesign(EventOrderDto dto) {
    final td = dto.themeDesign;
    return td.picksBase64.isNotEmpty ||
        (td.generatedImageUrl?.trim().isNotEmpty ?? false) ||
        (td.customInstructions?.trim().isNotEmpty ?? false) ||
        (td.colorPrompt?.trim().isNotEmpty ?? false) ||
        (td.customerThemeRequest?.trim().isNotEmpty ?? false) ||
        td.wantsCustomDesign;
  }

  Widget _buildEventDesignDetailSection(EventOrderDto dto) {
    final td = dto.themeDesign;
    final imageUrl = td.generatedImageUrl?.trim() ?? '';
    final picks =
        td.picksBase64
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();

    Widget imageFromSource(String source, {BoxFit fit = BoxFit.cover}) {
      if (source.startsWith('http://') || source.startsWith('https://')) {
        return Image.network(
          source,
          fit: fit,
          errorBuilder:
              (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
        );
      }
      try {
        return Image.memory(base64Decode(source), fit: fit);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image));
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVENT DESIGN (CUSTOMER)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            _themeExtrasLine(dto),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'AI-generated design',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: imageFromSource(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ],
          if (picks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Reference photos (${picks.length})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: picks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 100,
                      child: imageFromSource(picks[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<AntdDescriptionItem> _orderDetailDescriptionItems(
    EventOrderDto dto, {
    required double screenWidth,
  }) {
    final cols = screenWidth < 700 ? 1 : 3;
    final total =
        dto.totalCost > 0 ? dto.totalCost : computeOrderTotalCost(dto);
    return [
      AntdDescriptionItem(
        label: 'Service type',
        value: _orderTypeColumnLabel(dto),
      ),
      AntdDescriptionItem(label: 'Status', value: dto.status),
      AntdDescriptionItem(
        label: 'Final status',
        value: dto.finalStatus.isEmpty ? '—' : dto.finalStatus,
      ),
      AntdDescriptionItem(
        label: 'Event / title',
        value: dto.eventTitle.isEmpty ? '—' : dto.eventTitle,
        span: cols >= 2 ? 2 : 1,
      ),
      AntdDescriptionItem(
        label: 'Event type',
        value: dto.eventType.isEmpty ? '—' : dto.eventType,
      ),
      AntdDescriptionItem(
        label: 'Formality',
        value: dto.formalityLevel.isEmpty ? '—' : dto.formalityLevel,
      ),
      AntdDescriptionItem(label: 'Customer', value: dto.customerName),
      AntdDescriptionItem(label: 'Contact person', value: dto.contactPerson),
      AntdDescriptionItem(label: 'Phone', value: dto.contactNumber),
      AntdDescriptionItem(
        label: 'Email',
        value: dto.emailAddress,
        span: cols >= 2 ? 2 : 1,
      ),
      AntdDescriptionItem(label: 'Guests', value: '${dto.guestCount}'),
      AntdDescriptionItem(
        label: 'Allergens',
        value: dto.allergens.trim().isEmpty ? '—' : dto.allergens,
        span: cols >= 2 ? 2 : 1,
      ),
      AntdDescriptionItem(
        label: 'Schedule',
        value:
            dto.scheduleSlots.isEmpty
                ? '—'
                : dto.scheduleSlots
                    .map((s) => '${s.date} ${s.startTime}–${s.endTime}')
                    .join('\n'),
        span: cols >= 2 ? 2 : 1,
      ),
      AntdDescriptionItem(
        label: 'Address',
        value: dto.address.isEmpty ? '—' : dto.address,
        span: cols >= 2 ? 2 : 1,
      ),
      AntdDescriptionItem(
        label: 'Menu',
        value: _formatMenuLines(dto),
        span: cols,
      ),
      AntdDescriptionItem(
        label: 'Theme / notes',
        value: _themeExtrasLine(dto),
        span: cols >= 2 ? 2 : 1,
      ),
      AntdDescriptionItem(label: 'Total cost', value: formatPesos(total)),
      AntdDescriptionItem(
        label: 'Down payment',
        value:
            '${dto.downPaymentStatus} · ${formatPesos(dto.downPaymentAmount > 0 ? dto.downPaymentAmount : total / 2)}',
      ),
      AntdDescriptionItem(
        label: 'Full payment',
        value:
            '${dto.fullPaymentStatus} · ${formatPesos(dto.fullPaymentAmount > 0 ? dto.fullPaymentAmount : total)}',
      ),
    ];
  }

  Future<EventOrderDto> _loadOrderForDetail(EventOrderDto dto) async {
    try {
      final role = AuthSession.instance.currentRole;
      final roleType = role == Role.supervisor ? 'supervisor' : 'manager';
      return await EventsApi.instance.getEventOrder(
        orderId: dto.id,
        roleType: roleType,
      );
    } catch (_) {
      return dto;
    }
  }

  Future<void> _showSeatingAssignmentEditor(EventOrderDto dto) async {
    final full = await _loadOrderForDetail(dto);
    if (!_isCateringPlusEventOrder(full)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seating assignment is only available for event orders.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    await showAntdModal<void>(
      context: context,
      title: 'Edit seating assignment',
      maxWidth: 980,
      body: SingleChildScrollView(
        child: ProcessingSeatingSection(order: full, onSaved: _refreshOrders),
      ),
      actions: [
        AntdCancelButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _showEventOrderDetailModal(EventOrderDto dto) async {
    final w = MediaQuery.sizeOf(context).width;
    EventOrderDto full = dto;
    final canOpenSeatingEditor = _canManageSeatingAssignmentsForStatus(
      dto.status,
    );
    final canPostChanges =
        canOpenSeatingEditor && _isCateringPlusEventOrder(dto);
    await showAntdModal<void>(
      context: context,
      title: dto.eventTitle.isEmpty ? dto.customerName : dto.eventTitle,
      maxWidth: 800,
      body: FutureBuilder<EventOrderDto>(
        future: _loadOrderForDetail(dto),
        builder: (context, snap) {
          full = snap.data ?? dto;
          final canEditSeating =
              _canManageSeatingAssignmentsForStatus(full.status) &&
              _isCateringPlusEventOrder(full);
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AntdDescriptions(
                  column: w < 700 ? 1 : 3,
                  labelColor: Colors.grey.shade600,
                  valueColor: Colors.black87,
                  items: _orderDetailDescriptionItems(full, screenWidth: w),
                ),
                if (_orderHasEventDesign(full))
                  _buildEventDesignDetailSection(full),
                if (canEditSeating) ...[
                  const SizedBox(height: 16),
                  ProcessingSeatingSection(
                    order: full,
                    onSaved: _refreshOrders,
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        AntdCancelButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (canOpenSeatingEditor)
          AntdSecondaryButton(
            label: 'Edit seating assignment',
            icon: Icons.event_seat_outlined,
            onPressed: () => _showSeatingAssignmentEditor(full),
          ),
        if (canPostChanges)
          AntdPrimaryButton(
            label: 'Post changes to customer',
            onPressed: () async {
              await _postOrderChangesToCustomer(full);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        AntdPrimaryButton(
          label: 'OK',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _postOrderChangesToCustomer(EventOrderDto order) async {
    try {
      await EventsApi.instance.postOrderChanges(orderId: order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes posted to customer.'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      await _refreshOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markOrderForFinalPayment(EventOrderDto order) async {
    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Mark for final payment',
      maxWidth: 460,
      body: Text(
        'Move "${order.eventTitle.isEmpty ? order.customerName : order.eventTitle}" to For Full Payment?',
      ),
      actions: antdModalActions(
        context: context,
        cancelLabel: 'Cancel',
        okLabel: 'Mark for final payment',
        onCancel: () => Navigator.of(context).pop(false),
        onOk: () => Navigator.of(context).pop(true),
      ),
    );
    if (ok != true) return;
    try {
      await EventsApi.instance.acceptOrder(orderId: order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked for final payment.'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      await _refreshOrders();
      if (!mounted) return;
      _mutateTableState(() => _selectedStatus = EventStatus.forFullPayment);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark for final payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _dishCostForFinalize(EventOrderDto order) {
    final fromTheme = order.themeDesign.dishCost;
    if (fromTheme != null && fromTheme > 0) return fromTheme;
    final fromMenu = computeOrderTotalCost(order);
    if (fromMenu > 0) return fromMenu;
    return 0;
  }

  Map<String, dynamic> _finalizeInquiryPayload(
    EventOrderDto order,
    double laborCost,
    double travelCost,
    double totalCost,
    String action,
  ) {
    final serviceType =
        order.orderType == 'catering' ? 'catering' : 'catering+event';
    final date =
        order.scheduleSlots.isNotEmpty ? order.scheduleSlots.first.date : '';
    final time =
        order.scheduleSlots.isNotEmpty
            ? order.scheduleSlots.first.startTime
            : '';
    return _buildOnlineInquiryPayload(
      order,
      order.address,
      date,
      time,
      serviceType,
      'yes',
      const <String>[],
      null,
      laborCost,
      travelCost,
      totalCost,
      action,
    );
  }

  Widget _buildFinalizeCostSection({
    required EventOrderDto order,
    required TextEditingController laborController,
    required TextEditingController travelController,
  }) {
    double parseCost(TextEditingController c) =>
        double.tryParse(c.text.trim()) ?? 0.0;
    final dishCost = _dishCostForFinalize(order);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COST ESTIMATION',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildLabeledReadonlyCost('Dish cost (from menu)', dishCost),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: laborController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Labor cost',
                    prefixText: 'PHP ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: travelController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Travel cost',
                    prefixText: 'PHP ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: Listenable.merge([laborController, travelController]),
            builder: (context, _) {
              final laborCost = parseCost(laborController);
              final travelCost = parseCost(travelController);
              final totalCost = dishCost + laborCost + travelCost;
              return _buildLabeledReadonlyCost(
                'Total estimated cost',
                totalCost,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Post changes sends the updated estimate to the customer without moving the inquiry.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFinalizeInquiryAction({
    required BuildContext dialogContext,
    required EventOrderDto order,
    required TextEditingController laborController,
    required TextEditingController travelController,
    required String action,
    required String successMessage,
  }) async {
    final laborCost = double.tryParse(laborController.text.trim()) ?? 0.0;
    final travelCost = double.tryParse(travelController.text.trim()) ?? 0.0;
    final dishCost = _dishCostForFinalize(order);
    final totalCost = dishCost + laborCost + travelCost;
    final payload = _finalizeInquiryPayload(
      order,
      laborCost,
      travelCost,
      totalCost,
      action,
    );
    await EventsApi.instance.managerFinalizeOnlineInquiry(
      orderId: order.id,
      payload: payload,
    );
    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    await _refreshOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _openFinalizeOnlineInquiryDialog(EventOrderDto order) async {
    final laborCostController = TextEditingController(
      text: (order.themeDesign.laborCost ?? 0).toStringAsFixed(2),
    );
    final travelCostController = TextEditingController(
      text: (order.themeDesign.travelCost ?? 0).toStringAsFixed(2),
    );
    final detailFuture = _loadOrderForDetail(order);

    try {
      await showAntdModal<void>(
        context: context,
        title: order.eventTitle.isEmpty ? order.customerName : order.eventTitle,
        maxWidth: 800,
        barrierDismissible: false,
        body: FutureBuilder<EventOrderDto>(
          future: detailFuture,
          builder: (dialogContext, snap) {
            final full = snap.data ?? order;
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final w = MediaQuery.sizeOf(dialogContext).width;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AntdDescriptions(
                  column: w < 700 ? 1 : 3,
                  labelColor: Colors.grey.shade600,
                  valueColor: Colors.black87,
                  items: _orderDetailDescriptionItems(full, screenWidth: w),
                ),
                if (_orderHasEventDesign(full))
                  _buildEventDesignDetailSection(full),
                _buildFinalizeCostSection(
                  order: full,
                  laborController: laborCostController,
                  travelController: travelCostController,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    AntdCancelButton(
                      label: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await _submitFinalizeInquiryAction(
                            dialogContext: dialogContext,
                            order: full,
                            laborController: laborCostController,
                            travelController: travelCostController,
                            action: 'post_changes',
                            successMessage:
                                'Changes posted. Customer can review updates in My Caterings.',
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Failed to post changes: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4511E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Post changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await _submitFinalizeInquiryAction(
                            dialogContext: dialogContext,
                            order: full,
                            laborController: laborCostController,
                            travelController: travelCostController,
                            action: 'confirm_inquiry',
                            successMessage:
                                'Order accepted and moved to For down payment.',
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Failed to accept order: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Accept order',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await _submitFinalizeInquiryAction(
                            dialogContext: dialogContext,
                            order: full,
                            laborController: laborCostController,
                            travelController: travelCostController,
                            action: 'cancel_event',
                            successMessage: 'Inquiry cancelled.',
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Failed to cancel: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFFFC107)),
                        backgroundColor: const Color(0xFFFFC107),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Cancel order'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    } finally {
      laborCostController.dispose();
      travelCostController.dispose();
    }
  }

  Future<void> _showConfirmDownpaymentDialog(EventOrderDto order) async {
    await _showDownpaymentConfirmationDialog(order);
  }

  Future<void> _selectManageEventsOrder(EventOrderDto dto) async {
    setState(() {
      _manageEventsDetailLoading = true;
      _manageEventsDetailError = null;
      _selectedManageEventsOrder = dto;
    });
    try {
      final orderKind = dto.orderKind.isNotEmpty
          ? dto.orderKind
          : (dto.orderType == 'catering' ? 'catering' : 'event');
      final raw = await ManagerCateringApi.instance.getItem(
        id: dto.id,
        orderKind: orderKind,
      );
      if (!mounted) return;
      setState(() {
        _selectedManageEventsOrder = EventsApi.instance.parseOrder(raw);
        _manageEventsDetailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manageEventsDetailLoading = false;
        _manageEventsDetailError = '$e';
      });
    }
  }

  Widget _mergedInquiryColumnCell(EventOrderDto dto) {
    final eventType =
        dto.eventType.trim().isEmpty ? '—' : dto.eventType.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eventType,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(dto.customerName, style: const TextStyle(fontSize: 12)),
        if (dto.contactPerson.trim().isNotEmpty &&
            dto.contactPerson.trim() != dto.customerName.trim())
          Text(dto.contactPerson, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        Text(
          _formatInquiryDateTime(dto),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildOrdersTablePanel({
    required String title,
    required List<EventOrderDto> orders,
    required String emptyMessage,
    List<Widget> Function(EventOrderDto dto)? actionCells,
    bool showGuestsAndTotal = true,
  }) {
    final filtered = _filterEventOrdersByTableFilters(orders);
    return _buildManageEventsSplitShell(
      title: title,
      emptyMessage: emptyMessage,
      filters: [_buildEventTableFilters(orders)],
      columns: [
        const DataColumn(label: Text('Service type')),
        const DataColumn(label: Text('Event / inquiry')),
        if (showGuestsAndTotal) const DataColumn(label: Text('Guests')),
        if (showGuestsAndTotal) const DataColumn(label: Text('Total')),
      ],
      rows: filtered.map((dto) {
        final selected = _selectedManageEventsOrder?.id == dto.id;
        return DataRow(
          selected: selected,
          onSelectChanged: (_) => _selectManageEventsOrder(dto),
          cells: [
            DataCell(Text(_orderTypeColumnLabel(dto))),
            DataCell(_mergedInquiryColumnCell(dto)),
            if (showGuestsAndTotal) DataCell(Text('${dto.guestCount}')),
            if (showGuestsAndTotal)
              DataCell(
                Text(
                  formatPesos(
                    dto.totalCost > 0
                        ? dto.totalCost
                        : computeOrderTotalCost(dto),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildManageEventsSplitShell({
    required String title,
    required String emptyMessage,
    required List<Widget> filters,
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height - 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _ordersLoading ? null : _refreshOrdersFromButton,
                          icon: _ordersLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          emptyMessage,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      Expanded(
                        child: PagedDataTable(
                          title: title,
                          fullWidth: true,
                          filters: filters,
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: columns,
                          rows: rows,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: _buildManageEventsDetailPanel(),
          ),
        ],
      ),
    );
  }

  String _formatInquiryDateTime(EventOrderDto dto) {
    final value = dto.updatedAt;
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  bool _matchesInquiryDateFilter(EventOrderDto dto) {
    if (_inquiryDateFilter.isEmpty) return true;
    final value = dto.updatedAt?.toLocal();
    if (value == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_inquiryDateFilter == 'today') return !value.isBefore(today);
    if (_inquiryDateFilter == '7d') {
      return !value.isBefore(now.subtract(const Duration(days: 7)));
    }
    if (_inquiryDateFilter == '30d') {
      return !value.isBefore(now.subtract(const Duration(days: 30)));
    }
    return true;
  }

  bool _matchesEventTableDateFilter(EventOrderDto dto) {
    if (_eventTableDateFilter.isEmpty) return true;
    if (dto.scheduleSlots.isEmpty) return false;
    final value = _tryParseDate(dto.scheduleSlots.first.date);
    if (value == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_eventTableDateFilter == 'today') {
      final day = DateTime(value.year, value.month, value.day);
      return day == today;
    }
    if (_eventTableDateFilter == '7d') {
      return !value.isBefore(now.subtract(const Duration(days: 7)));
    }
    if (_eventTableDateFilter == '30d') {
      return !value.isBefore(now.subtract(const Duration(days: 30)));
    }
    return true;
  }

  List<EventOrderDto> _filterEventOrdersByTableFilters(
    List<EventOrderDto> orders,
  ) {
    return orders.where((o) {
      if (_eventTableServiceTypeFilter.isNotEmpty &&
          _orderTypeColumnLabel(o) != _eventTableServiceTypeFilter) {
        return false;
      }
      if (_eventTableEventTypeFilter.isNotEmpty &&
          o.eventType != _eventTableEventTypeFilter) {
        return false;
      }
      return _matchesEventTableDateFilter(o);
    }).toList();
  }

  Widget _buildEventTableFilters(List<EventOrderDto> sourceOrders) {
    final serviceTypes =
        {
            for (final o in sourceOrders) _orderTypeColumnLabel(o).trim(),
          }.where((v) => v.isNotEmpty).toList()
          ..sort();
    final eventTypes =
        {
            for (final o in sourceOrders)
              if (o.eventType.trim().isNotEmpty) o.eventType.trim(),
          }.toList()
          ..sort();

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _eventTableServiceTypeFilter,
            decoration: const InputDecoration(
              labelText: 'Service type',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All services')),
              ...serviceTypes.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged:
                (value) => _mutateTableState(
                  () => _eventTableServiceTypeFilter = value ?? '',
                ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _eventTableEventTypeFilter,
            decoration: const InputDecoration(
              labelText: 'Event type',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All events')),
              ...eventTypes.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged:
                (value) => _mutateTableState(
                  () => _eventTableEventTypeFilter = value ?? '',
                ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _eventTableDateFilter,
            decoration: const InputDecoration(
              labelText: 'Event datetime',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All dates')),
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
            ],
            onChanged:
                (value) => _mutateTableState(
                  () => _eventTableDateFilter = value ?? '',
                ),
          ),
        ),
        if (_eventTableServiceTypeFilter.isNotEmpty ||
            _eventTableEventTypeFilter.isNotEmpty ||
            _eventTableDateFilter.isNotEmpty)
          TextButton.icon(
            onPressed:
                () => _mutateTableState(() {
                  _eventTableServiceTypeFilter = '';
                  _eventTableEventTypeFilter = '';
                  _eventTableDateFilter = '';
                }),
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Clear filters'),
          ),
      ],
    );
  }

  Widget _buildOnlineInquiryTableFilters(
    List<String> serviceTypes,
    List<String> eventTypes,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _inquiryServiceTypeFilter,
            decoration: const InputDecoration(
              labelText: 'Service type',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('All service types'),
              ),
              ...serviceTypes.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged:
                (value) => _mutateTableState(
                  () => _inquiryServiceTypeFilter = value ?? '',
                ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _inquiryEventTypeFilter,
            decoration: const InputDecoration(
              labelText: 'Event type',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All event types')),
              ...eventTypes.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged:
                (value) => _mutateTableState(
                  () => _inquiryEventTypeFilter = value ?? '',
                ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: _inquiryDateFilter,
            decoration: const InputDecoration(
              labelText: 'Inquiry datetime',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All dates')),
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
            ],
            onChanged:
                (value) =>
                    _mutateTableState(() => _inquiryDateFilter = value ?? ''),
          ),
        ),
        if (_inquiryServiceTypeFilter.isNotEmpty ||
            _inquiryEventTypeFilter.isNotEmpty ||
            _inquiryDateFilter.isNotEmpty)
          TextButton.icon(
            onPressed:
                () => _mutateTableState(() {
                  _inquiryServiceTypeFilter = '';
                  _inquiryEventTypeFilter = '';
                  _inquiryDateFilter = '';
                }),
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Clear filters'),
          ),
      ],
    );
  }

  Widget _buildOnlineInquiriesTableView(bool isNarrow) {
    final serviceTypes =
        {for (final o in _onlineInquiryOrders) _orderTypeColumnLabel(o).trim()}
            .where((v) => v.isNotEmpty)
            .toList()
          ..sort();
    final eventTypes =
        {
            for (final o in _onlineInquiryOrders)
              if (o.eventType.trim().isNotEmpty) o.eventType.trim(),
          }.toList()
          ..sort();
    final filtered =
        _onlineInquiryOrders.where((o) {
          if (_inquiryServiceTypeFilter.isNotEmpty &&
              _orderTypeColumnLabel(o) != _inquiryServiceTypeFilter) {
            return false;
          }
          if (_inquiryEventTypeFilter.isNotEmpty &&
              o.eventType != _inquiryEventTypeFilter) {
            return false;
          }
          if (!_matchesInquiryDateFilter(o)) return false;
          return true;
        }).toList();

    return _buildManageEventsSplitShell(
      title: 'Online inquiries',
      emptyMessage: 'No online inquiries to show yet.',
      filters: [_buildOnlineInquiryTableFilters(serviceTypes, eventTypes)],
      columns: const [
        DataColumn(label: Text('Service type')),
        DataColumn(label: Text('Event / inquiry')),
      ],
      rows: filtered.map((dto) {
        final selected = _selectedManageEventsOrder?.id == dto.id;
        return DataRow(
          selected: selected,
          onSelectChanged: (_) => _selectManageEventsOrder(dto),
          cells: [
            DataCell(Text(_orderTypeColumnLabel(dto))),
            DataCell(_mergedInquiryColumnCell(dto)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildForDownpaymentTableView(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: 'For downpayment',
      orders: _downpaymentOrders,
      emptyMessage: 'No confirmed orders awaiting downpayment.',
    );
  }

  Widget _buildOngoingTableView(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: 'Ongoing',
      orders: _ongoingOrders,
      emptyMessage: 'No ongoing events.',
    );
  }

  Widget _buildForFullPaymentTableView(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: 'For full payment',
      orders: _postAnalysisOrdersDto,
      emptyMessage: 'No orders awaiting full payment.',
    );
  }

  Future<void> _openFullPaymentCompleteModal(EventOrderDto dto) async {
    _syncPostAnalysisFields(dto);
    await showAntdModal<void>(
      context: context,
      title: 'For full payment — ${dto.eventTitle}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _postCardsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Business cards given away',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postInquiriesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'On-the-spot inquiries',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AntdPrimaryButton(
          label: 'Complete',
          loading: _postAnalysisSaving,
          onPressed: () async {
            _mutateTableState(() => _postAnalysisSaving = true);
            try {
              await EventsApi.instance.completePostAnalysis(
                orderId: dto.id,
                businessCardsGivenAway:
                    int.tryParse(_postCardsController.text.trim()) ?? 0,
                onTheSpotInquiries:
                    int.tryParse(_postInquiriesController.text.trim()) ?? 0,
                complaints: 0,
              );
              if (!mounted) return;
              Navigator.of(context).pop();
              await _refreshOrders();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event completed and moved to Completed.'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            } finally {
              if (mounted) _mutateTableState(() => _postAnalysisSaving = false);
            }
          },
        ),
      ],
    );
  }
}
