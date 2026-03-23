import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class TransactionItem {
  final String transactionNo;
  final String customerName;
  final String eventTitle;
  final String eventType;
  final String totalCost;
  final String loyaltyRewards;

  TransactionItem({
    required this.transactionNo,
    required this.customerName,
    required this.eventTitle,
    required this.eventType,
    required this.totalCost,
    required this.loyaltyRewards,
  });
}

class Transactions extends StatefulWidget {
  const Transactions({super.key});

  @override
  State<Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<Transactions> {
  DateTime _selectedDate = DateTime(2026, 1, 10);

  final List<TransactionItem> _transactions = [
    TransactionItem(
      transactionNo: 'T000003',
      customerName: 'Jacklyn Perez',
      eventTitle: "Queenie's 18th Birthday",
      eventType: 'Birthday',
      totalCost: '₱25000',
      loyaltyRewards: '+122 pts',
    ),
  ];

  Widget _dateTile(DateTime date) {
    final isSelected = date == _selectedDate;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade400 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month.toString().padLeft(2, '0')} ${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][date.weekday % 7],
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _dateTile(_selectedDate),
                        const SizedBox(height: 12),
                        _dateTile(DateTime(2026, 1, 9)),
                        const SizedBox(height: 12),
                        _dateTile(DateTime(2026, 1, 8)),
                        const SizedBox(height: 12),
                        _dateTile(DateTime(2026, 1, 7)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transactions',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            if (_transactions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    'No transactions available yet.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Transaction No.')),
                                    DataColumn(label: Text('Customer Name')),
                                    DataColumn(label: Text('Event Title')),
                                    DataColumn(label: Text('Event Type')),
                                    DataColumn(label: Text('Total Cost')),
                                    DataColumn(label: Text('Loyalty Rewards')),
                                  ],
                                  rows: _transactions.map((tx) {
                                    return DataRow(cells: [
                                      DataCell(Text(tx.transactionNo)),
                                      DataCell(Text(tx.customerName)),
                                      DataCell(Text(tx.eventTitle)),
                                      DataCell(Text(tx.eventType)),
                                      DataCell(Text(tx.totalCost)),
                                      DataCell(Text(tx.loyaltyRewards)),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
