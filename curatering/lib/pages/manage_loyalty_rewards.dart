import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

// Models for Points Condition
class PointsCondition {
  String? id;
  double minimumCost;
  int pointsApplication;
  bool isActive;

  PointsCondition({
    this.id,
    required this.minimumCost,
    required this.pointsApplication,
    this.isActive = true,
  });
}

// Models for Rewards Condition
class RewardsCondition {
  String? id;
  int minimumPoints;
  int maximumPoints;
  String reward;
  String size;
  bool isActive;

  RewardsCondition({
    this.id,
    required this.minimumPoints,
    required this.maximumPoints,
    required this.reward,
    required this.size,
    this.isActive = true,
  });
}

// Customer with loyalty points
class LoyaltyCustomer {
  String id;
  String name;
  int points;

  LoyaltyCustomer({
    required this.id,
    required this.name,
    required this.points,
  });
}

// Customer Transaction
class CustomerTransaction {
  String transactionNo;
  String eventTitle;
  String dateTime;
  double totalCost;
  int loyaltyPointsObtained;
  int totalLoyaltyPoints;
  String reward;

  CustomerTransaction({
    required this.transactionNo,
    required this.eventTitle,
    required this.dateTime,
    required this.totalCost,
    required this.loyaltyPointsObtained,
    required this.totalLoyaltyPoints,
    required this.reward,
  });
}

class ManageLoyaltyRewards extends StatefulWidget {
  const ManageLoyaltyRewards({Key? key}) : super(key: key);

  @override
  State<ManageLoyaltyRewards> createState() => _ManageLoyaltyRewardsState();
}

class _ManageLoyaltyRewardsState extends State<ManageLoyaltyRewards> {
  bool _showCustomersTab = true;
  String? _selectedCustomerId;
  
  // Sample data - replace with API calls
  final List<LoyaltyCustomer> _customers = [
    LoyaltyCustomer(id: '1', name: 'Guess Inc.', points: 356),
    LoyaltyCustomer(id: '2', name: 'Guess Inc.', points: 455),
    LoyaltyCustomer(id: '3', name: 'Guess Inc.', points: 109),
    LoyaltyCustomer(id: '4', name: 'Guess Inc.', points: 56),
  ];

  final List<PointsCondition> _pointsConditions = [
    PointsCondition(id: '1', minimumCost: 2000.00, pointsApplication: 50),
  ];

  final List<RewardsCondition> _rewardsConditions = [
    RewardsCondition(
      id: '1',
      minimumPoints: 1000,
      maximumPoints: 1500,
      reward: 'Shrimp Tempura',
      size: '50 pcs',
    ),
  ];

  final List<CustomerTransaction> _transactions = [
    CustomerTransaction(
      transactionNo: '887766443399',
      eventTitle: "Queenie's 18th Birthday",
      dateTime: 'Feb 24 2026 1:23 PM',
      totalCost: 25000,
      loyaltyPointsObtained: 122,
      totalLoyaltyPoints: 1022,
      reward: 'Shrimp Tempura half tray',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      child: Row(
        children: [
          // Left sidebar - Manage Points and Rewards
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MANAGE POINTS AND',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'REWARDS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab buttons
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showCustomersTab = true;
                              _selectedCustomerId = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showCustomersTab
                                ? const Color(0xFFFFC107)
                                : Colors.grey.shade200,
                            foregroundColor: Colors.black,
                            elevation: 0,
                          ),
                          child: const Text('CUSTOMERS'),
                        ),
                      ),
                    ],
                  ),
                ),
                // ALL header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'ALL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Customer list
                Expanded(
                  child: ListView.builder(
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      final isSelected = _selectedCustomerId == customer.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.grey.shade200,
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Text(
                          '${customer.points} pts',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = customer.id;
                            _showCustomersTab = true;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: _showCustomersTab && _selectedCustomerId != null
                ? _buildCustomerTransactionsView()
                : _buildPointsAndRewardsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsAndRewardsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // POINTS Section
          _buildSectionHeader('POINTS', () => _showAddPointsConditionDialog()),
          const SizedBox(height: 16),
          _buildPointsTable(),
          const SizedBox(height: 32),
          // REWARDS Section
          _buildSectionHeader('REWARDS', () => _showAddRewardsConditionDialog()),
          const SizedBox(height: 16),
          _buildRewardsTable(),
        ],
      ),
    );
  }

  Widget _buildCustomerTransactionsView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'CUSTOMER TRANSACTIONS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildCustomerTransactionsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAddPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Condition'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPointsTable() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Minimum Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Points Application', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // Rows
          ..._pointsConditions.map((condition) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('₱${condition.minimumCost.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${condition.pointsApplication} pts'),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.red, size: 20),
                          onPressed: () => _showEditPointsConditionDialog(condition),
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive, color: Colors.orange, size: 20),
                          onPressed: () => _showArchivePointsDialog(condition),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRewardsTable() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Minimum Points', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Maximum Points', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Reward', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // Rows
          ..._rewardsConditions.map((condition) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('${condition.minimumPoints} pts'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${condition.maximumPoints} pts'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(condition.reward),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(condition.size),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.red, size: 20),
                          onPressed: () => _showEditRewardsConditionDialog(condition),
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive, color: Colors.orange, size: 20),
                          onPressed: () => _showArchiveRewardsDialog(condition),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCustomerTransactionsTable() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Transaction No.', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Event Title', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Loyalty Points\nObtained', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Total Loyalty\nPoints', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Reward', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // Rows
          ..._transactions.map((transaction) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(transaction.transactionNo)),
                  Expanded(flex: 2, child: Text(transaction.eventTitle)),
                  Expanded(flex: 2, child: Text(transaction.dateTime)),
                  Expanded(flex: 1, child: Text('₱${transaction.totalCost}')),
                  Expanded(flex: 1, child: Text('+${transaction.loyaltyPointsObtained} pts')),
                  Expanded(flex: 1, child: Text('${transaction.totalLoyaltyPoints} pts')),
                  Expanded(flex: 2, child: Text(transaction.reward)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Dialogs
  void _showAddPointsConditionDialog() {
    final minimumCostController = TextEditingController(text: '2000.00');
    final pointsController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('POINTS - Add Condition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Minimum Cost')),
                Expanded(
                  child: TextField(
                    controller: minimumCostController,
                    decoration: const InputDecoration(
                      prefixText: '₱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Points Application')),
                Expanded(
                  child: TextField(
                    controller: pointsController,
                    decoration: const InputDecoration(
                      suffixText: 'pts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pointsConditions.add(PointsCondition(
                  id: DateTime.now().toString(),
                  minimumCost: double.tryParse(minimumCostController.text) ?? 0,
                  pointsApplication: int.tryParse(pointsController.text) ?? 0,
                ));
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('SAVE'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showEditPointsConditionDialog(PointsCondition condition) {
    final minimumCostController = TextEditingController(text: condition.minimumCost.toStringAsFixed(2));
    final pointsController = TextEditingController(text: condition.pointsApplication.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('POINTS - Edit Condition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Minimum Cost')),
                Expanded(
                  child: TextField(
                    controller: minimumCostController,
                    decoration: const InputDecoration(
                      prefixText: '₱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Points Application')),
                Expanded(
                  child: TextField(
                    controller: pointsController,
                    decoration: const InputDecoration(
                      suffixText: 'pts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                condition.minimumCost = double.tryParse(minimumCostController.text) ?? 0;
                condition.pointsApplication = int.tryParse(pointsController.text) ?? 0;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('SAVE'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showArchivePointsDialog(PointsCondition condition) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to ARCHIVE this condition?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Minimum Cost')),
                Text('₱${condition.minimumCost.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Points')),
                Text('${condition.pointsApplication} pts'),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                condition.isActive = false;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('YES'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showAddRewardsConditionDialog() {
    final minPointsController = TextEditingController(text: '1000');
    final maxPointsController = TextEditingController(text: '1500');
    final rewardController = TextEditingController(text: 'Shrimp Tempura');
    final sizeController = TextEditingController(text: '50 pcs');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REWARDS - Add Condition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Minimum Points')),
                Expanded(
                  child: TextField(
                    controller: minPointsController,
                    decoration: const InputDecoration(
                      suffixText: 'pts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Maximum Points')),
                Expanded(
                  child: TextField(
                    controller: maxPointsController,
                    decoration: const InputDecoration(
                      suffixText: 'pts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Reward')),
                Expanded(
                  child: TextField(
                    controller: rewardController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Size')),
                Expanded(
                  child: TextField(
                    controller: sizeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _rewardsConditions.add(RewardsCondition(
                  id: DateTime.now().toString(),
                  minimumPoints: int.tryParse(minPointsController.text) ?? 0,
                  maximumPoints: int.tryParse(maxPointsController.text) ?? 0,
                  reward: rewardController.text,
                  size: sizeController.text,
                ));
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('SAVE'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showEditRewardsConditionDialog(RewardsCondition condition) {
    final minPointsController = TextEditingController(text: condition.minimumPoints.toString());
    final maxPointsController = TextEditingController(text: condition.maximumPoints.toString());
    final rewardController = TextEditingController(text: condition.reward);
    final sizeController = TextEditingController(text: condition.size);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REWARDS - Edit Condition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Minimum Points')),
                Expanded(
                  child: TextField(
                    controller: minPointsController,
                    decoration: const InputDecoration(
                      suffixText: 'pts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Maximum Points')),
                Expanded(
                  child: TextField(
                    controller: maxPointsController,
                    decoration: const InputDecoration(
                      suffixText: 'pts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Reward')),
                Expanded(
                  child: TextField(
                    controller: rewardController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Size')),
                Expanded(
                  child: TextField(
                    controller: sizeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                condition.minimumPoints = int.tryParse(minPointsController.text) ?? 0;
                condition.maximumPoints = int.tryParse(maxPointsController.text) ?? 0;
                condition.reward = rewardController.text;
                condition.size = sizeController.text;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('SAVE'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showArchiveRewardsDialog(RewardsCondition condition) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to ARCHIVE this condition?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Minimum Points')),
                Text('${condition.minimumPoints} pts'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Maximum Points')),
                Text('${condition.maximumPoints} pts'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Reward')),
                Text(condition.reward),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 100, child: Text('Size')),
                Text(condition.size),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                condition.isActive = false;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('YES'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }
}
