part of 'catering.dart';

extension _ManageEventsTableExt on _ManageEventsState {
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

  Future<void> _showEventOrderDetailModal(EventOrderDto dto) async {
    final w = MediaQuery.sizeOf(context).width;
    await showAntdModal<void>(
      context: context,
      title: dto.eventTitle,
      maxWidth: 720,
      body: AntdDescriptions(
        column: w < 700 ? 1 : 3,
        items: [
          AntdDescriptionItem(label: 'Customer', value: dto.customerName),
          AntdDescriptionItem(label: 'Contact', value: dto.contactPerson),
          AntdDescriptionItem(label: 'Phone', value: dto.contactNumber),
          AntdDescriptionItem(label: 'Email', value: dto.emailAddress),
          AntdDescriptionItem(label: 'Guests', value: '${dto.guestCount}'),
          AntdDescriptionItem(
            label: 'Address',
            value: dto.address,
            span: w < 700 ? 1 : 2,
          ),
          AntdDescriptionItem(
            label: 'Total',
            value: '₱${dto.totalCost.toStringAsFixed(2)}',
          ),
          AntdDescriptionItem(
            label: 'Down payment',
            value:
                '${dto.downPaymentStatus} · ₱${dto.downPaymentAmount.toStringAsFixed(2)}',
          ),
        ],
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
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Guests')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      filtered.map((dto) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                dto.eventTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(Text(dto.customerName)),
                            DataCell(Text(_formatOrderSchedule(dto))),
                            DataCell(Text('${dto.guestCount}')),
                            DataCell(
                              Text('₱${dto.totalCost.toStringAsFixed(2)}'),
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

  Widget _buildForDownpaymentTableView(bool isNarrow) {
    return SingleChildScrollView(
      child: _buildOrdersTablePanel(
        title: 'For downpayment',
        orders: _downpaymentOrders,
        emptyMessage: 'No confirmed orders awaiting downpayment.',
        actionCells:
            (dto) => [
              TextButton(
                onPressed: () => _showEventOrderDetailModal(dto),
                child: const Text('View'),
              ),
              TextButton(
                onPressed: () => _acceptOrder(dto),
                child: const Text('Accept'),
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
              TextButton(
                onPressed: () => _showEventOrderDetailModal(dto),
                child: const Text('View'),
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
              TextButton(
                onPressed: () => _showEventOrderDetailModal(dto),
                child: const Text('View'),
              ),
              TextButton(
                onPressed: () => _openFullPaymentCompleteModal(dto),
                child: const Text('Complete'),
              ),
            ],
      ),
    );
  }
}
