import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../services/menu_store.dart';

class ArchivedTransaction {
  final String transactionNo;
  final String customerName;
  final String eventTitle;
  final String eventType;
  final String totalCost;
  final String loyaltyRewards;
  final String archiveDate;

  ArchivedTransaction({
    required this.transactionNo,
    required this.customerName,
    required this.eventTitle,
    required this.eventType,
    required this.totalCost,
    required this.loyaltyRewards,
    required this.archiveDate,
  });
}

class ArchivedDish {
  final String dishNo;
  final String dishName;
  final String variants;
  final String price;
  final String archiveDate;

  ArchivedDish({
    required this.dishNo,
    required this.dishName,
    required this.variants,
    required this.price,
    required this.archiveDate,
  });
}

class Archive extends StatelessWidget {
  const Archive({super.key});

  List<ArchivedDish> _archivedDishesFromStore() {
    return MenuStore.instance.archivedDishes.map((d) {
      final archivedAt = d.archivedAt;
      final archiveDate = archivedAt == null
          ? ''
          : '${archivedAt.month.toString().padLeft(2, '0')} ${archivedAt.day} ${archivedAt.year} ${archivedAt.hour.toString().padLeft(2, '0')}:${archivedAt.minute.toString().padLeft(2, '0')}';
      return ArchivedDish(
        dishNo: d.id,
        dishName: d.name,
        variants: d.paxOptions.join(', '),
        price: '₱${d.price}',
        archiveDate: archiveDate,
      );
    }).toList();
  }

  Widget _buildTable<T>({
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(columns: columns, rows: rows),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MenuStore.instance,
      builder: (context, _) {
        final archivedDishes = _archivedDishesFromStore();
        return AppScaffold(
          showSearch: true,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Archive',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildTable<ArchivedTransaction>(
                        columns: const [
                          DataColumn(label: Text('Transaction No.')),
                          DataColumn(label: Text('Customer Name')),
                          DataColumn(label: Text('Event Title')),
                          DataColumn(label: Text('Event Type')),
                          DataColumn(label: Text('Total Cost')),
                          DataColumn(label: Text('Loyalty Rewards')),
                          DataColumn(label: Text('Archive Date')),
                        ],
                        rows: const <ArchivedTransaction>[]
                            .map(
                              (t) => DataRow(cells: [
                                DataCell(Text(t.transactionNo)),
                                DataCell(Text(t.customerName)),
                                DataCell(Text(t.eventTitle)),
                                DataCell(Text(t.eventType)),
                                DataCell(Text(t.totalCost)),
                                DataCell(Text(t.loyaltyRewards)),
                                DataCell(Text(t.archiveDate)),
                              ]),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      _buildTable<ArchivedDish>(
                        columns: const [
                          DataColumn(label: Text('Dish No.')),
                          DataColumn(label: Text('Dish Name')),
                          DataColumn(label: Text('Variants')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Archive Date')),
                        ],
                        rows: archivedDishes
                            .map(
                              (d) => DataRow(cells: [
                                DataCell(Text(d.dishNo)),
                                DataCell(Text(d.dishName)),
                                DataCell(Text(d.variants)),
                                DataCell(Text(d.price)),
                                DataCell(Text(d.archiveDate)),
                              ]),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
