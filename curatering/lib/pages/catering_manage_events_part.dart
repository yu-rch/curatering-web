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
    return normalized == 'on_going' || normalized == 'ongoing';
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

  Future<void> _showEventOrderDetailModal(EventOrderDto dto) async {
    final w = MediaQuery.sizeOf(context).width;
    EventOrderDto full = dto;
    final role = AuthSession.instance.currentRole;
    final canPostChanges =
        _isOngoingStatus(dto.status) &&
        _isCateringPlusEventOrder(dto) &&
        (role == Role.manager ||
            role == Role.supervisor ||
            role == Role.superAdmin);
    await showAntdModal<void>(
      context: context,
      title: dto.eventTitle.isEmpty ? dto.customerName : dto.eventTitle,
      maxWidth: 800,
      body: FutureBuilder<EventOrderDto>(
        future: _loadOrderForDetail(dto),
        builder: (context, snap) {
          full = snap.data ?? dto;
          final role = AuthSession.instance.currentRole;
          final canEditSeating =
              _isOngoingStatus(full.status) &&
              _isCateringPlusEventOrder(full) &&
              (role == Role.manager ||
                  role == Role.supervisor ||
                  role == Role.superAdmin);
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
      setState(() => _selectedStatus = EventStatus.forFullPayment);
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

  Widget _buildOrdersTablePanel({
    required String title,
    required List<EventOrderDto> orders,
    required String emptyMessage,
    required List<Widget> Function(EventOrderDto dto) actionCells,
  }) {
    final filtered = _filterEventOrdersBySearch(orders);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  icon:
                      _ordersLoading
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
            TextField(
              controller: _eventSearchController,
              decoration: InputDecoration(
                hintText: 'Search orders',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => _mutateTableState(() {}),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              PagedDataTable(
                title: title,
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Service type')),
                  DataColumn(label: Text('Event / customer')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Guests')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Actions')),
                ],
                rows:
                    filtered.map((dto) {
                      final title =
                          dto.eventTitle.isEmpty
                              ? dto.customerName
                              : dto.eventTitle;
                      return DataRow(
                        cells: [
                          DataCell(Text(_orderTypeColumnLabel(dto))),
                          DataCell(
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(Text(dto.customerName)),
                          DataCell(Text(_formatOrderSchedule(dto))),
                          DataCell(Text('${dto.guestCount}')),
                          DataCell(
                            Text(
                              formatPesos(
                                dto.totalCost > 0
                                    ? dto.totalCost
                                    : computeOrderTotalCost(dto),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actionCells(dto),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
          ],
        ),
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

  Widget _buildOnlineInquiriesTableView(bool isNarrow) {
    final query = _eventSearchController.text.trim().toLowerCase();
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
          if (query.isEmpty) return true;
          return [
            o.customerName,
            o.contactPerson,
            o.contactNumber,
            o.emailAddress,
            o.eventType,
            o.eventTitle,
            o.orderType,
          ].any((v) => v.toLowerCase().contains(query));
        }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Online inquiries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _ordersLoading ? null : _refreshOrdersFromButton,
                  icon:
                      _ordersLoading
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
            Wrap(
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
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
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
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All event types'),
                      ),
                      ...eventTypes.map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
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
                      DropdownMenuItem(
                        value: '30d',
                        child: Text('Last 30 days'),
                      ),
                    ],
                    onChanged:
                        (value) => _mutateTableState(
                          () => _inquiryDateFilter = value ?? '',
                        ),
                  ),
                ),
                if (_inquiryServiceTypeFilter.isNotEmpty ||
                    _inquiryEventTypeFilter.isNotEmpty ||
                    _inquiryDateFilter.isNotEmpty ||
                    query.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed:
                            () => _mutateTableState(() {
                              _inquiryServiceTypeFilter = '';
                              _inquiryEventTypeFilter = '';
                              _inquiryDateFilter = '';
                              _eventSearchController.clear();
                            }),
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Clear filters'),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No online inquiries to show yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Expanded(
                child: PagedDataTable(
                  title: 'Online Inquiries',
                  fullWidth: true,
                  maxTableHeight: MediaQuery.sizeOf(context).height,
                  headingRowColor: WidgetStateProperty.all(
                    Colors.grey.shade100,
                  ),
                  columns: const [
                    DataColumn(label: Text('Service type')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Contact')),
                    DataColumn(label: Text('Event type')),
                    DataColumn(label: Text('Inquiry datetime')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      filtered.map((dto) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_orderTypeColumnLabel(dto))),
                            DataCell(Text(dto.customerName)),
                            DataCell(Text(dto.contactPerson)),
                            DataCell(
                              Text(dto.eventType.isEmpty ? '—' : dto.eventType),
                            ),
                            DataCell(Text(_formatInquiryDateTime(dto))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _eventIconAction(
                                    icon: Icons.visibility_outlined,
                                    tooltip: 'View details',
                                    permissionKey:
                                        ActionPermissionKeys
                                            .manageEventsViewDetails,
                                    onPressed: () async {
                                      try {
                                        final full =
                                            await _resolveOrderForSelection(
                                              dto,
                                            );
                                        if (!mounted) return;
                                        await _showEventOrderDetailModal(full);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not load inquiry: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  _eventIconAction(
                                    icon: Icons.check_circle_outline,
                                    tooltip: 'Finalize inquiry',
                                    permissionKey:
                                        ActionPermissionKeys
                                            .manageEventsFinalize,
                                    onPressed: () async {
                                      try {
                                        final full =
                                            await _resolveOrderForSelection(
                                              dto,
                                            );
                                        if (!mounted) return;
                                        await _openFinalizeOnlineInquiryDialog(
                                          full,
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not open finalize: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForDownpaymentTableView(bool isNarrow) {
    return SingleChildScrollView(
      child: _buildOrdersTablePanel(
        title: 'For downpayment',
        orders: _downpaymentOrders,
        emptyMessage: 'No confirmed orders awaiting downpayment.',
        actionCells:
            (dto) => [
              _eventIconAction(
                icon: Icons.visibility_outlined,
                tooltip: 'View details',
                permissionKey: ActionPermissionKeys.manageEventsViewDetails,
                onPressed: () => _showEventOrderDetailModal(dto),
              ),
              _eventIconAction(
                icon: Icons.payments_outlined,
                tooltip: 'Confirm downpayment',
                permissionKey:
                    ActionPermissionKeys.manageEventsConfirmDownpayment,
                onPressed: () => _showConfirmDownpaymentDialog(dto),
              ),
            ],
      ),
    );
  }

  Widget _buildOngoingTableView(bool isNarrow) {
    return SingleChildScrollView(
      child: _buildOrdersTablePanel(
        title: 'Ongoing',
        orders: _ongoingOrders,
        emptyMessage: 'No ongoing events.',
        actionCells:
            (dto) => [
              _eventIconAction(
                icon: Icons.visibility_outlined,
                tooltip: 'View details',
                permissionKey: ActionPermissionKeys.manageEventsViewDetails,
                onPressed: () => _showEventOrderDetailModal(dto),
              ),
              _eventIconAction(
                icon: Icons.checklist_rtl_outlined,
                tooltip: 'Checklist',
                permissionKey: ActionPermissionKeys.manageEventsChecklist,
                onPressed: () => _showChecklistDialog(dto),
              ),
              _eventIconAction(
                icon: Icons.payments_outlined,
                tooltip: 'Mark for final payment',
                permissionKey: ActionPermissionKeys.manageEventsFinalize,
                onPressed: () => _markOrderForFinalPayment(dto),
                color: Colors.indigo.shade700,
              ),
            ],
      ),
    );
  }

  Widget _buildForFullPaymentTableView(bool isNarrow) {
    return SingleChildScrollView(
      child: _buildOrdersTablePanel(
        title: 'For full payment',
        orders: _postAnalysisOrdersDto,
        emptyMessage: 'No orders awaiting full payment.',
        actionCells:
            (dto) => [
              _eventIconAction(
                icon: Icons.visibility_outlined,
                tooltip: 'View details',
                permissionKey: ActionPermissionKeys.manageEventsViewDetails,
                onPressed: () => _showEventOrderDetailModal(dto),
              ),
              _eventIconAction(
                icon: Icons.receipt_long_outlined,
                tooltip: 'Finalize payment',
                permissionKey: ActionPermissionKeys.manageEventsFinalize,
                onPressed: () => _showFinalizeFullPaymentDialog(dto),
              ),
              _eventIconAction(
                icon: Icons.task_alt_outlined,
                tooltip: 'Complete event',
                permissionKey: ActionPermissionKeys.manageEventsComplete,
                onPressed: () => _openFullPaymentCompleteModal(dto),
                color: Colors.green.shade700,
              ),
            ],
      ),
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
