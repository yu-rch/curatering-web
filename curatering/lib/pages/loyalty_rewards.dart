import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class LoyaltyCustomer {
  final String name;
  final int points;

  LoyaltyCustomer({required this.name, required this.points});
}

class LoyaltyTransaction {
  final String title;
  final DateTime date;
  final String time;
  final int pointsEarned;
  final String reward;

  LoyaltyTransaction({
    required this.title,
    required this.date,
    required this.time,
    required this.pointsEarned,
    required this.reward,
  });
}

class LoyaltyRewards extends StatefulWidget {
  const LoyaltyRewards({super.key});

  @override
  State<LoyaltyRewards> createState() => _LoyaltyRewardsState();
}

class _LoyaltyRewardsState extends State<LoyaltyRewards> {
  final List<LoyaltyCustomer> _customers = [
    LoyaltyCustomer(name: 'Guess Inc.', points: 356),
    LoyaltyCustomer(name: 'Guess Inc.', points: 455),
    LoyaltyCustomer(name: 'Guess Inc.', points: 109),
    LoyaltyCustomer(name: 'Guess Inc.', points: 56),
  ];

  final Map<String, List<LoyaltyTransaction>> _transactionsByCustomer = {
    'Guess Inc.': [
      LoyaltyTransaction(
        title: "Queenie's 18th Birthday",
        date: DateTime(2026, 2, 24),
        time: '1:23 PM',
        pointsEarned: 122,
        reward: 'Shrimp Tempura - half tray',
      ),
    ],
  };

  LoyaltyCustomer? _selectedCustomer;
  LoyaltyTransaction? _selectedTransaction;

  @override
  Widget build(BuildContext context) {
    final transactions = _selectedCustomer == null
        ? <LoyaltyTransaction>[]
        : _transactionsByCustomer[_selectedCustomer!.name] ?? [];

    return AppScaffold(
      showSearch: true,
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
                              _buildCustomersSection(),
                              const SizedBox(height: 20),
                              _buildTransactionsSection(transactions),
                              const SizedBox(height: 20),
                              _buildTransactionInfoSection(),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildCustomersSection()),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 3,
                              child: _buildTransactionsSection(transactions),
                            ),
                            const SizedBox(width: 20),
                            Expanded(flex: 4, child: _buildTransactionInfoSection()),
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

  Widget _buildCustomersSection() {
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
            if (_customers.isEmpty)
              Center(
                child: Text(
                  'No customers yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              Column(
                children: _customers.map((customer) {
                  final isSelected = _selectedCustomer == customer;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCustomer = customer;
                        _selectedTransaction = null;
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

  Widget _buildTransactionsSection(List<LoyaltyTransaction> transactions) {
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
            if (_selectedCustomer == null)
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
                  final isSelected = _selectedTransaction == tx;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTransaction = tx;
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

  Widget _buildTransactionInfoSection() {
    if (_selectedTransaction == null) {
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

    final tx = _selectedTransaction!;
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
            _buildInfoRow('Event Type', 'Birthday'),
            _buildInfoRow('Customer', _selectedCustomer?.name ?? ''),
            _buildInfoRow('Contact Person', 'Jacklyn Perez'),
            _buildInfoRow('Contact Number', '09355479221'),
            _buildInfoRow('Email Address', 'jperez@gmail.com'),
            _buildInfoRow('Date of Event', 'APR 10 2026'),
            _buildInfoRow('Time', '1:00 - 3:00 PM'),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Transaction No. 887766443399',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Loyalty Points Obtained', '+122 pts'),
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
