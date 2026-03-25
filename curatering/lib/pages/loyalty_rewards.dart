import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/event_order.dart';
import '../services/events_api.dart';
import '../utils/order_calculations.dart';

class LoyaltyCustomer {
  final String name;
  final int points;

  LoyaltyCustomer({required this.name, required this.points});
}

class LoyaltyTransaction {
  final String transactionNo;
  final String title;
  final String customerName;
  final String eventType;
  final DateTime date;
  final String time;
  final int pointsEarned;
  final String reward;
  final String contactPerson;
  final String contactNumber;
  final String emailAddress;

  LoyaltyTransaction({
    required this.transactionNo,
    required this.title,
    required this.customerName,
    required this.eventType,
    required this.date,
    required this.time,
    required this.pointsEarned,
    required this.reward,
    required this.contactPerson,
    required this.contactNumber,
    required this.emailAddress,
  });
}

class LoyaltyRewards extends StatefulWidget {
  const LoyaltyRewards({super.key});

  @override
  State<LoyaltyRewards> createState() => _LoyaltyRewardsState();
}

class _LoyaltyRewardsState extends State<LoyaltyRewards> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = false;
  String? _errorMessage;

  List<EventOrderDto> _completedOrders = const <EventOrderDto>[];

  String? _selectedCustomerName;
  String? _selectedTransactionNo;

  @override
  void initState() {
    super.initState();
    _loadCompletedOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedOrders() async {
    final role = AuthSession.instance.currentRole;
    final roleType = role == Role.supervisor ? 'supervisor' : 'manager';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _completedOrders = await EventsApi.instance.listOrders(
        status: 'completed',
        roleType: roleType,
      );
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load loyalty data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsByCustomer = <String, int>{};
    for (final o in _completedOrders) {
      final totalCost = computeOrderTotalCost(o);
      final points = computeLoyaltyPointsFromCost(totalCost);
      pointsByCustomer[o.customerName] =
          (pointsByCustomer[o.customerName] ?? 0) + points;
    }

    final customers = pointsByCustomer.entries
        .map((e) => LoyaltyCustomer(name: e.key, points: e.value))
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    final customersFiltered = _searchQuery.isEmpty
        ? customers
        : customers
            .where((c) => c.name.toLowerCase().contains(_searchQuery))
            .toList();

    final selectedCustomerName = _selectedCustomerName;
    final selectedCustomerStillVisible =
        selectedCustomerName != null &&
                customersFiltered.any((c) => c.name == selectedCustomerName)
            ? selectedCustomerName
            : (customersFiltered.isNotEmpty ? customersFiltered.first.name : null);

    final transactions = (selectedCustomerStillVisible == null)
        ? <LoyaltyTransaction>[]
        : _completedOrders
            .where((o) => o.customerName == selectedCustomerStillVisible)
            .where((o) {
              if (_searchQuery.isEmpty) return true;
              final haystack = '${o.eventTitle} ${o.eventType}'.toLowerCase();
              return haystack.contains(_searchQuery);
            })
            .map((o) {
              final totalCost = computeOrderTotalCost(o);
              final pointsEarned = computeLoyaltyPointsFromCost(totalCost);
              final date = o.scheduleSlots.isNotEmpty
                  ? DateTime.parse(o.scheduleSlots.first.date)
                  : DateTime.now();
              final time = o.scheduleSlots.isNotEmpty
                  ? '${o.scheduleSlots.first.startTime} - ${o.scheduleSlots.first.endTime}'
                  : '';
              // Dev placeholder until backend stores reward rules.
              final reward = pointsEarned > 0
                  ? 'Reward rules not implemented (dev)'
                  : 'N/A';
              return LoyaltyTransaction(
                transactionNo: o.id,
                title: o.eventTitle,
                customerName: o.customerName,
                eventType: o.eventType,
                date: date,
                time: time,
                pointsEarned: pointsEarned,
                reward: reward,
                contactPerson: o.contactPerson,
                contactNumber: o.contactNumber,
                emailAddress: o.emailAddress,
              );
            })
            .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final selectedTransaction = _selectedTransactionNo == null
        ? null
        : transactions.where((t) => t.transactionNo == _selectedTransactionNo).isNotEmpty
            ? transactions.firstWhere((t) => t.transactionNo == _selectedTransactionNo)
            : null;

    if (_isLoading) {
      return AppScaffold(
        showSearch: true,
        searchController: _searchController,
        onSearchChanged: (v) =>
            setState(() => _searchQuery = v.trim().toLowerCase()),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return AppScaffold(
        showSearch: true,
        searchController: _searchController,
        onSearchChanged: (v) =>
            setState(() => _searchQuery = v.trim().toLowerCase()),
        child: Center(
          child: Text(
            _errorMessage!,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1100;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loyalty Rewards',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isNarrow
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCustomersSection(
                                customersFiltered,
                                selectedCustomerStillVisible,
                              ),
                              const SizedBox(height: 20),
                              _buildTransactionsSection(
                                transactions,
                                selectedCustomerStillVisible,
                                _selectedTransactionNo,
                              ),
                              const SizedBox(height: 20),
                              _buildTransactionInfoSection(selectedTransaction),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildCustomersSection(
                                customersFiltered,
                                selectedCustomerStillVisible,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 3,
                              child: _buildTransactionsSection(
                                transactions,
                                selectedCustomerStillVisible,
                                _selectedTransactionNo,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: _buildTransactionInfoSection(selectedTransaction),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomersSection(
    List<LoyaltyCustomer> customers,
    String? selectedCustomerName,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CUSTOMERS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (customers.isEmpty)
              Center(
                child: Text(
                  'No customers yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              Column(
                children: customers.map((customer) {
                  final isSelected = customer.name == selectedCustomerName;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCustomerName = customer.name;
                        _selectedTransactionNo = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade50
                            : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(customer.name),
                          Text(
                            '${customer.points} pts',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(
    List<LoyaltyTransaction> transactions,
    String? selectedCustomerName,
    String? selectedTransactionNo,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CUSTOMER TRANSACTIONS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (selectedCustomerName == null)
              Text(
                'Select a customer to see transactions.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else if (transactions.isEmpty)
              Text(
                'No transactions found.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: transactions.map((tx) {
                  final isSelected = tx.transactionNo == selectedTransactionNo;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTransactionNo = tx.transactionNo;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Colors.blue.shade50 : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(tx.title),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${tx.date.month}/${tx.date.day}/${tx.date.year}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              Text(
                                tx.time,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionInfoSection(LoyaltyTransaction? selectedTransaction) {
    if (selectedTransaction == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRANSACTION INFORMATION',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a transaction to view details.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final tx = selectedTransaction;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TRANSACTION INFORMATION',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Event Title', tx.title),
            _buildInfoRow('Event Type', tx.eventType),
            _buildInfoRow('Customer', tx.customerName),
            _buildInfoRow('Contact Person', tx.contactPerson),
            _buildInfoRow('Contact Number', tx.contactNumber),
            _buildInfoRow('Email Address', tx.emailAddress),
            _buildInfoRow(
              'Date of Event',
              '${tx.date.month.toString().padLeft(2, '0')}/${tx.date.day.toString().padLeft(2, '0')}/${tx.date.year}',
            ),
            _buildInfoRow('Time', tx.time),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Transaction No. ${tx.transactionNo}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              'Loyalty Points Obtained',
              '+${tx.pointsEarned} pts',
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Reward', tx.reward),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
