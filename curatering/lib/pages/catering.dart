import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';
import '../utils/web_html.dart' as html;

enum EventStatus {
  newEvent,
  onlineInquiries,
  forProcessing,
  forPostAnalysis,
  completed,
}

class Dish {
  final String name;
  final String price;
  final List<String> paxOptions;

  const Dish({
    required this.name,
    required this.price,
    required this.paxOptions,
  });
}

class MenuItem {
  final Dish dish;
  final String paxOption;

  MenuItem({required this.dish, required this.paxOption});
}

class ManageEvents extends StatefulWidget {
  const ManageEvents({super.key});

  @override
  State<ManageEvents> createState() => _ManageEventsState();
}

class ProcessingOrder {
  final String company;
  final String contactName;
  final String contactNumber;
  final DateTime date;
  final String time;

  ProcessingOrder({
    required this.company,
    required this.contactName,
    required this.contactNumber,
    required this.date,
    required this.time,
  });
}

class _ManageEventsState extends State<ManageEvents> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _eventSearchController = TextEditingController();
  final TextEditingController _inquirySearchController =
      TextEditingController();
  final TextEditingController _foodSearchController = TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  EventStatus _selectedStatus = EventStatus.newEvent;
  DateTime? _eventDate;
  String? _eventType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: EventStatus.values.length,
      vsync: this,
      initialIndex: _selectedStatus.index,
    )..addListener(() {
        if (!_tabController.indexIsChanging) return;
        final newStatus = EventStatus.values[_tabController.index];
        setState(() {
          _selectedStatus = newStatus;
          if (newStatus != EventStatus.forProcessing) {
            _selectedProcessingOrder = null;
          }
          if (newStatus != EventStatus.forPostAnalysis) {
            _selectedPostAnalysisOrder = null;
          }
          if (newStatus != EventStatus.completed) {
            _selectedCompletedOrder = null;
          }
        });
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventSearchController.dispose();
    _inquirySearchController.dispose();
    _foodSearchController.dispose();
    _eventTitleController.dispose();
    _customerController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  ProcessingOrder? _selectedProcessingOrder;
  final List<ProcessingOrder> _mockProcessingOrders = [
    ProcessingOrder(
      company: 'Guess Inc.',
      contactName: 'Mary Joyce Reyes',
      contactNumber: '09878845690',
      date: DateTime(2026, 2, 24),
      time: '1:00 - 3:00 PM',
    ),
    ProcessingOrder(
      company: 'Tech Solutions',
      contactName: 'John Doe',
      contactNumber: '09123456789',
      date: DateTime(2026, 2, 25),
      time: '10:00 AM - 12:00 PM',
    ),
    ProcessingOrder(
      company: 'Food Fest',
      contactName: 'Jane Smith',
      contactNumber: '09987654321',
      date: DateTime(2026, 2, 26),
      time: '2:00 - 5:00 PM',
    ),
  ];

  ProcessingOrder? _selectedPostAnalysisOrder;
  final List<ProcessingOrder> _mockPostAnalysisOrders = [
    ProcessingOrder(
      company: 'Guess Inc.',
      contactName: 'Mary Joyce Reyes',
      contactNumber: '09878845690',
      date: DateTime(2026, 2, 24),
      time: '1:00 - 3:00 PM',
    ),
    ProcessingOrder(
      company: 'Acme Events',
      contactName: 'Juan Dela Cruz',
      contactNumber: '09171234567',
      date: DateTime(2026, 2, 25),
      time: '2:00 - 4:00 PM',
    ),
    ProcessingOrder(
      company: 'Global Corp',
      contactName: 'Alice Johnson',
      contactNumber: '09234567890',
      date: DateTime(2026, 2, 27),
      time: '11:00 AM - 1:00 PM',
    ),
  ];

  ProcessingOrder? _selectedCompletedOrder;
  final List<ProcessingOrder> _mockCompletedOrders = [
    ProcessingOrder(
      company: 'Guess Inc.',
      contactName: 'Mary Joyce Reyes',
      contactNumber: '09878845690',
      date: DateTime(2026, 2, 24),
      time: '1:00 - 3:00 PM',
    ),
    ProcessingOrder(
      company: 'Acme Events',
      contactName: 'Juan Dela Cruz',
      contactNumber: '09171234567',
      date: DateTime(2026, 2, 25),
      time: '2:00 - 4:00 PM',
    ),
    ProcessingOrder(
      company: 'Innovate Ltd',
      contactName: 'Bob Wilson',
      contactNumber: '09345678901',
      date: DateTime(2026, 2, 28),
      time: '3:00 - 6:00 PM',
    ),
  ];

  final List<ProcessingOrder> _mockNewEvents = [
    ProcessingOrder(
      company: 'Wedding Celebration',
      contactName: 'Anna Garcia',
      contactNumber: '09123456789',
      date: DateTime(2026, 3, 15),
      time: '4:00 - 8:00 PM',
    ),
    ProcessingOrder(
      company: 'Birthday Party',
      contactName: 'Carlos Reyes',
      contactNumber: '09987654321',
      date: DateTime(2026, 3, 18),
      time: '6:00 - 9:00 PM',
    ),
  ];

  List<Uint8List> _themeDesignImages = [];

  final List<MenuItem> _menuItems = [];
  final Map<String, String> _selectedPaxPerDish = {};

  static const _eventTypes = [
    'Wedding',
    'Birthday',
    'Corporate',
    'Private Party',
    'Other',
  ];

  static const _allDishes = [
    Dish(
      name: 'Bistek',
      price: '₱100.00',
      paxOptions: ['1 pax', '10 pax', '15-25 pax', '25-30 pax', '30-40 pax'],
    ),
    Dish(
      name: 'Sinigang',
      price: '₱120.00',
      paxOptions: ['1 pax', '10 pax', '15-25 pax', '25-30 pax', '30-40 pax'],
    ),
    Dish(
      name: 'Lechon Kawali',
      price: '₱250.00',
      paxOptions: ['1 pax', '10 pax', '15-25 pax', '25-30 pax', '30-40 pax'],
    ),
    Dish(
      name: 'Kare-Kare',
      price: '₱200.00',
      paxOptions: ['1 pax', '10 pax', '15-25 pax', '25-30 pax', '30-40 pax'],
    ),
  ];

  List<Dish> get _filteredDishes {
    final query = _foodSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allDishes;
    return _allDishes
        .where((d) => d.name.toLowerCase().contains(query))
        .toList();
  }

  void _resetForm() {
    setState(() {
      _eventTitleController.clear();
      _customerController.clear();
      _contactPersonController.clear();
      _contactNumberController.clear();
      _emailController.clear();
      _eventDate = null;
      _eventType = null;
      _menuItems.clear();
      _selectedPaxPerDish.clear();
      _selectedProcessingOrder = null;
      _selectedPostAnalysisOrder = null;
      _selectedCompletedOrder = null;
      _themeDesignImages.clear();
      _selectedStatus = EventStatus.newEvent;
      _eventSearchController.clear();
      _foodSearchController.clear();
    });
  }

  void _addToMenu(Dish dish) {
    final selectedPax = _selectedPaxPerDish[dish.name] ?? dish.paxOptions.first;
    final existingIndex = _menuItems.indexWhere(
      (item) => item.dish.name == dish.name && item.paxOption == selectedPax,
    );
    if (existingIndex != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is already in your menu.')),
      );
      return;
    }

    setState(() {
      _menuItems.add(MenuItem(dish: dish, paxOption: selectedPax));
    });
  }

  void _removeFromMenu(MenuItem item) {
    setState(() {
      _menuItems.remove(item);
    });
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  String _statusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.onlineInquiries:
        return 'Online Inquiries';
      case EventStatus.forProcessing:
        return 'For Processing';
      case EventStatus.forPostAnalysis:
        return 'For Post-Analysis';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.newEvent:
        return 'New Event';
    }
  }

  Widget _buildOnlineInquiriesView(bool isNarrow) {
    final inquiryList = <Widget>[
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inquiry from ABC Events',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Contact Person: Juan Dela Cruz'),
              const Text('Contact Number: 09171234567'),
              const Text('Email: juan@example.com'),
              const Text('Event Type: Birthday'),
              const Text('Event Date: 2026-03-15'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4511E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ),
      ),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inquiry from XYZ Catering',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Contact Person: Maria Santos'),
              const Text('Contact Number: 09987654321'),
              const Text('Email: maria@example.com'),
              const Text('Event Type: Corporate'),
              const Text('Event Date: 2026-03-20'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4511E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Online Inquiries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inquirySearchController,
              decoration: InputDecoration(
                hintText: 'Search inquiries',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (inquiryList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No online inquiries to show yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(children: inquiryList),
          ],
        ),
      ),
    );

    final detailsSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inquiry Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Select an inquiry to view details.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4511E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('View inquiry'),
              ),
            ),
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [listSection, const SizedBox(height: 20), detailsSection],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: listSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: detailsSection,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingOrderCard(ProcessingOrder order, bool isSelected) {
    final bgColor = isSelected ? Colors.blue.shade50 : Colors.white;
    final borderColor = isSelected
        ? const Color(0xFF1976D2)
        : Colors.grey.shade300;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedProcessingOrder = order;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.company,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.contactName,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.contactNumber,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.date.month}/${order.date.day}/${order.date.year}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  order.time,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForProcessingView(bool isNarrow) {
    final orders = _mockProcessingOrders;

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders for Processing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventSearchController,
              decoration: InputDecoration(
                hintText: 'Search orders',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No orders are ready for processing.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children: orders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProcessingOrderCard(
                          order,
                          _selectedProcessingOrder == order,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );

    final menuSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedProcessingOrder == null)
              Text(
                'Select an order to view the menu.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Text(
                'Menu for ${_selectedProcessingOrder!.company} will appear here.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4511E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Update menu'),
              ),
            ),
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listSection,
            const SizedBox(height: 20),
            menuSection,
            const SizedBox(height: 20),
            _buildFoodBrowser(),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: listSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: menuSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: _buildFoodBrowser(),
          ),
        ),
      ],
    );
  }

  Future<void> _showThemeDesignDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Events Theme Design'),
          content: SizedBox(
            width: 800,
            height: 500,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DESIGN BOARD',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _themeDesignImages.isEmpty
                            ? Center(
                                child: Text(
                                  'No images uploaded yet.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            : GridView.count(
                                crossAxisCount: 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: _themeDesignImages
                                    .map(
                                      (file) => Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(
                                            file,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!kIsWeb) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Image upload is only supported on web.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final uploadInput = html.FileUploadInputElement();
                            uploadInput.accept = 'image/*';
                            uploadInput.multiple = true;
                            uploadInput.click();

                            uploadInput.onChange.listen((event) {
                              final files = uploadInput.files;
                              if (files == null || files.isEmpty) return;

                              for (final file in files) {
                                final reader = html.FileReader();
                                reader.readAsArrayBuffer(file);
                                reader.onLoad.listen((event) {
                                  final data = reader.result;
                                  if (data is Uint8List) {
                                    setState(() {
                                      _themeDesignImages.add(data);
                                    });
                                  } else if (data is ByteBuffer) {
                                    setState(() {
                                      _themeDesignImages.add(data.asUint8List());
                                    });
                                  }
                                });
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4511E),
                          ),
                          child: const Text('UPLOAD IMAGES'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTUAL EVENT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              'This will display the final event setup.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                              ),
                              child: const Text('SAVE'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                              ),
                              child: const Text('CANCEL'),
                            ),
                          ),
                        ],
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

  Widget _buildPostAnalysisView(bool isNarrow) {
    final orders = _mockPostAnalysisOrders;

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders for Post-Event Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventSearchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No orders available for analysis.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children: orders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProcessingOrderCard(
                          order,
                          _selectedPostAnalysisOrder == order,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );

    final menuSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedPostAnalysisOrder == null)
              Text(
                'Select an order to view the menu.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: _allDishes.take(4).map((dish) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dish.price,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Most Popular Dish',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final infoSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Business cards given away', '4'),
            _buildInfoRow('On-the-spot inquiries', '1'),
            _buildInfoRow('No. of Complaints', '0'),
            const SizedBox(height: 16),
            _buildCostBlock('Cost Estimation', '₱30000.00', Colors.orange),
            const SizedBox(height: 8),
            _buildCostBlock('Downpayment', '₱15000.00', Colors.blue),
            const SizedBox(height: 8),
            _buildCostBlock('Total Cost', '₱32000.00', Colors.green),
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listSection,
            const SizedBox(height: 20),
            menuSection,
            const SizedBox(height: 20),
            infoSection,
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: listSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: menuSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: infoSection,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedEventsView(bool isNarrow) {
    final orders = _mockCompletedOrders;

    final listSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COMPLETED EVENTS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No completed events yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children: orders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProcessingOrderCard(
                          order,
                          _selectedCompletedOrder == order,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );

    final menuSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MENU',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedCompletedOrder == null)
              Text(
                'Select an event to view the menu.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: _allDishes.take(4).map((dish) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dish.price,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Most Popular Dish',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final infoSection = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OTHER INFO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Business cards given away', '4'),
            _buildInfoRow('On-the-spot inquiries', '1'),
            _buildInfoRow('No. of Complaints', '0'),
            const SizedBox(height: 16),
            _buildCostBlock('Cost Estimation', '₱30000.00', Colors.orange),
            const SizedBox(height: 8),
            _buildCostBlock('Downpayment', '₱15000.00', Colors.blue),
            const SizedBox(height: 8),
            _buildCostBlock('Total Cost', '₱32000.00', Colors.green),
          ],
        ),
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listSection,
            const SizedBox(height: 20),
            menuSection,
            const SizedBox(height: 20),
            infoSection,
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: listSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: menuSection,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: infoSection,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCostBlock(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNewEventsList() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_mockNewEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No new events.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Column(
                children: _mockNewEvents.map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildProcessingOrderCard(order, false),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(EventStatus status, bool isNarrow) {
    switch (status) {
      case EventStatus.onlineInquiries:
        return _buildOnlineInquiriesView(isNarrow);
      case EventStatus.forProcessing:
        return _buildForProcessingView(isNarrow);
      case EventStatus.forPostAnalysis:
        return _buildPostAnalysisView(isNarrow);
      case EventStatus.completed:
        return _buildCompletedEventsView(isNarrow);
      case EventStatus.newEvent:
        return isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNewEventsList(),
                  const SizedBox(height: 20),
                  _buildEventForm(),
                  const SizedBox(height: 20),
                  _buildMenuSection(),
                  const SizedBox(height: 20),
                  _buildFoodBrowser(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNewEventsList(),
                          const SizedBox(height: 20),
                          _buildEventForm(),
                          const SizedBox(height: 20),
                          _buildMenuSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: _buildFoodBrowser(),
                    ),
                  ),
                ],
              );
    }
  }

  Widget _buildEventForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.add),
                label: const Text('New Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4511E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _eventSearchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Event Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              TextField(
                controller: _eventTitleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _eventType,
                      items: _eventTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      decoration: InputDecoration(
                        labelText: 'Event Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _eventType = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _customerController,
                      decoration: InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contactPersonController,
                      decoration: InputDecoration(
                        labelText: 'Contact Person',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contactNumberController,
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Date of Event',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                            hintText: _eventDate == null
                                ? 'Select date'
                                : '${_eventDate!.month}/${_eventDate!.day}/${_eventDate!.year}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _menuItems.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text('You don’t have anything on the menu right now...'),
                    SizedBox(height: 20),
                    SizedBox(height: 40),
                  ],
                )
              : Column(
                  children: _menuItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.dish.name} • ${item.paxOption}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            item.dish.price,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _removeFromMenu(item),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _showThemeDesignDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('EVENTS THEME DESIGN'),
          ),
        ),
      ],
    );
  }

  Widget _buildDishCard(Dish dish) {
    final selectedPax = _selectedPaxPerDish[dish.name] ?? dish.paxOptions.first;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fastfood,
                    size: 28,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.price,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _addToMenu(dish),
                  child: const Text('Add to menu'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dish.paxOptions.map((option) {
                final isSelected = selectedPax == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedPaxPerDish[dish.name] = option;
                    });
                  },
                  selectedColor: const Color(0xFF1976D2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1100;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Events',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black87,
                  indicator: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  tabs: EventStatus.values
                      .map((status) => Tab(text: _statusLabel(status)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: EventStatus.values
                        .map((status) => _buildBodyContent(status, isNarrow))
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFoodBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _foodSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search dish',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (_filteredDishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No dishes match your search.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 400, // Fixed height to prevent overflow, or use Expanded if possible
                    child: ListView(
                      children: _filteredDishes.map((dish) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDishCard(dish),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

