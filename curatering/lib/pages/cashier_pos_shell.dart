import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/cashier_pos_api.dart';
import '../services/menu_store.dart';
import '../models/menu_dish.dart';
import '../utils/cashier_pos_filters.dart';
import '../utils/payment_proof_image.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/confirm_logout_dialog.dart';

class CashierPosShell extends StatefulWidget {
  const CashierPosShell({super.key, this.appBarTrailing});

  /// Optional trailing AppBar control (e.g. manager/POS mode switcher).
  final Widget? appBarTrailing;

  @override
  State<CashierPosShell> createState() => _CashierPosShellState();
}

class _CashierPosShellState extends State<CashierPosShell> {
  final GlobalKey<ScaffoldState> _posScaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTab = 0;
  Timer? _clockTimer;
  String _clock = '';

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _online = const [];
  List<Map<String, dynamic>> _walkInPreparing = const [];
  List<Map<String, dynamic>> _walkInClaimed = const [];
  List<Map<String, dynamic>> _walkInCancelled = const [];

  final List<Map<String, dynamic>> _tray = [];
  final _walkInLabelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _gcashRefCtrl = TextEditingController();
  String _paymentMethod = 'CASH';
  Uint8List? _gcashProofBytes;
  String? _gcashProofBase64;

  String _menuSearch = '';
  String _menuCategory = 'ALL';

  String _onlineSearch = '';
  String _onlinePendingFilter = 'all';
  String _onlinePreparingFilter = 'all';
  int _onlineSubTab = 0;
  PosOrderView? _selectedOnlineOrder;

  String _walkSearch = '';
  int _walkInSubTab = 0;
  Map<String, dynamic>? _selectedWalkIn;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
    _refreshAll();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _walkInLabelCtrl.dispose();
    _amountCtrl.dispose();
    _gcashRefCtrl.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ap = now.hour >= 12 ? 'PM' : 'AM';
    if (mounted) setState(() => _clock = '$h:$m:$s $ap');
  }

  // ---------------------------------------------------------------------------
  // Data refresh
  // ---------------------------------------------------------------------------

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await MenuStore.instance.loadDishesWithImages();
      final results = await Future.wait([
        CashierPosApi.instance.listOnlineOrders(),
        CashierPosApi.instance.walkInQueue('preparing'),
        CashierPosApi.instance.walkInQueue('claimed'),
        CashierPosApi.instance.walkInQueue('cancelled'),
      ]);
      if (!mounted) return;
      setState(() {
        _online = results[0];
        _walkInPreparing = results[1];
        _walkInClaimed = results[2];
        _walkInCancelled = results[3];
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

  Future<void> _refreshOnline() async {
    try {
      final data = await CashierPosApi.instance.listOnlineOrders();
      if (mounted) {
        setState(() {
          _online = data;
          // Update selected order with fresh data
          if (_selectedOnlineOrder != null) {
            final id = _selectedOnlineOrder!.orderNo;
            final fresh = data.cast<Map<String, dynamic>>().where(
              (r) => PosOrderView(r).orderNo == id,
            );
            _selectedOnlineOrder = fresh.isNotEmpty ? PosOrderView(fresh.first) : null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshWalkIn() async {
    try {
      final results = await Future.wait([
        CashierPosApi.instance.walkInQueue('preparing'),
        CashierPosApi.instance.walkInQueue('claimed'),
        CashierPosApi.instance.walkInQueue('cancelled'),
      ]);
      if (mounted) {
        setState(() {
          _walkInPreparing = results[0];
          _walkInClaimed = results[1];
          _walkInCancelled = results[2];
        });
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double _toMoney(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  Future<void> _withStatusUpdate(Future<void> Function() action) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Widget? _paymentAmountSummary(Map<String, dynamic> raw, {bool walkIn = false}) {
    final due = _toMoney(raw['total'] ?? raw['total_cost'] ?? 0);
    final received = _toMoney(
      raw['amount_received'] ??
          raw['cashier_amount_received'] ??
          raw['amount_paid'] ??
          0,
    );
    final change = _toMoney(raw['change'] ?? raw['change_given'] ?? 0);
    if (!walkIn && due <= 0 && received <= 0 && change <= 0) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (due > 0)
          Text(
            'Amount due: ₱${due.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        if (received > 0)
          Text(
            'Amount received: ₱${received.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        if (change > 0)
          Text(
            'Change: ₱${change.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
      ],
    );
  }

  int _toQty(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 1;
  }

  double get _trayTotal => _tray.fold<double>(
        0,
        (s, it) => s + _toQty(it['qty']) * _toMoney(it['price']),
      );

  int get _trayItemCount =>
      _tray.fold<int>(0, (s, it) => s + _toQty(it['qty']));

  Future<void> _snack(String msg, {bool success = false}) async {
    if (!mounted) return;
    if (success) {
      await showCurateringSuccessDialog(
        context: context,
        title: 'Success',
        body: msg,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Notice'),
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AntdTokens.brandPrimary,
              foregroundColor: AntdTokens.brandOnPrimary,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String? _posOrderId(Map<String, dynamic> raw) {
    for (final key in ['id', 'order_id', 'order_no']) {
      final v = raw[key]?.toString().trim() ?? '';
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return null;
  }

  List<dynamic> _orderItems(Map<String, dynamic> raw) {
    final items = raw['tray_items'] ??
        raw['order_lines_snapshot'] ??
        raw['lines'] ??
        raw['items'];
    if (items is List && items.isNotEmpty) return items;
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Menu data — restaurant dishes only
  // ---------------------------------------------------------------------------

  List<MenuDish> get _restaurantDishes {
    return MenuStore.instance.activeDishes
        .where((d) => d.category.trim().toLowerCase() == 'restaurant')
        .toList();
  }

  List<String> get _categoryChips {
    final types = <String>{'ALL'};
    for (final dish in _restaurantDishes) {
      final mt = dish.effectiveMealType.trim().toUpperCase();
      types.add(mt.isNotEmpty ? mt : 'OTHERS');
    }
    final list = types.toList()..sort();
    list.remove('ALL');
    list.insert(0, 'ALL');
    return list;
  }

  String _dishMealType(MenuDish dish) {
    final mt = dish.effectiveMealType.trim().toLowerCase();
    return mt.isNotEmpty ? mt : 'others';
  }

  List<MenuDish> get _filteredDishes {
    final selectedType = _menuCategory.trim().toLowerCase();
    final search = _menuSearch.trim().toLowerCase();
    return _restaurantDishes.where((d) {
      if (selectedType != 'all' && _dishMealType(d) != selectedType) {
        return false;
      }
      if (search.isEmpty) return true;
      return d.name.toLowerCase().contains(search) ||
          d.publicDescription.toLowerCase().contains(search);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Add-to-tray dialog (matches restaurant_order_page.dart)
  // ---------------------------------------------------------------------------

  void _showAddToTrayDialog(MenuDish dish) {
    int quantity = 1;
    String? selectedAddOn;
    int addOnQty = 1;
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final dishPrice = double.tryParse(dish.price) ?? 0;
          final totalPrice = dishPrice * quantity;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image header
                  Stack(
                    children: [
                      RepaintBoundary(
                        child: dish.imageBase64?.isNotEmpty == true
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: Image.memory(
                                  base64Decode(dish.imageBase64!),
                                  fit: BoxFit.cover,
                                  height: 160,
                                  width: double.infinity,
                                  gaplessPlayback: true,
                                ),
                              )
                            : Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: const Icon(Icons.fastfood,
                                    size: 48, color: Colors.grey),
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(dialogCtx),
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dish.name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('₱${dish.price}',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w600)),
                          if (dish.publicDescription.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(dish.publicDescription.trim(),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    height: 1.35)),
                          ],
                          if (dish.ingredients.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('Ingredients',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: dish.ingredients
                                  .map((ing) => Chip(
                                        label: Text(ing,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ],
                          if (dish.allergens.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text('Allergens',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.red.shade700)),
                            const SizedBox(height: 4),
                            Text(dish.allergens.trim(),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700)),
                          ],
                          if (dish.sauces.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('Add-on',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String?>(
                              value: selectedAddOn,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('None')),
                                ...dish.sauces.map((s) =>
                                    DropdownMenuItem<String?>(
                                        value: s, child: Text(s))),
                              ],
                              onChanged: (val) => setDialogState(() {
                                selectedAddOn = val;
                                addOnQty = 1;
                              }),
                            ),
                            if (selectedAddOn != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Qty:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700)),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              size: 16),
                                          onPressed: addOnQty > 1
                                              ? () => setDialogState(
                                                  () => addOnQty--)
                                              : null,
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                        ),
                                        Text('$addOnQty',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.add, size: 16),
                                          onPressed: () =>
                                              setDialogState(() => addOnQty++),
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                          const Text('Notes',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: notesCtrl,
                            decoration: InputDecoration(
                              hintText: 'Special instructions...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon:
                                          const Icon(Icons.remove, size: 18),
                                      onPressed: quantity > 1
                                          ? () =>
                                              setDialogState(() => quantity--)
                                          : null,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    ),
                                    Text('$quantity',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () =>
                                          setDialogState(() => quantity++),
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _tray.add({
                                        'item_name': dish.name,
                                        'dish_id': dish.id,
                                        'image_base64': dish.imageBase64,
                                        'dip': selectedAddOn ?? '',
                                        'dip_qty': selectedAddOn != null
                                            ? addOnQty
                                            : 0,
                                        'qty': quantity,
                                        'price': dishPrice,
                                        'note': notesCtrl.text.trim(),
                                      });
                                    });
                                    Navigator.pop(dialogCtx);
                                    _snack(
                                        '${dish.name} x$quantity added to tray');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AntdTokens.brandPrimary,
                                    foregroundColor:
                                        AntdTokens.brandOnPrimary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    'ADD TO TRAY  ₱${totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Checkout confirmation → walk-in submission
  // ---------------------------------------------------------------------------

  Future<void> _handleCheckout() async {
    if (_tray.isEmpty) {
      _snack('Add items to the tray');
      return;
    }
    final received = double.tryParse(_amountCtrl.text.trim());
    if (received == null || received < _trayTotal) {
      _snack('Amount received must cover ₱${_trayTotal.toStringAsFixed(2)}');
      return;
    }
    if (_paymentMethod == 'GCASH') {
      if (_gcashProofBase64 == null || _gcashProofBase64!.isEmpty) {
        _snack('Please upload GCash payment proof');
        return;
      }
      if (_gcashRefCtrl.text.trim().isEmpty) {
        _snack('Please enter GCash reference number');
        return;
      }
    }

    // Confirmation dialog with order summary
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirm Order'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_walkInLabelCtrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        'Customer: ${_walkInLabelCtrl.text.trim()}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ..._tray.map((item) {
                  final name = item['item_name']?.toString() ?? 'Dish';
                  final qty = _toQty(item['qty']);
                  final price = _toMoney(item['price']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('$name  x$qty',
                                style: const TextStyle(fontSize: 13))),
                        Text('₱${(price * qty).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('₱${_trayTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Payment: $_paymentMethod',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700)),
                Text('Received: ₱${received.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700)),
                if (received > _trayTotal)
                  Text(
                      'Change: ₱${(received - _trayTotal).toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.green.shade700)),
                const SizedBox(height: 14),
                const Text('Proceed with this order?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await CashierPosApi.instance.submitWalkInOrder(
        paymentMethod: _paymentMethod,
        amountReceived: received,
        posCustomerLabel: _walkInLabelCtrl.text.trim(),
        items: _tray,
        note: _paymentMethod == 'GCASH'
            ? 'Ref#: ${_gcashRefCtrl.text.trim()}'
            : '',
        paymentProofBase64: _gcashProofBase64,
      );
      setState(() {
        _tray.clear();
        _walkInLabelCtrl.clear();
        _amountCtrl.clear();
        _gcashRefCtrl.clear();
        _gcashProofBytes = null;
        _gcashProofBase64 = null;
      });
      await _refreshWalkIn();
      if (mounted) {
        final change = result['change'] ?? 0;
        await _snack(
          'Walk-in ${result['order_no']} submitted · change ₱$change',
          success: true,
        );
      }
    } catch (e) {
      if (mounted) await _snack('$e');
    }
  }

  Future<void> _pickGcashProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _gcashProofBytes = result.files.single.bytes;
        _gcashProofBase64 = base64Encode(_gcashProofBytes!);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Online order actions
  // ---------------------------------------------------------------------------

  Future<void> _confirmPayment(PosOrderView order) async {
    final raw = order.raw;
    final proofB64 = (raw['payment_proof'] ?? raw['payment_proof_initial'] ?? '').toString();
    final balanceProofB64 = (raw['payment_proof_balance'] ?? raw['supplemental_payment_proof'] ?? '').toString();
    final refNumber = (raw['payment_reference_initial'] ?? '').toString();
    final balanceRef = (raw['payment_reference_balance'] ?? '').toString();
    final initialPaid = _toMoney(raw['cashier_amount_received'] ?? raw['amount_paid'] ?? 0);
    final isBalanceReview = initialPaid > 0 && balanceProofB64.isNotEmpty;

    final paidCtrl = TextEditingController(
      text: order.total.toStringAsFixed(2),
    );

    String? dialogAction;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final entered = double.tryParse(paidCtrl.text) ?? 0;
          final isInsufficient = entered > 0 && entered < order.total;
          final isOverpayment = entered > order.total;

          return AlertDialog(
            title: Text('Confirm Payment · ${order.orderNo}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order total: ₱${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),

                    // Show initial payment info when reviewing balance
                    if (isBalanceReview) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Initial Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Amount: ₱${initialPaid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                            if (refNumber.isNotEmpty)
                              Text('Ref#: $refNumber', style: const TextStyle(fontSize: 12)),
                            if (proofB64.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: buildPaymentProofPreview(proofB64, height: 100, emptyLabel: ''),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Balance Payment Proof:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (balanceRef.isNotEmpty)
                        Text('Ref#: $balanceRef', style: const TextStyle(fontSize: 12)),
                    ] else ...[
                      // Show initial proof for initial review
                      if (refNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('GCash Ref#: $refNumber', style: const TextStyle(fontSize: 13)),
                        ),
                    ],

                    // Proof of payment image
                    if (isBalanceReview && balanceProofB64.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildPaymentProofPreview(balanceProofB64, height: 140, emptyLabel: ''),
                      ),
                    ] else if (!isBalanceReview && proofB64.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Payment Proof:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildPaymentProofPreview(proofB64, height: 140, emptyLabel: ''),
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextField(
                      controller: paidCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount received',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),

                    // Insufficient/Overpayment indicators
                    if (isInsufficient)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Insufficient: ₱${(order.total - entered).toStringAsFixed(2)} short',
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    if (isOverpayment)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Overpayment: ₱${(entered - order.total).toStringAsFixed(2)} over',
                          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (isInsufficient)
                OutlinedButton(
                  onPressed: () { dialogAction = 'insufficient'; Navigator.pop(ctx); },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: const Text('Insufficient Payment'),
                ),
              if (isOverpayment)
                OutlinedButton(
                  onPressed: () { dialogAction = 'confirm'; Navigator.pop(ctx); },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
                  child: const Text('Accept Overpayment'),
                ),
              if (!isInsufficient && !isOverpayment)
                FilledButton(
                  onPressed: entered > 0 ? () { dialogAction = 'confirm'; Navigator.pop(ctx); } : null,
                  child: const Text('Confirm Payment'),
                ),
            ],
          );
        },
      ),
    );

    final paid = double.tryParse(paidCtrl.text) ?? order.total;
    paidCtrl.dispose();
    if (dialogAction == null) return;

    await _withStatusUpdate(() async {
      await CashierPosApi.instance.reviewOnlineOrder(
        _posOrderId(order.raw) ?? order.orderNo,
        action: dialogAction!,
        amountReceived: paid,
      );
      await _refreshOnline();
      if (mounted) {
        await _snack(
          dialogAction == 'insufficient'
              ? 'Marked as insufficient'
              : 'Payment confirmed',
          success: dialogAction != 'insufficient',
        );
      }
    });
  }

  Future<void> _showOutForDeliveryDialog(PosOrderView order) async {
    final trackingCtrl = TextEditingController();
    final trackingUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Out for Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: ${order.orderNo}'),
            const SizedBox(height: 12),
            TextField(
              controller: trackingCtrl,
              decoration: const InputDecoration(
                labelText: 'Delivery tracking link/URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, trackingCtrl.text.trim()),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    trackingCtrl.dispose();
    if (trackingUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Out for Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: ${order.orderNo}'),
            const SizedBox(height: 8),
            Text(
                'Tracking URL: ${trackingUrl.isEmpty ? "(none)" : trackingUrl}'),
            const SizedBox(height: 12),
            const Text(
                'Are you sure you want to mark this order as Out for Delivery?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _withStatusUpdate(() async {
        await CashierPosApi.instance.patchFulfillment(
          _posOrderId(order.raw) ?? order.orderNo,
          fulfillmentStage: 'OUT_FOR_DELIVERY',
          deliveryTrackingUrl: trackingUrl,
        );
        await _refreshOnline();
      });
      if (mounted) await _snack('Marked Out for Delivery', success: true);
    } catch (e) {
      if (mounted) await _snack('$e');
    }
  }

  Future<void> _markDelivered(PosOrderView order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: Text(
            'Confirm that order ${order.orderNo} has been delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _withStatusUpdate(() async {
        await CashierPosApi.instance.patchFulfillment(
          _posOrderId(order.raw) ?? order.orderNo,
          fulfillmentStage: 'DELIVERED',
        );
        await _refreshOnline();
      });
      if (mounted) await _snack('Marked as Delivered', success: true);
    } catch (e) {
      if (mounted) await _snack('$e');
    }
  }

  Future<void> _claimWalkIn(Map<String, dynamic> raw) async {
    final o = PosOrderView(raw);
    final orderId = _posOrderId(raw);
    if (orderId == null) {
      await _snack('Missing order id — refresh the walk-in queue and try again.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark order claimed?'),
        content: Text(
            'Confirm when ${o.orderNo} has been picked up by the customer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _withStatusUpdate(() async {
        await CashierPosApi.instance.claimWalkIn(orderId);
        await _refreshWalkIn();
      });
      if (mounted) {
        setState(() {
          _selectedWalkIn = null;
          _walkInSubTab = 1;
        });
        await _snack('Order claimed', success: true);
      }
    } catch (e) {
      if (mounted) await _snack('$e');
    }
  }

  Future<void> _cancelWalkIn(Map<String, dynamic> raw) async {
    final o = PosOrderView(raw);
    final orderId = _posOrderId(raw);
    if (orderId == null) {
      await _snack('Missing order id — refresh the walk-in queue and try again.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this walk-in order?'),
        content: Text('${o.orderNo} will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _withStatusUpdate(() async {
        await CashierPosApi.instance.cancelWalkIn(orderId);
        await _refreshWalkIn();
      });
      if (mounted) {
        setState(() => _selectedWalkIn = null);
        await _snack('Order cancelled', success: true);
      }
    } catch (e) {
      if (mounted) await _snack('$e');
    }
  }

  // ---------------------------------------------------------------------------
  // Online order filters
  // ---------------------------------------------------------------------------

  List<PosOrderView> get _pendingOnline => _online
      .map(PosOrderView.new)
      .where((o) => !isWalkIn(o))
      .where((o) {
        final stage = o.fulfillmentStage.toUpperCase();
        if (stage == 'PENDING_CASHIER' || stage.isEmpty) return true;
        if (stage == 'BALANCE_PAYMENT_PENDING_REVIEW') return true;
        if (stage == 'PAYMENT_INSUFFICIENT') return true;
        if (o.balanceProofPending) return true;
        return false;
      })
      .where((o) => matchesPendingFilter(o, _onlinePendingFilter))
      .where(_matchesOnlineSearch)
      .toList();

  List<PosOrderView> get _preparingOnline => _online
      .map(PosOrderView.new)
      .where((o) => !isWalkIn(o))
      .where((o) {
        final stage = o.fulfillmentStage.toUpperCase();
        if (stage == 'OUT_FOR_DELIVERY' || stage == 'DELIVERED') return false;
        return stage == 'IN_PREPARATION' ||
            o.status.toUpperCase().contains('ORDER CONFIRMED');
      })
      .where((o) => matchesPreparingFilter(o, _onlinePreparingFilter))
      .where(_matchesOnlineSearch)
      .toList();

  List<PosOrderView> get _outForDeliveryOnline => _online
      .map(PosOrderView.new)
      .where((o) => !isWalkIn(o))
      .where((o) => o.fulfillmentStage.toUpperCase() == 'OUT_FOR_DELIVERY')
      .where(_matchesOnlineSearch)
      .toList();

  List<PosOrderView> get _deliveredOnline => _online
      .map(PosOrderView.new)
      .where((o) => !isWalkIn(o))
      .where((o) => o.fulfillmentStage.toUpperCase() == 'DELIVERED')
      .where(_matchesOnlineSearch)
      .toList();

  List<PosOrderView> get _cancelledOnline => _online
      .map(PosOrderView.new)
      .where((o) => !isWalkIn(o))
      .where((o) => o.status.toUpperCase().contains('CANCEL'))
      .where(_matchesOnlineSearch)
      .toList();

  bool _matchesOnlineSearch(PosOrderView o) {
    final q = _onlineSearch.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.orderNo.toLowerCase().contains(q) ||
        o.status.toLowerCase().contains(q) ||
        (o.raw['customer_display_name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q) ||
        (o.raw['user_email'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q);
  }

  // ---------------------------------------------------------------------------
  // Tracking URL launcher
  // ---------------------------------------------------------------------------

  Future<void> _launchTrackingUrl(String url) async {
    var target = url.trim();
    if (target.isNotEmpty &&
        !target.startsWith('http://') &&
        !target.startsWith('https://')) {
      target = 'https://$target';
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      _snack('Invalid tracking URL');
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Could not open tracking link');
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser.value;
    final cashierName =
        (user?.fullName ?? user?.email ?? 'CASHIER').toUpperCase();
    const tabLabels = ['NEW ORDER', 'ONLINE ORDERS', 'WALK-IN ORDERS'];

    return Scaffold(
      key: _posScaffoldKey,
      backgroundColor: Colors.white,
      drawer: MediaQuery.sizeOf(context).width < 900
          ? Drawer(
              backgroundColor: const Color(0xFF1E1E1E),
              width: 220,
              child: SafeArea(child: _buildSidebar(inDrawer: true)),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: MediaQuery.sizeOf(context).width < 900
            ? IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu),
                onPressed: () => _posScaffoldKey.currentState?.openDrawer(),
              )
            : null,
        title: Row(
          children: [
            const Icon(Icons.storefront, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                cashierName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.appBarTrailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: widget.appBarTrailing!,
                ),
              ),
            ),
          if (_selectedTab == 0 && _trayItemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_trayItemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AntdTokens.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabLabels[_selectedTab],
                  style: const TextStyle(
                    color: AntdTokens.brandOnPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _clock,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 900) _buildSidebar(),
          if (MediaQuery.sizeOf(context).width >= 900)
            Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _refreshAll,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : IndexedStack(
                        index: _selectedTab,
                        children: [
                          _buildNewOrderTab(),
                          _buildOnlineOrdersTab(),
                          _buildWalkInTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left sidebar navigation + logout
  // ---------------------------------------------------------------------------

  Widget _buildSidebar({bool inDrawer = false}) {
    return Container(
      width: inDrawer ? null : 82,
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _sidebarTab(0, Icons.add_shopping_cart, 'New\nOrder', inDrawer: inDrawer),
          _sidebarTab(1, Icons.cloud_queue, 'Online', inDrawer: inDrawer),
          _sidebarTab(2, Icons.storefront_outlined, 'Walk-In', inDrawer: inDrawer),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          const SizedBox(height: 8),
          _sidebarAction(Icons.refresh, 'Refresh', Colors.white60, () {
            if (inDrawer) _posScaffoldKey.currentState?.closeDrawer();
            _refreshAll();
          }),
          const SizedBox(height: 4),
          _sidebarAction(Icons.settings_outlined, 'Settings', Colors.white60, () {
            if (inDrawer) _posScaffoldKey.currentState?.closeDrawer();
            Navigator.of(context).pushNamed('/settings');
          }),
          if (AuthSession.instance.currentRole == Role.cashier) ...[
            const SizedBox(height: 4),
            _sidebarAction(Icons.logout, 'Logout', Colors.red.shade400, () async {
              if (inDrawer) _posScaffoldKey.currentState?.closeDrawer();
              final ok = await confirmLogout(context);
              if (ok != true || !mounted) return;
              AuthSession.instance.clear();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            }),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sidebarTab(int index, IconData icon, String label, {bool inDrawer = false}) {
    final active = _selectedTab == index;
    return InkWell(
      onTap: () {
        if (inDrawer) _posScaffoldKey.currentState?.closeDrawer();
        setState(() => _selectedTab = index);
        if (index == 1) _refreshOnline();
        if (index == 2) _refreshWalkIn();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? AntdTokens.brandPrimary.withAlpha(40)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? AntdTokens.brandPrimary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? AntdTokens.brandPrimary : Colors.white70,
                size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? AntdTokens.brandPrimary : Colors.white70,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 0 — NEW ORDER (menu grid + tray sidebar)
  // =========================================================================

  Widget _buildNewOrderTab() {
    final dishes = _filteredDishes;
    final subtotal = _trayTotal;

    final menuBody = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search restaurant menu',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (v) => setState(() => _menuSearch = v),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _categoryChips.length,
            itemBuilder: (_, i) {
              final type = _categoryChips[i];
              final selected =
                  type.toLowerCase() == _menuCategory.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(type),
                  selected: selected,
                  selectedColor: AntdTokens.brandPrimary.withAlpha(80),
                  onSelected: (_) =>
                      setState(() => _menuCategory = type),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: dishes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No items available',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: GridView.builder(
                    key: ValueKey(_menuCategory),
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: dishes.length,
                    itemBuilder: (context, i) =>
                        _buildDishCard(dishes[i]),
                  ),
                ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 780) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: menuBody),
              _buildTraySidebar(subtotal),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: menuBody),
            _buildTrayBottomBar(subtotal),
          ],
        );
      },
    );
  }

  Widget _buildDishCard(MenuDish dish) {
    final price = double.tryParse(dish.price) ?? 0;
    void addToTray() {
      if (!dish.available) return;
      _showAddToTrayDialog(dish);
    }

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: dish.available ? addToTray : null,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: RepaintBoundary(
                    child: dish.imageBase64?.isNotEmpty == true
                        ? Image.memory(
                            base64Decode(dish.imageBase64!),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, size: 48),
                          ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dish.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: dish.available ? addToTray : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dish.available
                            ? AntdTokens.brandOnPrimary
                            : Colors.grey.shade500,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        dish.available ? 'Add to tray' : 'Not Available',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tray sidebar (desktop) / bottom bar (narrow)
  // ---------------------------------------------------------------------------

  Widget _buildTraySidebar(double subtotal) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your Tray',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$_trayItemCount ${_trayItemCount == 1 ? 'item' : 'items'}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tray.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('Your tray is empty',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    itemCount: _tray.length,
                    itemBuilder: (_, i) => _buildTrayLine(_tray[i], i),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border:
                  Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _walkInLabelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer label',
                    hintText: 'Table 3',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                    DropdownMenuItem(
                        value: 'GCASH', child: Text('GCASH')),
                  ],
                  onChanged: (v) =>
                      setState(() => _paymentMethod = v ?? 'CASH'),
                ),
                if (_paymentMethod == 'GCASH') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gcashRefCtrl,
                    maxLength: 13,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'GCash Reference Number',
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickGcashProof,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(_gcashProofBytes != null
                        ? 'Proof uploaded'
                        : 'Upload payment proof'),
                  ),
                  if (_gcashProofBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: RepaintBoundary(
                          child: Image.memory(
                            _gcashProofBytes!,
                            height: 60,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount received',
                    hintText: subtotal.toStringAsFixed(2),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('₱${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AntdTokens.brandPrimary,
                      foregroundColor: AntdTokens.brandOnPrimary,
                    ),
                    onPressed: _tray.isEmpty ? null : _handleCheckout,
                    child: const Text('CHECKOUT'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayBottomBar(double subtotal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AntdTokens.brandPrimary,
                foregroundColor: AntdTokens.brandOnPrimary,
              ),
              onPressed: _tray.isEmpty ? null : _showTraySheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('YOUR TRAY'),
                  if (_trayItemCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      constraints: const BoxConstraints(
                          minWidth: 22, minHeight: 22),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_trayItemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTraySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Text('YOUR TRAY',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8)),
                          const Spacer(),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _tray.isEmpty
                          ? const Center(child: Text('No dishes yet.'))
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              itemCount: _tray.length,
                              itemBuilder: (_, i) {
                                return _buildTrayLine(_tray[i], i,
                                    onChanged: () {
                                  setSheetState(() {});
                                  setState(() {});
                                });
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              'Total ₱${_trayTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() => _tray.clear());
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('CLEAR'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        AntdTokens.brandPrimary,
                                    foregroundColor:
                                        AntdTokens.brandOnPrimary,
                                  ),
                                  onPressed: _tray.isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(ctx);
                                          _handleCheckout();
                                        },
                                  child: const Text('CHECKOUT'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTrayLine(Map<String, dynamic> item, int index,
      {VoidCallback? onChanged}) {
    final name = item['item_name']?.toString() ?? 'Dish';
    final qty = _toQty(item['qty']);
    final price = _toMoney(item['price']);
    final imageB64 = item['image_base64']?.toString();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            if (imageB64 != null && imageB64.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      base64Decode(imageB64),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.fastfood,
                      size: 18, color: Colors.grey),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '₱${price.toStringAsFixed(2)} × $qty = ₱${(price * qty).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() {
                      if (qty <= 1) {
                        _tray.removeAt(index);
                      } else {
                        item['qty'] = qty - 1;
                      }
                    });
                    onChanged?.call();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('$qty',
                      style:
                          const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.add_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() => item['qty'] = qty + 1);
                    onChanged?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1 — ONLINE ORDERS (split: list LEFT, detail RIGHT)
  // =========================================================================

  Widget _buildOnlineOrdersTab() {
    final subTabs = [
      'Pending',
      'Preparing',
      'For Delivery',
      'Delivered',
      'Cancelled',
    ];
    final subLists = [
      _pendingOnline,
      _preparingOnline,
      _outForDeliveryOnline,
      _deliveredOnline,
      _cancelledOnline,
    ];

    final listPanel = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search order no / email / status',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) =>
                      setState(() => _onlineSearch = v),
                ),
              ),
              if (_onlineSubTab == 0)
                PopupMenuButton<String>(
                  tooltip: 'Filter',
                  icon: Icon(Icons.filter_list,
                      color: _onlinePendingFilter != 'all'
                          ? AntdTokens.brandPrimary
                          : null),
                  onSelected: (v) =>
                      setState(() => _onlinePendingFilter = v),
                  itemBuilder: (_) => [
                    _popupItem(
                        'all', 'All', _onlinePendingFilter),
                    _popupItem('wait_payment', 'Waiting Payment',
                        _onlinePendingFilter),
                    _popupItem('payment_insufficient',
                        'Payment Insufficient', _onlinePendingFilter),
                    _popupItem('wait_balance', 'Balance Review',
                        _onlinePendingFilter),
                  ],
                ),
              if (_onlineSubTab == 1)
                PopupMenuButton<String>(
                  tooltip: 'Filter',
                  icon: Icon(Icons.filter_list,
                      color: _onlinePreparingFilter != 'all'
                          ? AntdTokens.brandPrimary
                          : null),
                  onSelected: (v) =>
                      setState(() => _onlinePreparingFilter = v),
                  itemBuilder: (_) => [
                    _popupItem(
                        'all', 'All', _onlinePreparingFilter),
                    _popupItem('payment_confirmed',
                        'Payment Confirmed', _onlinePreparingFilter),
                    _popupItem('overpayment', 'Overpayment',
                        _onlinePreparingFilter),
                  ],
                ),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshOnline),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: subTabs.length,
            itemBuilder: (_, i) {
              final active = _onlineSubTab == i;
              final count = subLists[i].length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${subTabs[i]} ($count)'),
                  selected: active,
                  selectedColor:
                      AntdTokens.brandPrimary.withAlpha(80),
                  onSelected: (_) => setState(() {
                    _onlineSubTab = i;
                    _selectedOnlineOrder = null;
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: subLists[_onlineSubTab].isEmpty
              ? const Center(
                  child: Text('No orders in this stage.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: subLists[_onlineSubTab].length,
                  itemBuilder: (_, i) {
                    final o = subLists[_onlineSubTab][i];
                    final selected = _selectedOnlineOrder
                            ?.orderNo ==
                        o.orderNo;
                    return _buildOnlineOrderListTile(
                        o, _onlineSubTab, selected);
                  },
                ),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(flex: 2, child: listPanel),
        Container(width: 1, color: Colors.grey.shade300),
        Expanded(flex: 3, child: _buildOnlineOrderDetailPanel()),
      ],
    );
  }

  Widget _buildOnlineOrderListTile(
      PosOrderView o, int tabIdx, bool isSelected) {
    final customerName =
        o.raw['customer_display_name']?.toString() ??
            o.raw['user_email']?.toString() ??
            '';
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? AntdTokens.brandPrimary.withAlpha(30)
          : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () =>
            setState(() => _selectedOnlineOrder = o),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusBadgeBg(o.status),
                      borderRadius:
                          BorderRadius.circular(999),
                    ),
                    child: Text(
                      o.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              _statusBadgeFg(o.status)),
                    ),
                  ),
                  const Spacer(),
                  Text(
                      '₱${o.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Text(o.orderNo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              if (customerName.isNotEmpty)
                Text(customerName,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700)),
              if (_paymentAmountSummary(o.raw) != null) ...[
                const SizedBox(height: 4),
                _paymentAmountSummary(o.raw)!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineOrderDetailPanel() {
    if (_selectedOnlineOrder == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Select an order to view details',
                style:
                    TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    final o = _selectedOnlineOrder!;
    final raw = o.raw;
    final lines = _orderItems(raw);
    final customerName =
        raw['customer_display_name']?.toString() ??
            raw['user_email']?.toString() ??
            '—';
    final createdAt = raw['created_at']?.toString() ?? '';
    final deliveryAddress =
        raw['delivery_address']?.toString() ?? '';
    final note = raw['note']?.toString() ??
        raw['special_instructions']?.toString() ??
        '';
    final paymentMethod =
        (raw['payment_method'] ?? raw['payment_mode'] ?? '')
            .toString();
    final trackingUrl =
        raw['delivery_tracking_url']?.toString() ?? '';
    final stage = o.fulfillmentStage.toUpperCase();
    final amountReceived =
        _toMoney(raw['amount_received'] ?? 0);
    final proofB64 = (raw['payment_proof'] ??
            raw['payment_proof_initial'])
        ?.toString();

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.orderNo,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              _buildOnlineDetailActions(o),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('Status', o.status),
          _detailRow(
              'Fulfillment',
              o.fulfillmentStage.isNotEmpty
                  ? o.fulfillmentStage
                  : '—'),
          _detailRow('Customer', customerName),
          _detailRow('Payment',
              paymentMethod.isNotEmpty ? paymentMethod : '—'),
          _detailRow('Total',
              '₱${o.total.toStringAsFixed(2)}'),
          if (amountReceived > 0)
            _detailRow('Amount Received',
                '₱${amountReceived.toStringAsFixed(2)}'),
          if (createdAt.isNotEmpty)
            _detailRow('Placed', createdAt),
          if (deliveryAddress.isNotEmpty)
            _detailRow('Address', deliveryAddress),
          if (note.isNotEmpty) _detailRow('Note', note),

          // Clickable tracking URL
          if (trackingUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text('Tracking',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            fontSize: 13)),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          _launchTrackingUrl(trackingUrl),
                      child: Text(
                        trackingUrl,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AntdTokens.info,
                            decoration:
                                TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Insufficient / overpayment banners for pending orders
          if (stage == 'PENDING_CASHIER' ||
              stage.isEmpty) ...[
            if (amountReceived > 0 &&
                amountReceived < o.total)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient Payment — Received ₱${amountReceived.toStringAsFixed(2)} of ₱${o.total.toStringAsFixed(2)} (₱${(o.total - amountReceived).toStringAsFixed(2)} short)',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (amountReceived > o.total)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade800,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Overpayment — Received ₱${amountReceived.toStringAsFixed(2)} (₱${(amountReceived - o.total).toStringAsFixed(2)} over)',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // GCash reference numbers
          if ((raw['payment_reference_initial'] ?? '').toString().isNotEmpty)
            _detailRow('Ref# (Initial)', raw['payment_reference_initial'].toString()),
          if ((raw['payment_reference_balance'] ?? '').toString().isNotEmpty)
            _detailRow('Ref# (Balance)', raw['payment_reference_balance'].toString()),

          // Amount Paid / Change
          if ((raw['cashier_amount_received'] ?? raw['amount_paid']) != null)
            _detailRow('Amount Paid', '₱${_toMoney(raw['cashier_amount_received'] ?? raw['amount_paid'] ?? 0).toStringAsFixed(2)}'),
          if ((raw['cashier_secondary_amount_received'] ?? raw['cashier_amount_received_balance']) != null &&
              _toMoney(raw['cashier_secondary_amount_received'] ?? raw['cashier_amount_received_balance'] ?? 0) > 0)
            _detailRow('Balance Received', '₱${_toMoney(raw['cashier_secondary_amount_received'] ?? raw['cashier_amount_received_balance'] ?? 0).toStringAsFixed(2)}'),
          if ((raw['change_given']) != null && _toMoney(raw['change_given'] ?? 0) > 0)
            _detailRow('Change', '₱${_toMoney(raw['change_given'] ?? 0).toStringAsFixed(2)}'),

          // Initial payment proof
          if (proofB64 != null && proofB64.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Initial Payment Proof',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 8),
            buildPaymentProofPreview(proofB64, height: 200),
          ],

          // Balance payment proof
          if ((raw['payment_proof_balance'] ?? raw['supplemental_payment_proof'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Balance Payment Proof',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 8),
            buildPaymentProofPreview(
              (raw['payment_proof_balance'] ?? raw['supplemental_payment_proof'])
                  ?.toString(),
              height: 200,
            ),
          ],

          const Divider(height: 24),
          const Text('Items',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          ...lines.map((l) => _buildOrderItemRow(l)),
        ],
      ),
    ),
    );
  }

  Widget _buildOnlineDetailActions(PosOrderView o) {
    final stage = o.fulfillmentStage.toUpperCase();
    final status = o.status.toUpperCase();

    if ((stage == 'PENDING_CASHIER' ||
            stage.isEmpty ||
            stage == 'BALANCE_PAYMENT_PENDING_REVIEW' ||
            stage == 'PAYMENT_INSUFFICIENT' ||
            o.balanceProofPending) &&
        !status.contains('CANCEL')) {
      final isBalanceReview =
          stage == 'BALANCE_PAYMENT_PENDING_REVIEW' || o.balanceProofPending;
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AntdTokens.success,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
        ),
        onPressed: () => _confirmPayment(o),
        icon: const Icon(Icons.check, size: 16),
        label: Text(
          isBalanceReview ? 'Confirm Balance Payment' : 'Confirm Payment',
        ),
      );
    }
    if (stage == 'OUT_FOR_DELIVERY' || status.contains('OUT FOR DELIVERY')) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AntdTokens.success,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
        ),
        onPressed: () => _markDelivered(o),
        icon: const Icon(Icons.check_circle, size: 16),
        label: const Text('Mark as Delivered'),
      );
    }
    if (stage == 'IN_PREPARATION' ||
        status.contains('ORDER CONFIRMED')) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AntdTokens.info,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
        ),
        onPressed: () => _showOutForDeliveryDialog(o),
        icon: const Icon(Icons.local_shipping, size: 16),
        label: const Text('Out for Delivery'),
      );
    }
    return const SizedBox.shrink();
  }

  // =========================================================================
  // TAB 2 — WALK-IN ORDERS (split: list LEFT, detail RIGHT)
  // =========================================================================

  Widget _buildWalkInTab() {
    final qLower = _walkSearch.trim().toLowerCase();

    List<Map<String, dynamic>> filterList(
        List<Map<String, dynamic>> list) {
      if (qLower.isEmpty) return list;
      return list.where((raw) {
        final o = PosOrderView(raw);
        return o.orderNo.toLowerCase().contains(qLower) ||
            (raw['pos_customer_label'] ?? '')
                .toString()
                .toLowerCase()
                .contains(qLower);
      }).toList();
    }

    final preparing = filterList(_walkInPreparing);
    final claimed = filterList(_walkInClaimed);
    final cancelled = filterList(_walkInCancelled);

    final subTabs = ['Preparing', 'Claimed', 'Cancelled'];
    final subLists = [preparing, claimed, cancelled];

    final listPanel = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search order no, label…',
                    isDense: true,
                    prefixIcon:
                        const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                  ),
                  onChanged: (v) =>
                      setState(() => _walkSearch = v),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshWalkIn),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12),
            itemCount: subTabs.length,
            itemBuilder: (_, i) {
              final active = _walkInSubTab == i;
              final count = subLists[i].length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label:
                      Text('${subTabs[i]} ($count)'),
                  selected: active,
                  selectedColor:
                      AntdTokens.brandPrimary.withAlpha(80),
                  onSelected: (_) => setState(() {
                    _walkInSubTab = i;
                    _selectedWalkIn = null;
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: subLists[_walkInSubTab].isEmpty
              ? const Center(
                  child:
                      Text('No orders in this stage.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount:
                      subLists[_walkInSubTab].length,
                  itemBuilder: (_, i) {
                    final raw =
                        subLists[_walkInSubTab][i];
                    final selected =
                        _selectedWalkIn != null &&
                            _selectedWalkIn!['id'] ==
                                raw['id'];
                    return _buildWalkInListTile(
                        raw, selected);
                  },
                ),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(flex: 2, child: listPanel),
        Container(
            width: 1, color: Colors.grey.shade300),
        Expanded(
            flex: 3,
            child: _buildWalkInDetailPanel()),
      ],
    );
  }

  Widget _buildWalkInListTile(
      Map<String, dynamic> raw, bool isSelected) {
    final o = PosOrderView(raw);
    final label =
        raw['pos_customer_label']?.toString() ?? '';
    final paymentMode = (raw['payment_method'] ??
            raw['payment_mode'] ??
            '')
        .toString()
        .toUpperCase();

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? AntdTokens.brandPrimary.withAlpha(30)
          : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () =>
            setState(() => _selectedWalkIn = raw),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              12, 10, 12, 10),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (label.isNotEmpty)
                    Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 14)))
                  else
                    Expanded(
                        child: Text(o.orderNo,
                            style: const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 13))),
                  Text(
                      '₱${o.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
              if (label.isNotEmpty)
                Text(o.orderNo,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade700)),
              if (paymentMode.isNotEmpty)
                Text(paymentMode,
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            Colors.grey.shade600)),
              const SizedBox(height: 4),
              _paymentAmountSummary(raw, walkIn: true) ??
                  Text(
                    'Amount due: ₱${o.total.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalkInDetailPanel() {
    if (_selectedWalkIn == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long,
                size: 64,
                color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
                'Select a walk-in order to view details',
                style: TextStyle(
                    color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    final raw = _selectedWalkIn!;
    final o = PosOrderView(raw);
    final label =
        raw['pos_customer_label']?.toString() ?? '';
    final createdAt =
        raw['created_at']?.toString() ?? '';
    final paymentMode = (raw['payment_method'] ??
            raw['payment_mode'] ??
            '')
        .toString();
    final note = raw['note']?.toString() ?? '';
    final lines = _orderItems(raw);
    final isPreparing = _walkInSubTab == 0;
    final proofB64 = (raw['payment_proof'] ??
            raw['payment_proof_initial'])
        ?.toString();

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (label.isNotEmpty)
                      Text(label,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w800)),
                    Text(o.orderNo,
                        style: TextStyle(
                            fontSize: label.isNotEmpty
                                ? 14
                                : 20,
                            fontWeight:
                                FontWeight.w700)),
                  ],
                ),
              ),
              if (isPreparing)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          _cancelWalkIn(raw),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          _claimWalkIn(raw),
                      child: const Text('Claim'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('Total',
              '₱${o.total.toStringAsFixed(2)}'),
          _detailRow(
              'Payment',
              paymentMode.isNotEmpty
                  ? paymentMode
                  : '—'),
          if (createdAt.isNotEmpty)
            _detailRow('Submitted', createdAt),
          if (note.isNotEmpty)
            _detailRow('Note', note),
          if ((raw['payment_reference_initial'] ?? '').toString().isNotEmpty)
            _detailRow('Ref#', raw['payment_reference_initial'].toString()),
          if ((raw['cashier_amount_received'] ?? raw['amount_paid']) != null)
            _detailRow('Amount Paid', '₱${_toMoney(raw['cashier_amount_received'] ?? raw['amount_paid'] ?? 0).toStringAsFixed(2)}'),
          if ((raw['amount_received']) != null && _toMoney(raw['amount_received'] ?? 0) > 0)
            _detailRow('Amount Received', '₱${_toMoney(raw['amount_received'] ?? 0).toStringAsFixed(2)}'),
          if ((raw['change_given']) != null && _toMoney(raw['change_given'] ?? 0) > 0)
            _detailRow('Change', '₱${_toMoney(raw['change_given'] ?? 0).toStringAsFixed(2)}'),

          // Payment proof for walk-in orders
          if (proofB64 != null &&
              proofB64.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Payment Proof',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 8),
            buildPaymentProofPreview(proofB64, height: 200),
          ],

          const Divider(height: 24),
          const Text('Items',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 8),
          ...lines.map((l) => _buildOrderItemRow(l)),
        ],
      ),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _buildOrderItemRow(dynamic l) {
    final ln = l is Map ? l : <String, dynamic>{};
    final itemName =
        ln['item_name'] ?? ln['name'] ?? 'Item';
    final itemQty = ln['qty'] ?? 1;
    final itemPrice = _toMoney(
        ln['price'] ?? ln['unit_price'] ?? 0);
    final dip = ln['dip']?.toString() ?? '';
    final itemNote = ln['note']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.grey.shade100))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text('$itemName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                if (dip.isNotEmpty)
                  Text('Add-on: $dip',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey.shade600)),
                if (itemNote.isNotEmpty)
                  Text('Note: $itemNote',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey.shade500,
                          fontStyle:
                              FontStyle.italic)),
              ],
            ),
          ),
          Text('×$itemQty',
              style: const TextStyle(
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text(
              '₱${(itemPrice * (itemQty is num ? itemQty.toInt() : 1)).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13))),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, String label, String current) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (current == value)
            const Icon(Icons.check,
                size: 18,
                color: AntdTokens.brandPrimary),
          if (current == value)
            const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  Color _statusBadgeBg(String status) {
    final up = status.toUpperCase();
    if (up.contains('INSUFFICIENT'))
      return Colors.red.shade100;
    if (up.contains('CONFIRMED') ||
        up.contains('OVERPAYMENT'))
      return Colors.green.shade100;
    if (up.contains('CANCEL'))
      return Colors.grey.shade300;
    return Colors.orange.shade100;
  }

  Color _statusBadgeFg(String status) {
    final up = status.toUpperCase();
    if (up.contains('INSUFFICIENT'))
      return Colors.red.shade900;
    if (up.contains('CONFIRMED') ||
        up.contains('OVERPAYMENT'))
      return Colors.green.shade900;
    if (up.contains('CANCEL'))
      return Colors.grey.shade900;
    return Colors.orange.shade900;
  }
}
