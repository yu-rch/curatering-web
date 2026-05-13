import 'package:flutter/material.dart';

import '../models/menu_dish.dart';
import '../services/set_menu_store.dart';

/// Returns a list of selection blocks:
/// `{ kind: 'set', setMenuName, dishIds: [...], dishNames: [...] }` or
/// `{ kind: 'custom', dishIds: [...], dishNames: [...] }`.
Future<List<Map<String, dynamic>>?> showInquiryMenuSelectionDialog(
  BuildContext context, {
  required List<MenuDish> cateringDishes,
  required List<SetMenu> setMenus,
  List<Map<String, dynamic>> initialSelections = const [],
}) {
  return showDialog<List<Map<String, dynamic>>>(
    context: context,
    builder: (ctx) => _InquiryMenuSelectionDialog(
      cateringDishes: cateringDishes,
      setMenus: setMenus,
      initialSelections: initialSelections,
    ),
  );
}

class _InquiryMenuSelectionDialog extends StatefulWidget {
  const _InquiryMenuSelectionDialog({
    required this.cateringDishes,
    required this.setMenus,
    required this.initialSelections,
  });

  final List<MenuDish> cateringDishes;
  final List<SetMenu> setMenus;
  final List<Map<String, dynamic>> initialSelections;

  @override
  State<_InquiryMenuSelectionDialog> createState() =>
      _InquiryMenuSelectionDialogState();
}

class _InquiryMenuSelectionDialogState extends State<_InquiryMenuSelectionDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _scratchCustomIds = {};
  late List<Map<String, dynamic>> _blocks;
  String _customFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _blocks = widget.initialSelections
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, String> get _dishNameById => {
        for (final d in widget.cateringDishes) d.id: d.name,
      };

  void _addCustomBlockFromScratch() {
    if (_scratchCustomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one dish.')),
      );
      return;
    }
    final ids = _scratchCustomIds.toList()..sort();
    setState(() {
      _blocks.add({
        'kind': 'custom',
        'dishIds': ids,
        'dishNames': ids.map((id) => _dishNameById[id] ?? id).toList(),
      });
      _scratchCustomIds.clear();
    });
  }

  void _addSetBlock(SetMenu set) {
    final ids = set.dishIds.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set "${set.name}" has no dishes yet.')),
      );
      return;
    }
    final names = ids.map((id) => _dishNameById[id] ?? id).toList();
    setState(() {
      _blocks.add({
        'kind': 'set',
        'setMenuName': set.name,
        'dishIds': ids,
        'dishNames': names,
      });
    });
  }

  void _removeBlock(int index) {
    setState(() => _blocks.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustom = widget.cateringDishes.where((d) {
      if (_customFilter.trim().isEmpty) return true;
      return d.name.toLowerCase().contains(_customFilter.trim().toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('Catering menu selection'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'À la carte'),
                Tab(text: 'Set menus'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search dishes',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _customFilter = v),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredCustom.length,
                          itemBuilder: (context, i) {
                            final d = filteredCustom[i];
                            final checked = _scratchCustomIds.contains(d.id);
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _scratchCustomIds.add(d.id);
                                  } else {
                                    _scratchCustomIds.remove(d.id);
                                  }
                                });
                              },
                              title: Text(d.name),
                              subtitle: Text(
                                d.price,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addCustomBlockFromScratch,
                        icon: const Icon(Icons.add),
                        label: const Text('Add selected to inquiry'),
                      ),
                    ],
                  ),
                  ListView.builder(
                    itemCount: widget.setMenus.length,
                    itemBuilder: (context, i) {
                      final s = widget.setMenus[i];
                      final preview = s.dishIds
                          .map((id) => _dishNameById[id] ?? id)
                          .take(4)
                          .join(', ');
                      final more = s.dishIds.length > 4 ? '…' : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text(
                            s.dishIds.isEmpty ? 'No dishes' : '$preview$more',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: FilledButton(
                            onPressed: () => _addSetBlock(s),
                            child: const Text('Add set'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            const Text(
              'Your selections',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child:
                  _blocks.isEmpty
                      ? Center(
                        child: Text(
                          'Nothing added yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _blocks.length,
                        itemBuilder: (context, i) {
                          final b = _blocks[i];
                          final kind = b['kind'] as String? ?? 'custom';
                          final title =
                              kind == 'set'
                                  ? (b['setMenuName'] as String? ?? 'Set')
                                  : 'À la carte';
                          final names =
                              (b['dishNames'] as List<dynamic>?)
                                  ?.cast<String>()
                                  .join(', ') ??
                              '';
                          return ListTile(
                            dense: true,
                            title: Text(title),
                            subtitle: Text(
                              names,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeBlock(i),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_blocks),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
