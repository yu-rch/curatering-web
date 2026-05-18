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
  List<EventOrderDto> get _downpaymentOrders => _processingOrdersDto
      .where((o) => o.downPaymentStatus != 'paid')
      .toList();

  List<EventOrderDto> get _ongoingOrders => _processingOrdersDto
      .where((o) => o.downPaymentStatus == 'paid')
      .toList();

  String _formatOrderSchedule(EventOrderDto dto) {
    if (dto.scheduleSlots.isEmpty) return '—';
    final s = dto.scheduleSlots.first;
    return '${s.date} ${s.startTime}';
  }

  String _orderTypeColumnLabel(EventOrderDto dto) {
    return orderTypeDisplayLabel(
      dto.orderType,
      eventTitle: dto.eventTitle,
    );
  }

  String _formatMenuLines(EventOrderDto dto) {
    if (dto.menu.isEmpty) return '—';
    return dto.menu
        .map((m) => '${m.dishName} · ${m.paxOption} · ${m.price}')
        .join('\n');
  }

  String _themeExtrasLine(EventOrderDto dto) {
    final td = dto.themeDesign;
    final parts = <String>[];
    if (td.wantsCustomDesign) parts.add('Custom design requested');
    if (td.customerThemeRequest != null &&
        td.customerThemeRequest!.trim().isNotEmpty) {
      parts.add('Theme: ${td.customerThemeRequest}');
    }
    return parts.isEmpty ? '—' : parts.join('\n');
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
      AntdDescriptionItem(label: 'Event type', value: dto.eventType.isEmpty ? '—' : dto.eventType),
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
        value: dto.scheduleSlots.isEmpty
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
      AntdDescriptionItem(
        label: 'Total cost',
        value: formatPesos(total),
      ),
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
      return await _resolveOrderForSelection(dto);
    } catch (_) {
      return dto;
    }
  }

  Future<void> _showEventOrderDetailModal(EventOrderDto dto) async {
    final w = MediaQuery.sizeOf(context).width;
    EventOrderDto full = dto;
    await showAntdModal<void>(
      context: context,
      title: dto.eventTitle.isEmpty
          ? dto.customerName
          : dto.eventTitle,
      maxWidth: 800,
      body: FutureBuilder<EventOrderDto>(
        future: _loadOrderForDetail(dto),
        builder: (context, snap) {
          full = snap.data ?? dto;
          if (snap.connectionState == ConnectionState.waiting &&
              dto.menu.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return SingleChildScrollView(
            child: AntdDescriptions(
              column: w < 700 ? 1 : 3,
              labelColor: Colors.grey.shade600,
              valueColor: Colors.black87,
              items: _orderDetailDescriptionItems(full, screenWidth: w),
            ),
          );
        },
      ),
      actions: antdModalActions(
        context: context,
        cancelLabel: 'Close',
        okLabel: 'OK',
        onCancel: () => Navigator.of(context).pop(),
        onOk: () => Navigator.of(context).pop(),
      ),
    );
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Colors.grey.shade100,
                  ),
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineInquiriesTableView(bool isNarrow) {
    final query = _inquirySearchController.text.trim().toLowerCase();
    final filtered =
        _onlineInquiryOrders.where((o) {
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

    return SingleChildScrollView(
      child: Card(
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
              TextField(
                controller: _inquirySearchController,
                decoration: InputDecoration(
                  hintText: 'Search inquiries',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade100,
                    ),
                    columns: const [
                      DataColumn(label: Text('Service type')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Contact')),
                      DataColumn(label: Text('Event type')),
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
                                Text(
                                  dto.eventType.isEmpty ? '—' : dto.eventType,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _eventIconAction(
                                      icon: Icons.visibility_outlined,
                                      tooltip: 'View details',
                                      permissionKey:
                                          ActionPermissionKeys.manageEventsViewDetails,
                                      onPressed: () async {
                                        try {
                                          final full =
                                              await _resolveOrderForSelection(
                                                dto,
                                              );
                                          if (!mounted) return;
                                          await _showEventOrderDetailModal(
                                            full,
                                          );
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
                                          ActionPermissionKeys.manageEventsFinalize,
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
                permissionKey: ActionPermissionKeys.manageEventsConfirmDownpayment,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
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
