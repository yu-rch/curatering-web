import 'package:flutter/material.dart';

import '../services/cashier_pos_api.dart';
import '../utils/cashier_pos_filters.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/antd_form_field.dart';
import '../widgets/antd_tokens.dart';

/// Cashier POS shell: online orders, walk-in queue, new walk-in order, history.
class CashierPosShell extends StatefulWidget {
  const CashierPosShell({super.key});

  @override
  State<CashierPosShell> createState() => _CashierPosShellState();
}

class _CashierPosShellState extends State<CashierPosShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _online = const [];
  List<Map<String, dynamic>> _walkInPreparing = const [];
  List<Map<String, dynamic>> _walkInClaimed = const [];
  List<Map<String, dynamic>> _history = const [];
  List<Map<String, dynamic>> _menu = const [];

  final List<Map<String, dynamic>> _tray = [];
  String _pendingFilter = 'wait_payment';
  String _preparingFilter = 'payment_confirmed';
  final _walkInLabelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _menuSearchCtrl = TextEditingController();
  String _paymentMethod = 'CASH';
  bool _showWalkInValidation = false;
  String _menuTypeFilter = 'ALL';
  String _menuSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _walkInLabelCtrl.dispose();
    _amountCtrl.dispose();
    _menuSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        CashierPosApi.instance.listOnlineOrders(),
        CashierPosApi.instance.walkInQueue('preparing'),
        CashierPosApi.instance.walkInQueue('claimed'),
        CashierPosApi.instance.orderHistory(),
        CashierPosApi.instance.loadMenu(),
      ]);
      if (!mounted) return;
      setState(() {
        _online = results[0];
        _walkInPreparing = results[1];
        _walkInClaimed = results[2];
        _history = results[3];
        _menu = results[4];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<PosOrderView> get _pendingOnline =>
      _online
          .map(PosOrderView.new)
          .where((o) => !isWalkIn(o))
          .where((o) => matchesPendingFilter(o, _pendingFilter))
          .toList();

  List<PosOrderView> get _preparingOnline =>
      _online
          .map(PosOrderView.new)
          .where((o) => !isWalkIn(o))
          .where((o) => matchesPreparingFilter(o, _preparingFilter))
          .where(
            (o) =>
                o.fulfillmentStage == 'IN_PREPARATION' ||
                o.status.toUpperCase().contains('ORDER CONFIRMED'),
          )
          .toList();

  List<Map<String, dynamic>> get _restaurantMenu {
    return _menu.where((d) {
      final category = (d['category'] ?? '').toString().trim().toLowerCase();
      return category == 'restaurant';
    }).toList();
  }

  String _dishMealType(Map<String, dynamic> d) {
    final meal = (d['meal_type'] ?? d['type'] ?? '').toString().trim();
    if (meal.isNotEmpty) return meal.toUpperCase();
    final category = (d['category'] ?? '').toString().trim().toLowerCase();
    switch (category) {
      case 'main_course':
      case 'rice':
        return 'RICE MEALS';
      case 'noodles':
        return 'PASTA';
      case 'appetizer':
        return 'SANDWICHES';
      case 'dessert':
        return 'OTHERS';
      case 'drink':
      case 'drinks':
        return 'DRINKS';
      default:
        return 'OTHERS';
    }
  }

  List<Map<String, dynamic>> get _filteredRestaurantMenu {
    final selected = _menuTypeFilter.trim().toLowerCase();
    final search = _menuSearchQuery.trim().toLowerCase();
    return _restaurantMenu.where((d) {
      final type = _dishMealType(d).toLowerCase();
      if (selected != 'all' && type != selected) return false;
      if (search.isEmpty) return true;
      final name = (d['name'] ?? '').toString().toLowerCase();
      return name.contains(search);
    }).toList();
  }

  List<String> get _menuTypeChips {
    final types = <String>{};
    for (final d in _restaurantMenu) {
      types.add(_dishMealType(d));
    }
    final list = types.toList()..sort();
    return ['ALL', ...list];
  }

  void _addDishToTray(Map<String, dynamic> d) {
    final name = (d['name'] ?? 'Dish').toString();
    final price = _toMoney(d['price']);
    setState(() {
      final idx = _tray.indexWhere(
        (it) =>
            (it['item_name']?.toString() ?? '') == name &&
            (it['dip']?.toString() ?? '') == '',
      );
      if (idx >= 0) {
        final existing = _tray[idx];
        final qty =
            (existing['qty'] is num)
                ? (existing['qty'] as num).toInt()
                : int.tryParse('${existing['qty']}') ?? 1;
        existing['qty'] = qty + 1;
      } else {
        _tray.add({
          'item_name': name,
          'dip': '',
          'dip_qty': 0,
          'qty': 1,
          'price': price,
        });
      }
    });
  }

  Future<void> _confirmPayment(PosOrderView order) async {
    final paidCtrl = TextEditingController(
      text: order.total.toStringAsFixed(2),
    );
    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Confirm · ${order.orderNo}',
      body: AntdFieldShell(
        label: 'Amount received',
        required: true,
        child: AntdOutlineInput(
          controller: paidCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: order.total.toStringAsFixed(2),
        ),
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AntdPrimaryButton(
          label: 'Confirm',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    final paid = double.tryParse(paidCtrl.text) ?? order.total;
    paidCtrl.dispose();
    if (ok != true) return;
    try {
      await CashierPosApi.instance.reviewOnlineOrder(
        order.raw['id'],
        action: 'confirm',
        amountReceived: paid,
      );
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment confirmed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _advanceFulfillment(PosOrderView order, String stage) async {
    try {
      await CashierPosApi.instance.patchFulfillment(
        order.raw['id'],
        fulfillmentStage: stage,
      );
      await _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  double _toMoney(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  int _toQty(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 1;
  }

  double get _trayTotal => _tray.fold<double>(0, (s, it) {
    final q = _toQty(it['qty']);
    final p = _toMoney(it['price']);
    return s + q * p;
  });

  Future<void> _submitWalkIn() async {
    setState(() => _showWalkInValidation = true);
    if (_tray.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add items to the tray')));
      return;
    }
    if (_walkInAmountError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount received')),
      );
      return;
    }
    final received = double.tryParse(_amountCtrl.text) ?? _trayTotal;
    try {
      String? paymentRef;
      if (_paymentMethod.toUpperCase() == 'GCASH') {
        final refCtrl = TextEditingController();
        final okRef = await showAntdModal<bool>(
          context: context,
          title: 'GCash reference',
          body: AntdFieldShell(
            label: 'Payment reference',
            required: true,
            child: AntdOutlineInput(
              controller: refCtrl,
              hintText: 'Enter GCash reference',
            ),
          ),
          actions: [
            AntdCancelButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context, false),
            ),
            AntdPrimaryButton(
              label: 'Confirm',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
        if (okRef != true || refCtrl.text.trim().isEmpty) {
          refCtrl.dispose();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GCash reference is required')),
          );
          return;
        }
        paymentRef = refCtrl.text.trim();
        refCtrl.dispose();
      }

      final result = await CashierPosApi.instance.submitWalkInOrder(
        paymentMethod: _paymentMethod,
        amountReceived: received,
        posCustomerLabel: _walkInLabelCtrl.text.trim(),
        items: _tray,
        paymentReferenceInitial: paymentRef,
      );
      setState(() => _tray.clear());
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Walk-in ${result['order_no']} · change ${result['change'] ?? 0}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String? get _walkInAmountError {
    if (_tray.isEmpty) return null;
    final value = _amountCtrl.text.trim();
    if (value.isEmpty) return 'Amount received is required';
    final amount = double.tryParse(value);
    if (amount == null) return 'Enter a valid amount';
    if (amount < _trayTotal) return 'Amount must cover the tray total';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AntdTokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Cashier POS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AntdTokens.valueDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AntdTokens.brandPrimary,
                      foregroundColor: AntdTokens.brandOnPrimary,
                    ),
                    onPressed: _loading ? null : _refreshAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AntdTokens.borderSubtle),
            ),
            child: TabBar(
              controller: _tabs,
              labelColor: AntdTokens.brandOnPrimary,
              unselectedLabelColor: AntdTokens.labelMuted,
              indicatorColor: AntdTokens.brandPrimary,
              tabs: const [
                Tab(text: 'Online'),
                Tab(text: 'Walk-in'),
                Tab(text: 'New order'),
                Tab(text: 'History'),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildOnlineTab(),
                        _buildWalkInTab(),
                        _buildNewOrderTab(),
                        _buildHistoryTab(),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Awaiting payment'),
              selected: _pendingFilter == 'wait_payment',
              onSelected:
                  (_) => setState(() => _pendingFilter = 'wait_payment'),
            ),
            ChoiceChip(
              label: const Text('Insufficient'),
              selected: _pendingFilter == 'payment_insufficient',
              onSelected:
                  (_) =>
                      setState(() => _pendingFilter = 'payment_insufficient'),
            ),
            ChoiceChip(
              label: const Text('Balance review'),
              selected: _pendingFilter == 'wait_balance',
              onSelected:
                  (_) => setState(() => _pendingFilter = 'wait_balance'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Pending (${_pendingOnline.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._pendingOnline.map(_onlineOrderTile),
        const Divider(height: 32),
        Text(
          'In preparation (${_preparingOnline.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._preparingOnline.map(
          (o) => _onlineOrderTile(o, showFulfillment: true),
        ),
      ],
    );
  }

  Widget _onlineOrderTile(PosOrderView o, {bool showFulfillment = false}) {
    return Card(
      child: ListTile(
        title: Text(o.orderNo),
        subtitle: Text(
          '${o.status}\n₱${o.total.toStringAsFixed(2)} · ${o.raw['customer_display_name'] ?? ''}',
        ),
        isThreeLine: true,
        trailing:
            showFulfillment
                ? PopupMenuButton<String>(
                  onSelected: (v) => _advanceFulfillment(o, v),
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: 'OUT_FOR_DELIVERY',
                          child: Text('Out for delivery'),
                        ),
                        PopupMenuItem(
                          value: 'DELIVERED',
                          child: Text('Delivered'),
                        ),
                      ],
                )
                : IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _confirmPayment(o),
                ),
      ),
    );
  }

  Widget _buildWalkInTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Preparing (${_walkInPreparing.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._walkInPreparing.map((raw) {
          final o = PosOrderView(raw);
          return Card(
            child: ListTile(
              title: Text(o.orderNo),
              subtitle: Text(
                raw['pos_customer_label']?.toString() ?? 'Walk-in',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  await CashierPosApi.instance.claimWalkIn(raw['id']);
                  await _refreshAll();
                },
                child: const Text('Claim'),
              ),
            ),
          );
        }),
        const Divider(height: 24),
        Text(
          'Claimed (${_walkInClaimed.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._walkInClaimed.map((raw) {
          final o = PosOrderView(raw);
          return ListTile(
            title: Text(o.orderNo),
            subtitle: Text(raw['pos_customer_label']?.toString() ?? ''),
          );
        }),
      ],
    );
  }

  Widget _buildNewOrderTab() {
    final dishes = _filteredRestaurantMenu;
    final types = _menuTypeChips;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _menuSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search restaurant menu',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _menuSearchQuery.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _menuSearchCtrl.clear();
                            _menuSearchQuery = '';
                          }),
                        ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(
                    () => _menuSearchQuery = v.trim().toLowerCase(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final selected =
                        type.toLowerCase() == _menuTypeFilter.toLowerCase();
                    return FilterChip(
                      label: Text(type),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _menuTypeFilter = type),
                      selectedColor: AntdTokens.brandPrimary.withValues(
                        alpha: 0.35,
                      ),
                      checkmarkColor: AntdTokens.brandOnPrimary,
                    );
                  },
                ),
              ),
              Expanded(
                child: dishes.isEmpty
                    ? Center(
                      child: Text(
                        'No restaurant dishes match your filters',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: dishes.length,
                      itemBuilder: (_, i) {
                        final d = dishes[i];
                        final price = _toMoney(d['price']);
                        return ListTile(
                          title: Text(d['name']?.toString() ?? 'Dish'),
                          subtitle: Text(
                            '${_dishMealType(d)} · ₱${price.toStringAsFixed(2)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addDishToTray(d),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _walkInLabelCtrl,
                    onChanged: (_) {
                      if (_showWalkInValidation) setState(() {});
                    },
                    decoration: const InputDecoration(
                      labelText: 'Customer label',
                      hintText: 'Table 3',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'GCASH', child: Text('GCash')),
                    ],
                    onChanged:
                        (v) => setState(() => _paymentMethod = v ?? 'CASH'),
                  ),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      if (_showWalkInValidation) setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'Amount received',
                      hintText: _trayTotal.toStringAsFixed(2),
                      errorText:
                          _showWalkInValidation ? _walkInAmountError : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tray · ₱${_trayTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView(
                      children: _tray
                          .map(
                            (it) => ListTile(
                              dense: true,
                              title: Text(
                                '${it['item_name']} × ${it['qty']}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: () => setState(() {
                                      final qty = (it['qty'] is num)
                                          ? (it['qty'] as num).toInt()
                                          : int.tryParse('${it['qty']}') ?? 1;
                                      if (qty <= 1) {
                                        _tray.remove(it);
                                      } else {
                                        it['qty'] = qty - 1;
                                      }
                                    }),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => setState(() {
                                      final qty = (it['qty'] is num)
                                          ? (it['qty'] as num).toInt()
                                          : int.tryParse('${it['qty']}') ?? 1;
                                      it['qty'] = qty + 1;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _submitWalkIn,
                    child: const Text('Submit walk-in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final o = PosOrderView(_history[i]);
        return ListTile(
          title: Text(o.orderNo),
          subtitle: Text(o.status),
          trailing: Text('₱${o.total.toStringAsFixed(2)}'),
        );
      },
    );
  }
}
