part of 'catering.dart';

extension _ManageEventsTableExt on _ManageEventsState {
  void _openZoomableImageDialog(Widget image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(child: image),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomableThemeImage(Widget thumbnail, Widget zoomChild) {
    return GestureDetector(
      onTap: () => _openZoomableImageDialog(zoomChild),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: thumbnail,
      ),
    );
  }

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
    final end = s.endTime.trim();
    if (end.isEmpty) return '${s.date} ${s.startTime}';
    return '${s.date} ${s.startTime}–$end';
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
      if (m.additionalChargeAmount > 0) {
        parts.add('+${formatPesos(m.additionalChargeAmount)} add-on');
      }
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

  Widget _buildEventDesignDetailSection(EventOrderDto dto, {bool readOnly = true}) {
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

    // Supervisor: final design output only (no step/edit UI).
    if (_isSupervisor) {
      return _detailSection(
        'Event theme design',
        child: imageUrl.isNotEmpty
            ? _zoomableThemeImage(
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: imageFromSource(imageUrl, fit: BoxFit.contain),
                  ),
                ),
                imageFromSource(imageUrl, fit: BoxFit.contain),
              )
            : Text(
                picks.isNotEmpty
                    ? 'Design output not ready yet.'
                    : 'No design image submitted.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
      );
    }

    Widget stepBlock(String title, Widget child) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVENT THEME DESIGN (CUSTOMER)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 10),
          stepBlock(
            'Step 1 - Reference & preview',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty) ...[
                  const Text(
                    'AI-generated design',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _zoomableThemeImage(
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 170,
                        width: double.infinity,
                        child: imageFromSource(imageUrl, fit: BoxFit.contain),
                      ),
                    ),
                    imageFromSource(imageUrl, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                ],
                if (picks.isNotEmpty) ...[
                  Text(
                    'Reference photos (${picks.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: picks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return _zoomableThemeImage(
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 90,
                              child: imageFromSource(picks[index]),
                            ),
                          ),
                          imageFromSource(picks[index], fit: BoxFit.contain),
                        );
                      },
                    ),
                  ),
                ],
                if (imageUrl.isEmpty && picks.isEmpty)
                  const Text(
                    'No design image / reference photos submitted.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          stepBlock(
            'Step 2 - Style notes',
            Text(
              _themeExtrasLine(dto),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
          const SizedBox(height: 10),
          stepBlock(
            'Step 3 - Action',
            !readOnly
                ? OutlinedButton.icon(
                    onPressed: () => _openThemeDesignEditor(dto),
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('Edit event theme design'),
                  )
                : const Text(
                    'Theme design is read-only in this stage.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
          ),
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
      if (!_isSupervisor)
        AntdDescriptionItem(label: 'Customer', value: dto.customerName),
      if (!_isSupervisor) ...[
        AntdDescriptionItem(label: 'Contact person', value: dto.contactPerson),
        AntdDescriptionItem(label: 'Phone', value: dto.contactNumber),
        AntdDescriptionItem(
          label: 'Email',
          value: dto.emailAddress,
          span: cols >= 2 ? 2 : 1,
        ),
      ],
      if (!_isSupervisor)
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
        onValueTap: dto.address.trim().isEmpty
            ? null
            : () => showVenueMapDialog(context, dto.address),
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
      if (!_isSupervisor) ...[
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
      ],
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
            'Seating assignment is only available for catering + event orders.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_canManageSeatingAssignmentsForStatus(full.status)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seating assignment can only be edited while the order is On Going.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    await showAntdModal<void>(
      context: context,
      title: 'Seating assignment — ${full.eventTitle.isEmpty ? full.transactionNo : full.eventTitle}',
      maxWidth: 980,
      body: SingleChildScrollView(
        child: ProcessingSeatingSection(
          order: full,
          onSaved: () async {
            await _refreshOrders();
            if (!mounted) return;
            await _selectManageEventsOrder(full);
          },
        ),
      ),
      actions: [
        AntdCancelButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
    if (!mounted) return;
    await _selectManageEventsOrder(full);
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

  double _dishCostForFinalize(
    int guests, {
    List<Map<String, dynamic>>? menuOverride,
  }) {
    if (menuOverride != null && menuOverride.isNotEmpty) {
      return menuOverride.fold<double>(
        0.0,
        (sum, row) => sum + (double.tryParse('${row['price']}') ?? 0.0),
      );
    }
    return estimateInquiryCateringTotal(guests);
  }

  Map<String, dynamic> _finalizeInquiryPayload(
    EventOrderDto order, {
    required double laborCost,
    required double travelCost,
    required List<Map<String, dynamic>> additionalCosts,
    required double totalCost,
    required String action,
    required String address,
    required String date,
    required String time,
    String? eventTitleOverride,
    String? eventTypeOverride,
    String? formalityLevelOverride,
    int? guestCountOverride,
    List<Map<String, dynamic>>? menuOverride,
    String? allergensOverride,
    String? customerNameOverride,
    String? contactPersonOverride,
    String? contactNumberOverride,
    String? emailAddressOverride,
    String? endTimeOverride,
    String? noteOverride,
  }) {
    final serviceType =
        order.orderType == 'catering' ? 'catering' : 'catering+event';
    return _buildOnlineInquiryPayload(
      order,
      address,
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
      eventTitleOverride: eventTitleOverride,
      eventTypeOverride: eventTypeOverride,
      formalityLevelOverride: formalityLevelOverride,
      guestCountOverride: guestCountOverride,
      additionalCosts: additionalCosts,
      menuOverride: menuOverride,
      allergensOverride: allergensOverride,
      customerNameOverride: customerNameOverride,
      contactPersonOverride: contactPersonOverride,
      contactNumberOverride: contactNumberOverride,
      emailAddressOverride: emailAddressOverride,
      endTimeOverride: endTimeOverride,
      noteOverride: noteOverride,
    );
  }

  Widget _buildFinalizeCostSection({
    required EventOrderDto order,
    required TextEditingController laborController,
    required TextEditingController travelController,
  }) {
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
          // Dish cost is already shown in the Pax & venue section.
          // This section is focused on labor + travel inputs.
          const SizedBox(height: 4),
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
          // Total cost is shown as a sticky footer (real-time updated).
        ],
      ),
    );
  }

  Future<void> _submitFinalizeInquiryAction({
    required BuildContext dialogContext,
    required EventOrderDto order,
    required TextEditingController laborController,
    required TextEditingController travelController,
    required String address,
    required String date,
    required String time,
    String? eventTitle,
    String? eventType,
    String? formalityLevel,
    int? guestCount,
    required List<Map<String, dynamic>> additionalCosts,
    required String action,
    required String successMessage,
    List<Map<String, dynamic>>? menuOverride,
    String? allergensOverride,
    String? customerName,
    String? contactPerson,
    String? contactNumber,
    String? emailAddress,
    String? endTime,
    String? note,
  }) async {
    if (!_isManager) return;
    final laborCost = double.tryParse(laborController.text.trim()) ?? 0.0;
    final travelCost = double.tryParse(travelController.text.trim()) ?? 0.0;
    final guests = guestCount ?? order.guestCount;
    final dishCost = _dishCostForFinalize(guests, menuOverride: menuOverride);
    final additionalCostsTotal = additionalCosts.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse('${e['amount'] ?? e['cost'] ?? 0}') ?? 0),
    );
    final totalCost = dishCost + laborCost + travelCost + additionalCostsTotal;
    final payload = _finalizeInquiryPayload(
      order,
      laborCost: laborCost,
      travelCost: travelCost,
      additionalCosts: additionalCosts,
      totalCost: totalCost,
      action: action,
      address: address,
      date: date,
      time: time,
      eventTitleOverride: eventTitle,
      eventTypeOverride: eventType,
      formalityLevelOverride: formalityLevel,
      guestCountOverride: guestCount,
      menuOverride: menuOverride,
      allergensOverride: allergensOverride,
      customerNameOverride: customerName,
      contactPersonOverride: contactPerson,
      contactNumberOverride: contactNumber,
      emailAddressOverride: emailAddress,
      endTimeOverride: endTime,
      noteOverride: note,
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

  Future<void> _openFinalizeOnlineInquiryDialog(
    EventOrderDto order, {
    int initialTabIndex = 0,
  }) async {
    final laborCostController = TextEditingController(
      text: (order.themeDesign.laborCost ?? 0).toStringAsFixed(2),
    );
    final travelCostController = TextEditingController(
      text: (order.themeDesign.travelCost ?? 0).toStringAsFixed(2),
    );
    final slot = order.scheduleSlots.isNotEmpty ? order.scheduleSlots.first : null;
    final eventTitleController = TextEditingController(text: order.eventTitle);
    final eventTypeController = TextEditingController(text: order.eventType);
    final formalityController = TextEditingController(text: order.formalityLevel);
    final guestCountController = TextEditingController(text: order.guestCount.toString());
    final addressController = TextEditingController(text: order.address);
    final dateController = TextEditingController(text: slot?.date ?? '');
    final timeController = TextEditingController(text: slot?.startTime ?? '');
    final endTimeController = TextEditingController(text: slot?.endTime ?? '');
    final customerNameController = TextEditingController(text: order.customerName);
    final contactPersonController = TextEditingController(text: order.contactPerson);
    final contactNumberController = TextEditingController(text: order.contactNumber);
    final emailController = TextEditingController(text: order.emailAddress);
    final noteController = TextEditingController(
      text: (order.themeDesign.customerNote ??
              order.themeDesign.customInstructions ??
              '')
          .toString(),
    );
    final additionalCostLabelController = TextEditingController();
    final additionalCostAmountController = TextEditingController();
    final additionalCosts = List<Map<String, dynamic>>.from(
      _additionalCostGroupsFromOrder(order).expand((g) {
        final items = g['items'];
        if (items is! List) return const <Map<String, dynamic>>[];
        return items.whereType<Map>().map((e) {
          final label = '${e['label'] ?? e['name'] ?? 'Item'}'.trim();
          final amount = double.tryParse('${e['amount'] ?? e['cost'] ?? 0}') ?? 0;
          return {'label': label, 'amount': amount};
        });
      }),
    );
    final detailFuture = _loadOrderForDetail(order);
    var inquiryMenuBlocks = <Map<String, dynamic>>[];
    var inquiryChargeOverrides = <String, double>{};
    var inquiryAllergens = order.allergens;
    var inquiryMenuTabIndex = 0;

    List<Map<String, dynamic>>? inquiryMenuPayloadForSave() {
      if (inquiryMenuBlocks.isEmpty) return null;
      final guests =
          int.tryParse(guestCountController.text.trim()) ?? order.guestCount;
      return _menuPayloadFromInquiryBlocks(
        inquiryMenuBlocks,
        inquiryChargeOverrides,
        guests,
      );
    }

    try {
      unawaited(MenuStore.instance.ensureImagesLoaded());
      unawaited(SetMenuStore.instance.loadSetMenus());
      await showAntdModal<void>(
        context: context,
        title: order.eventTitle.isEmpty ? order.customerName : order.eventTitle,
        maxWidth: 1080,
        barrierDismissible: false,
        actions: [
          Builder(
            builder: (footerContext) {
              Future<void> runFinalizeAction({
                required String action,
                required String successMessage,
              }) async {
                try {
                  await _submitFinalizeInquiryAction(
                    dialogContext: footerContext,
                    order: order,
                    laborController: laborCostController,
                    travelController: travelCostController,
                    address: addressController.text.trim(),
                    date: dateController.text.trim(),
                    time: timeController.text.trim(),
                    endTime: endTimeController.text.trim(),
                    eventTitle: eventTitleController.text.trim(),
                    eventType: eventTypeController.text.trim(),
                    formalityLevel: formalityController.text.trim(),
                    guestCount: int.tryParse(guestCountController.text.trim()),
                    customerName: customerNameController.text.trim(),
                    contactPerson: contactPersonController.text.trim(),
                    contactNumber: contactNumberController.text.trim(),
                    emailAddress: emailController.text.trim(),
                    note: noteController.text.trim(),
                    additionalCosts: additionalCosts,
                    action: action,
                    successMessage: successMessage,
                    menuOverride: inquiryMenuPayloadForSave(),
                    allergensOverride: inquiryAllergens,
                  );
                } catch (e) {
                  if (!footerContext.mounted) return;
                  ScaffoldMessenger.of(footerContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              return SizedBox(
                width: 680,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        laborCostController,
                        travelCostController,
                        additionalCostAmountController,
                        guestCountController,
                      ]),
                      builder: (context, _) {
                        final guests =
                            int.tryParse(guestCountController.text.trim()) ??
                            order.guestCount;
                        final menuOverride = inquiryMenuPayloadForSave();
                        final dishCost = _dishCostForFinalize(
                          guests,
                          menuOverride: menuOverride,
                        );
                        final laborCost =
                            double.tryParse(laborCostController.text.trim()) ??
                            0.0;
                        final travelCost =
                            double.tryParse(travelCostController.text.trim()) ??
                            0.0;
                        final additionalCostsTotal = additionalCosts.fold<double>(
                          0,
                          (sum, e) =>
                              sum +
                              (double.tryParse('${e['amount'] ?? 0}') ?? 0),
                        );
                        final totalCost =
                            dishCost +
                            laborCost +
                            travelCost +
                            additionalCostsTotal;
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total Cost: PHP ${totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        AntdCancelButton(
                          label: 'Close',
                          onPressed: () => Navigator.of(footerContext).pop(),
                        ),
                        if (_isManager) ...[
                          ElevatedButton(
                            onPressed: () => runFinalizeAction(
                              action: 'post_changes',
                              successMessage:
                                  'Changes saved. Customer can review updates in My Caterings.',
                            ),
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
                            onPressed: () => runFinalizeAction(
                              action: 'confirm_inquiry',
                              successMessage:
                                  'Order moved to For down payment.',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Move to Down Payment',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => runFinalizeAction(
                              action: 'cancel_event',
                              successMessage: 'Inquiry cancelled.',
                            ),
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
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        body: FutureBuilder<EventOrderDto>(
          future: detailFuture,
          builder: (dialogContext, snap) {
            final full = snap.data ?? order;
            if (inquiryMenuBlocks.isEmpty && full.menu.isNotEmpty) {
              inquiryMenuBlocks = _inquiryMenuBlocksFromOrder(full);
            }
            if (inquiryAllergens.isEmpty && full.allergens.isNotEmpty) {
              inquiryAllergens = full.allergens;
            }
            if (noteController.text.trim().isEmpty) {
              final noteFromTheme =
                  (full.themeDesign.customerNote ??
                          full.themeDesign.customInstructions ??
                          '')
                      .trim();
              if (noteFromTheme.isNotEmpty) {
                noteController.text = noteFromTheme;
              }
            }
            if (customerNameController.text.trim().isEmpty &&
                full.customerName.trim().isNotEmpty) {
              customerNameController.text = full.customerName;
            }
            if (contactPersonController.text.trim().isEmpty &&
                full.contactPerson.trim().isNotEmpty) {
              contactPersonController.text = full.contactPerson;
            }
            if (contactNumberController.text.trim().isEmpty &&
                full.contactNumber.trim().isNotEmpty) {
              contactNumberController.text = full.contactNumber;
            }
            if (emailController.text.trim().isEmpty &&
                full.emailAddress.trim().isNotEmpty) {
              emailController.text = full.emailAddress;
            }
            if (endTimeController.text.trim().isEmpty &&
                full.scheduleSlots.isNotEmpty &&
                full.scheduleSlots.first.endTime.trim().isNotEmpty) {
              endTimeController.text = full.scheduleSlots.first.endTime;
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            Widget eventInfoTab() {
              final guestsForUi =
                  int.tryParse(guestCountController.text.trim()) ??
                  full.guestCount;
              final dishCostLive = estimateInquiryCateringTotal(guestsForUi);
              final withinTaguigLive =
                  addressController.text.toLowerCase().contains('taguig');
              return SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Event information',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactPersonController,
                        decoration: const InputDecoration(
                          labelText: 'Contact person',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: contactNumberController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact number',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: eventTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Event title',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: eventTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Event type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<EventFormalityLevel>(
                        value: _formalityFromString(formalityController.text),
                        items: EventFormalityLevel.values
                            .map(
                              (level) => DropdownMenuItem(
                                value: level,
                                child: Text(level.displayName),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Formality level',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          formalityController.text = _formalityToString(value);
                          _mutateTableState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: guestCountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: false),
                        onChanged: (_) => _mutateTableState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Guest count (pax)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: addressController,
                              onChanged: (_) => _mutateTableState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Venue address',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Pick on map',
                            onPressed: () async {
                              final picked = await showMapPicker(
                                context: context,
                                initialAddress:
                                    addressController.text.trim().isEmpty
                                        ? null
                                        : addressController.text.trim(),
                              );
                              if (picked == null) return;
                              addressController.text = picked.address;
                              _mutateTableState(() {});
                            },
                            icon: const Icon(
                              Icons.place_outlined,
                              color: Color(0xFFFFC024),
                            ),
                          ),
                          IconButton(
                            tooltip: 'View on map',
                            onPressed: () => showVenueMapDialog(
                              context,
                              addressController.text,
                            ),
                            icon: const Icon(
                              Icons.map_outlined,
                              color: Color(0xFFFFC024),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: withinTaguigLive
                                      ? Colors.green.shade50
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: withinTaguigLive
                                        ? Colors.green.shade300
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  withinTaguigLive
                                      ? 'Within Taguig'
                                      : 'Outside Taguig',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: withinTaguigLive
                                        ? Colors.green.shade900
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Catering base: ${formatPesos(dishCostLive)} (₱${kCateringInquiryPricePerGuest.toStringAsFixed(0)} × pax)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: now.subtract(const Duration(days: 365)),
                              lastDate: now.add(const Duration(days: 365 * 2)),
                            );
                            if (pickedDate == null || !mounted) return;
                            final start = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 10, minute: 0),
                            );
                            if (start == null || !mounted) return;
                            final end = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: (start.hour + 2).clamp(0, 23),
                                minute: start.minute,
                              ),
                            );
                            if (end == null || !mounted) return;
                            String pad2(int n) => n.toString().padLeft(2, '0');
                            dateController.text =
                                '${pickedDate.year}-${pad2(pickedDate.month)}-${pad2(pickedDate.day)}';
                            timeController.text =
                                '${pad2(start.hour)}:${pad2(start.minute)}';
                            endTimeController.text =
                                '${pad2(end.hour)}:${pad2(end.minute)}';
                            _mutateTableState(() {});
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add slot'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (dateController.text.trim().isEmpty)
                        Text(
                          'No schedules yet.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        )
                      else
                        InputChip(
                          label: Text(
                            '${dateController.text} '
                            '(${timeController.text}'
                            '${endTimeController.text.trim().isEmpty ? '' : ' – ${endTimeController.text}'})',
                          ),
                          onDeleted: () {
                            dateController.clear();
                            timeController.clear();
                            endTimeController.clear();
                            _mutateTableState(() {});
                          },
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget menuAllergensTab() {
              final chargeRows = _setMenuChargeRowsForBlocks(
                inquiryMenuBlocks,
                inquiryChargeOverrides,
              );
              final cateringDishes =
                  MenuStore.instance.allDishes
                      .where(
                        (d) =>
                            d.category.toLowerCase().trim() == 'catering' &&
                            !d.archived &&
                            d.available,
                      )
                      .toList();
              return DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TabBar(
                      labelColor: const Color(0xFF1E1E1E),
                      unselectedLabelColor: Colors.grey.shade700,
                      indicatorColor: const Color(0xFFFFC024),
                      tabs: const [
                        Tab(text: 'Allergens'),
                        Tab(text: 'Menu'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: AllergenSelectorField(
                                initialSerialized: inquiryAllergens,
                                onChanged: (v) =>
                                    _mutateTableState(() => inquiryAllergens = v),
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Menu',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Custom dishes'),
                                selected: inquiryMenuTabIndex == 0,
                                onSelected: (_) => _mutateTableState(
                                  () => inquiryMenuTabIndex = 0,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Set menu'),
                                selected: inquiryMenuTabIndex == 1,
                                onSelected: (_) async {
                                  _mutateTableState(
                                    () => inquiryMenuTabIndex = 1,
                                  );
                                  if (SetMenuStore
                                      .instance.activeSetMenus.isEmpty) {
                                    await SetMenuStore.instance.loadSetMenus();
                                  }
                                  await MenuStore.instance.ensureImagesLoaded();
                                  if (mounted) _mutateTableState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InquiryMenuPicker(
                            key: ValueKey<String>(
                              'oi-menu-$inquiryMenuTabIndex-${SetMenuStore.instance.activeSetMenus.length}',
                            ),
                            embedded: true,
                            tabIndex: inquiryMenuTabIndex,
                            cateringDishes: cateringDishes,
                            setMenus: SetMenuStore.instance.activeSetMenus,
                            initialSelections: inquiryMenuBlocks,
                            mode: InquiryMenuPickerMode.staffNewEvent,
                            minCustomDishes: 0,
                            maxCustomDishes: 999,
                            onSelectionChanged: (blocks) {
                              _mutateTableState(() {
                                inquiryMenuBlocks = blocks;
                                inquiryChargeOverrides.removeWhere((dishId, _) {
                                  return !blocks.any((b) {
                                    final ids =
                                        (b['dishIds'] as List<dynamic>? ?? const [])
                                            .map((e) => '$e')
                                            .toSet();
                                    return ids.contains(dishId);
                                  });
                                });
                              });
                            },
                          ),
                          if (chargeRows.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Menu modifications add\'l charges',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...chargeRows.map((row) {
                              final dishId = '${row['dishId']}';
                              final dishName = '${row['dishName']}';
                              final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dishName,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 140,
                                      child: TextFormField(
                                        initialValue: amount.toStringAsFixed(2),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Add\'l charge',
                                          prefixText: 'PHP ',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (v) {
                                          final parsed =
                                              double.tryParse(v.trim()) ?? 0;
                                          _mutateTableState(() {
                                            inquiryChargeOverrides[dishId] =
                                                parsed < 0 ? 0 : parsed;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget submitCostsTab() {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Additional costs',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: additionalCostLabelController,
                              decoration: const InputDecoration(
                                labelText: 'Label',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 130,
                            child: TextField(
                              controller: additionalCostAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixText: 'PHP ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add additional cost',
                            onPressed: () {
                              final label = additionalCostLabelController.text.trim();
                              final amount =
                                  double.tryParse(additionalCostAmountController.text.trim());
                              if (label.isEmpty || amount == null) return;
                              _mutateTableState(() {
                                additionalCosts.add({'label': label, 'amount': amount});
                              });
                              additionalCostLabelController.clear();
                              additionalCostAmountController.clear();
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      if (additionalCosts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...additionalCosts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${row['label']} — ${formatPesos(amount)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () => _mutateTableState(
                                  () => additionalCosts.removeAt(index),
                                ),
                                icon: const Icon(Icons.delete_outline, size: 18),
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                    if (_orderHasEventDesign(full) ||
                        full.orderType.toLowerCase().contains('event') ||
                        full.includeMinimalEventStyling)
                      _buildEventDesignDetailSection(full, readOnly: false),
                    _buildFinalizeCostSection(
                      order: full,
                      laborController: laborCostController,
                      travelController: travelCostController,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            }

            return SizedBox(
              height: MediaQuery.sizeOf(dialogContext).height * 0.62,
              child: DefaultTabController(
                length: 3,
                initialIndex: initialTabIndex.clamp(0, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.white,
                      child: TabBar(
                        labelColor: const Color(0xFF1E1E1E),
                        unselectedLabelColor: Colors.grey.shade700,
                        indicatorColor: const Color(0xFFFFC024),
                        tabs: const [
                          Tab(text: 'Event Information'),
                          Tab(text: 'Menu & Allergens'),
                          Tab(text: 'Submit & Costs'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          eventInfoTab(),
                          menuAllergensTab(),
                          submitCostsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      laborCostController.dispose();
      travelCostController.dispose();
      eventTitleController.dispose();
      eventTypeController.dispose();
      formalityController.dispose();
      guestCountController.dispose();
      addressController.dispose();
      dateController.dispose();
      timeController.dispose();
      endTimeController.dispose();
      customerNameController.dispose();
      contactPersonController.dispose();
      contactNumberController.dispose();
      emailController.dispose();
      noteController.dispose();
      additionalCostLabelController.dispose();
      additionalCostAmountController.dispose();
    }
  }

  Future<void> _showConfirmDownpaymentDialog(EventOrderDto order) async {
    await _showDownpaymentConfirmationDialog(order);
  }

  Future<void> _selectManageEventsOrder(EventOrderDto dto) async {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _manageEventsDetailLoading = true;
      _manageEventsDetailError = null;
      _selectedManageEventsOrder = dto;
    });
    try {
      final roleType =
          AuthSession.instance.currentRole == Role.supervisor
              ? 'supervisor'
              : 'manager';
      final raw = await EventsApi.instance.getEventOrder(
        orderId: dto.id,
        roleType: roleType,
      );
      if (!mounted) return;
      // ignore: invalid_use_of_protected_member
      setState(() {
        _selectedManageEventsOrder = raw;
        _manageEventsDetailLoading = false;
      });
      _startDetailLivePollIfNeeded();
    } catch (e) {
      if (!mounted) return;
      // ignore: invalid_use_of_protected_member
      setState(() {
        _manageEventsDetailLoading = false;
        _manageEventsDetailError = '$e';
      });
      _stopDetailLivePoll();
    }
  }

  Widget _eventInquiryColumnCell(EventOrderDto dto) {
    final eventType =
        dto.eventType.trim().isEmpty ? '—' : dto.eventType.trim();
    final title = dto.eventTitle.trim().isEmpty
        ? dto.customerName
        : dto.eventTitle.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text('Type: $eventType', style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _mergedInquiryColumnCell(EventOrderDto dto) {
    if (_isCateringPlusEventOrder(dto)) {
      return _eventInquiryColumnCell(dto);
    }
    final eventType =
        dto.eventType.trim().isEmpty ? '—' : dto.eventType.trim();
    final menuLine =
        dto.menu.isEmpty
            ? 'Menu: —'
            : 'Menu: ${dto.menu.take(2).map((m) => m.dishName).join(', ')}${dto.menu.length > 2 ? ' +${dto.menu.length - 2} more' : ''}';
    final allergensLine =
        dto.allergens.trim().isEmpty ? 'Allergens: —' : 'Allergens: ${dto.allergens.trim()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eventType,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'TXN: ${dto.transactionNo}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 2),
        Text(dto.customerName, style: const TextStyle(fontSize: 12)),
        if (dto.contactPerson.trim().isNotEmpty &&
            dto.contactPerson.trim() != dto.customerName.trim())
          Text(dto.contactPerson, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(menuLine, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        Text(allergensLine, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _basicInquiryColumnCell(EventOrderDto dto) => _eventInquiryColumnCell(dto);

  Widget _buildOrdersTablePanel({
    required String title,
    required List<EventOrderDto> orders,
    required String emptyMessage,
    List<Widget> Function(EventOrderDto dto)? actionCells,
    bool showGuestsAndTotal = true,
    bool showSchedule = false,
  }) {
    final filtered = _filterEventOrdersByTableFilters(orders);
    return _buildManageEventsSplitShell(
      title: title,
      emptyMessage: emptyMessage,
      filters: [_buildEventTableFilters(orders)],
      columns: [
        const DataColumn(label: Text('Service type')),
        const DataColumn(label: Text('Event / inquiry')),
        if (showSchedule) const DataColumn(label: Text('Schedule')),
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
            if (showSchedule) DataCell(Text(_formatOrderSchedule(dto))),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height - 220;
        return SizedBox(
      height: panelHeight,
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
                    if (title.trim().isNotEmpty) ...[
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
                    ],
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
                        child: LayoutBuilder(
                          builder: (context, tableConstraints) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: tableConstraints.maxWidth,
                                  maxHeight: tableConstraints.maxHeight,
                                ),
                                child: PagedDataTable(
                                  title: title.trim(),
                                  fullWidth: true,
                                  forceVerticalScroll: true,
                                  minTableWidth: 680,
                                  columnSpacing: 8,
                                  horizontalMargin: 6,
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 56,
                                  headingRowHeight: 40,
                                  maxTableHeight: tableConstraints.maxHeight,
                                  filters: filters,
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey.shade100,
                                  ),
                                  columns: columns,
                                  rows: rows,
                                ),
                              ),
                            );
                          },
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
      },
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
      title: '',
      emptyMessage: 'No online inquiries to show yet.',
      filters: [_buildOnlineInquiryTableFilters(serviceTypes, eventTypes)],
      columns: const [
        DataColumn(label: Text('Service type')),
        DataColumn(label: Text('Event / inquiry')),
        DataColumn(label: Text('Date and time')),
      ],
      rows: filtered.map((dto) {
        final selected = _selectedManageEventsOrder?.id == dto.id;
        return DataRow(
          selected: selected,
          onSelectChanged: (_) => _selectManageEventsOrder(dto),
          cells: [
            DataCell(Text(_orderTypeColumnLabel(dto))),
            DataCell(_basicInquiryColumnCell(dto)),
            DataCell(Text(_formatInquiryDateTime(dto))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildForDownpaymentTableView(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: '',
      orders: _downpaymentOrders,
      emptyMessage: 'No confirmed orders awaiting downpayment.',
    );
  }

  Widget _buildOngoingTableView(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: '',
      orders: _ongoingOrders,
      emptyMessage: 'No ongoing events.',
      showGuestsAndTotal: !_isSupervisor,
      showSchedule: true,
    );
  }

  Widget _buildForFullPaymentTableView(bool isNarrow) {
    return _buildOrdersTablePanel(
      title: '',
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
              await EventsApi.instance.completeOrder(
                orderId: dto.id,
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
