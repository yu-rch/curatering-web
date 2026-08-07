import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/menu_dish.dart';
import '../services/set_menu_store.dart';
import 'antd_buttons.dart';
import 'antd_dialog.dart';
import 'antd_tokens.dart';

/// Menu picker modes for online inquiry / staff new-event food selection.
enum InquiryMenuPickerMode {
  /// Inquiry: custom 5–8 catering dishes OR one premade set menu (exclusive tabs).
  inquiryExclusive,

  /// Staff new event: same dish limits, exclusive tabs in food browser.
  staffNewEvent,

  /// Legacy: single dish from set menus only.
  setMenuSinglePickOnly,
}

Future<List<Map<String, dynamic>>?> showInquiryMenuSelectionDialog(
  BuildContext context, {
  required List<MenuDish> cateringDishes,
  required List<SetMenu> setMenus,
  List<Map<String, dynamic>> initialSelections = const [],
  InquiryMenuPickerMode mode = InquiryMenuPickerMode.inquiryExclusive,
  int minCustomDishes = 4,
  int maxCustomDishes = 8,
}) {
  return showAntdModal<List<Map<String, dynamic>>>(
    context: context,
    title: _titleForMode(mode),
    maxWidth: 640,
    body: InquiryMenuPicker(
      cateringDishes: cateringDishes,
      setMenus: setMenus,
      initialSelections: initialSelections,
      mode: mode,
      minCustomDishes: minCustomDishes,
      maxCustomDishes: maxCustomDishes,
    ),
    actions: const [],
  );
}

String _titleForMode(InquiryMenuPickerMode mode) {
  switch (mode) {
    case InquiryMenuPickerMode.setMenuSinglePickOnly:
      return 'Choose set-menu dish';
    case InquiryMenuPickerMode.staffNewEvent:
      return 'Food — select dishes';
    case InquiryMenuPickerMode.inquiryExclusive:
      return 'Menu preferences';
  }
}

/// Catering / set-menu picker. Use [embedded] on the inquiry page; modal via [showInquiryMenuSelectionDialog].
class InquiryMenuPicker extends StatefulWidget {
  const InquiryMenuPicker({
    super.key,
    required this.cateringDishes,
    required this.setMenus,
    this.initialSelections = const [],
    this.mode = InquiryMenuPickerMode.inquiryExclusive,
    this.minCustomDishes = 4,
    this.maxCustomDishes = 10,
    this.visibleRowCount = 8,
    this.twoColumnSetMenu = false,
    this.embedded = false,
    this.tabIndex = 0,
    this.onSelectionChanged,
    this.externalError,
  });

  final List<MenuDish> cateringDishes;
  final List<SetMenu> setMenus;
  final List<Map<String, dynamic>> initialSelections;
  final InquiryMenuPickerMode mode;
  final int minCustomDishes;
  final int maxCustomDishes;
  final int visibleRowCount;
  final bool twoColumnSetMenu;

  /// When true, renders inline (no modal chrome, no Done/Cancel). Parent owns tab chips via [tabIndex].
  final bool embedded;

  /// Active tab when [embedded]: 0 = custom dishes, 1 = set menu.
  final int tabIndex;

  final ValueChanged<List<Map<String, dynamic>>>? onSelectionChanged;

  /// Validation message from parent form (e.g. submit errors).
  final String? externalError;

  @override
  State<InquiryMenuPicker> createState() => _InquiryMenuPickerState();
}

class _InquiryMenuPickerState extends State<InquiryMenuPicker>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final Set<String> _customIds = {};
  SetMenu? _selectedSet;
  final Set<String> _selectedSetDishIds = {};
  String _customFilter = '';
  String? _localError;

  /// Single-pick legacy
  String? _pickDishId;
  String? _pickSetMenuName;

  bool get _exclusiveMode =>
      widget.mode == InquiryMenuPickerMode.inquiryExclusive ||
      widget.mode == InquiryMenuPickerMode.staffNewEvent;

  int get _activeTab =>
      widget.embedded ? widget.tabIndex : (_tabController?.index ?? 0);

  String? get _displayError => widget.externalError ?? _localError;

  @override
  void initState() {
    super.initState();
    if (_exclusiveMode && !widget.embedded) {
      _tabController = TabController(length: 2, vsync: this);
      _restoreFromInitial(widget.initialSelections);
      _tabController!.addListener(_onModalTabChanged);
    } else if (_exclusiveMode && widget.embedded) {
      _restoreFromInitial(widget.initialSelections);
    } else if (widget.mode == InquiryMenuPickerMode.setMenuSinglePickOnly) {
      if (widget.initialSelections.length == 1) {
        final b = widget.initialSelections.first;
        final ids = b['dishIds'] as List<dynamic>?;
        if (ids != null && ids.isNotEmpty) {
          _pickDishId = ids.first.toString();
          _pickSetMenuName = b['setMenuName'] as String?;
        }
      }
    }
  }

  void _onModalTabChanged() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    setState(() {
      _localError = null;
      if (_tabController!.index == 0) {
        _selectedSet = null;
        _selectedSetDishIds.clear();
      } else {
        _customIds.clear();
      }
    });
  }

  @override
  void didUpdateWidget(InquiryMenuPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedded &&
        _exclusiveMode &&
        oldWidget.tabIndex != widget.tabIndex) {
      setState(() {
        _localError = null;
        if (widget.tabIndex == 0) {
          _selectedSet = null;
          _selectedSetDishIds.clear();
        } else {
          _customIds.clear();
        }
      });
      _emitSelection();
    }
    if (widget.initialSelections != oldWidget.initialSelections) {
      _restoreFromInitial(widget.initialSelections);
    }
    if (widget.cateringDishes != oldWidget.cateringDishes &&
        _sanitizeSelectionsForAvailableDishes()) {
      _emitSelection();
    }
  }

  void _restoreFromInitial(List<Map<String, dynamic>> blocks) {
    _customIds.clear();
    _selectedSet = null;
    _selectedSetDishIds.clear();
    if (blocks.isEmpty) return;
    final availableIds = _availableDishIds;
    final b = blocks.first;
    final kind = b['kind'] as String? ?? 'custom';
    if (kind == 'set') {
      final name = b['setMenuName'] as String?;
      for (final s in widget.setMenus) {
        if (s.name == name) {
          _selectedSet = s;
          final ids = b['dishIds'] as List<dynamic>? ?? s.dishIds;
          _selectedSetDishIds.addAll(
            ids.map((e) => e.toString()).where(availableIds.contains),
          );
          break;
        }
      }
      if (!widget.embedded) _tabController?.index = 1;
    } else {
      final ids = b['dishIds'] as List<dynamic>? ?? const [];
      _customIds.addAll(
        ids.map((e) => e.toString()).where(availableIds.contains),
      );
      if (!widget.embedded) _tabController?.index = 0;
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onModalTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  Map<String, String> get _dishNameById => {
    for (final d in widget.cateringDishes) d.id: d.name,
  };

  Set<String> get _availableDishIds => {
    for (final d in widget.cateringDishes) d.id,
  };

  List<String> _visibleSetDishIds(SetMenu set) {
    final availableIds = _availableDishIds;
    return set.dishIds.where(availableIds.contains).toList();
  }

  bool _sanitizeSelectionsForAvailableDishes() {
    final availableIds = _availableDishIds;
    final customBefore = _customIds.length;
    final setBefore = _selectedSetDishIds.length;
    final pickBefore = _pickDishId;

    _customIds.removeWhere((id) => !availableIds.contains(id));
    _selectedSetDishIds.removeWhere((id) => !availableIds.contains(id));
    if (_pickDishId != null && !availableIds.contains(_pickDishId)) {
      _pickDishId = null;
    }

    return customBefore != _customIds.length ||
        setBefore != _selectedSetDishIds.length ||
        pickBefore != _pickDishId;
  }

  List<Map<String, dynamic>> _buildCurrentBlocks() {
    if (widget.mode == InquiryMenuPickerMode.setMenuSinglePickOnly) {
      if (_pickDishId == null || _pickDishId!.isEmpty) return [];
      final name = _dishNameById[_pickDishId!] ?? _pickDishId!;
      return [
        {
          'kind': 'set',
          'setMenuName': _pickSetMenuName ?? 'Set menu',
          'dishIds': [_pickDishId!],
          'dishNames': [name],
        },
      ];
    }

    if (_activeTab == 0) {
      if (_customIds.isEmpty) return [];
      final availableIds = _availableDishIds;
      final ids = _customIds.where(availableIds.contains).toList()..sort();
      if (ids.isEmpty) return [];
      return [
        {
          'kind': 'custom',
          'dishIds': ids,
          'dishNames': ids.map((id) => _dishNameById[id] ?? id).toList(),
        },
      ];
    }

    final set = _selectedSet;
    if (set == null) return [];
    final availableIds = _availableDishIds;
    final ids =
        _selectedSetDishIds.where(availableIds.contains).toList()..sort();
    if (ids.isEmpty) return [];
    final originalIds = _visibleSetDishIds(set)..sort();
    return [
      {
        'kind': 'set',
        'setMenuName': set.name,
        'originalDishIds': originalIds,
        'originalDishCount': originalIds.length,
        'dishIds': ids,
        'dishNames': ids.map((id) => _dishNameById[id] ?? id).toList(),
      },
    ];
  }

  void _emitSelection() {
    if (!widget.embedded) return;
    widget.onSelectionChanged?.call(_buildCurrentBlocks());
  }

  void _onDone() {
    final mode = widget.mode;
    if (mode == InquiryMenuPickerMode.setMenuSinglePickOnly) {
      if (_pickDishId == null || _pickDishId!.isEmpty) {
        setState(() => _localError = 'Please select one dish from a set menu.');
        return;
      }
      Navigator.of(context).pop(_buildCurrentBlocks());
      return;
    }

    final tab = _activeTab;
    if (tab == 0) {
      final n = _customIds.length;
      if (n <= 0) {
        setState(() => _localError = 'Please select at least one dish.');
        return;
      }
      Navigator.of(context).pop(_buildCurrentBlocks());
    } else {
      final set = _selectedSet;
      if (set == null) {
        setState(() => _localError = 'Please choose a set menu.');
        return;
      }
      if (_selectedSetDishIds.isEmpty) {
        setState(
          () => _localError = 'Please keep at least one dish in "${set.name}".',
        );
        return;
      }
      Navigator.of(context).pop(_buildCurrentBlocks());
    }
  }

  Widget _buildErrorBanner() {
    final msg = _displayError;
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        msg,
        style: const TextStyle(color: AntdTokens.error, fontSize: 13),
      ),
    );
  }

  Widget _buildCustomDishesPanel() {
    final filtered =
        widget.cateringDishes.where((d) {
          if (_customFilter.trim().isEmpty) return true;
          return d.name.toLowerCase().contains(
            _customFilter.trim().toLowerCase(),
          );
        }).toList();
    filtered.sort((a, b) {
      final aSel = _customIds.contains(a.id) ? 0 : 1;
      final bSel = _customIds.contains(b.id) ? 0 : 1;
      if (aSel != bSel) return aSel - bSel;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Pick dishes from the catering menu (${_customIds.length} selected).',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search dishes',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _customFilter = v),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              widget.cateringDishes.isEmpty
                  ? 'Loading catering menu…'
                  : 'No dishes match your search.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.visibleRowCount * 52.0,
            ),
            child: ListView.builder(
              shrinkWrap: !widget.embedded,
              itemCount: filtered.length,
              itemBuilder: (context, i) {
              final d = filtered[i];
              final checked = _customIds.contains(d.id);
              return CheckboxListTile(
                dense: true,
                secondary: _dishThumb(d),
                value: checked,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      if (_customIds.length >= widget.maxCustomDishes) {
                        _localError =
                            'Select at most ${widget.maxCustomDishes} dishes.';
                        return;
                      }
                      _customIds.add(d.id);
                      _localError = null;
                    } else {
                      _customIds.remove(d.id);
                      _localError = null;
                    }
                  });
                  _emitSelection();
                },
                title: Text(d.name),
              );
            },
            ),
          ),
      ],
    );
  }

  Widget _buildSetMenusPanel() {
    if (widget.setMenus.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No set menus are available yet.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: widget.setMenus.length,
      itemBuilder: (context, i) {
        final s = widget.setMenus[i];
        final selected = _selectedSet?.name == s.name;
        final visibleDishIds = _visibleSetDishIds(s);
        final canSelect = visibleDishIds.isNotEmpty;
        final preview = visibleDishIds
            .map((id) => _dishNameById[id] ?? id)
            .join(', ');
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color:
              selected ? AntdTokens.brandPrimary.withValues(alpha: 0.15) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? AntdTokens.brandPrimary : Colors.grey.shade300,
            ),
          ),
          child: ListTile(
            title: Text(
              s.name,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            subtitle: Text(
              visibleDishIds.isEmpty
                  ? 'No dishes available for the selected allergens'
                  : preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Radio<SetMenu>(
              value: s,
              groupValue: _selectedSet,
              activeColor: AntdTokens.brandPrimary,
              onChanged:
                  canSelect
                      ? (v) {
                        setState(() {
                          _selectedSet = v;
                          _selectedSetDishIds
                            ..clear()
                            ..addAll(
                              v == null
                                  ? const <String>[]
                                  : _visibleSetDishIds(v),
                            );
                          _localError = null;
                        });
                        _emitSelection();
                      }
                      : null,
            ),
            onTap:
                canSelect
                    ? () {
                      setState(() {
                        _selectedSet = s;
                        _selectedSetDishIds
                          ..clear()
                          ..addAll(visibleDishIds);
                        _localError = null;
                      });
                      _emitSelection();
                    }
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildSetDishCustomizer() {
    final selected = _selectedSet;
    if (selected == null) return const SizedBox.shrink();
    final originalIds = _visibleSetDishIds(selected).toSet();
    final addedCount =
        _selectedSetDishIds.where((id) => !originalIds.contains(id)).length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Customize "${selected.name}" with catering dishes',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (addedCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$addedCount added dish(es) may incur additional fees.',
              style: const TextStyle(
                color: AntdTokens.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final d in (() {
            final sorted = [...widget.cateringDishes];
            sorted.sort((a, b) {
              final aSel = _selectedSetDishIds.contains(a.id) ? 0 : 1;
              final bSel = _selectedSetDishIds.contains(b.id) ? 0 : 1;
              if (aSel != bSel) return aSel - bSel;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
            return sorted;
          })())
            CheckboxListTile(
              dense: true,
              secondary: _dishThumb(d),
              value: _selectedSetDishIds.contains(d.id),
              title: Text(d.name),
              subtitle: () {
                if (!_selectedSetDishIds.contains(d.id)) return null;
                final originalIds = _visibleSetDishIds(selected).toSet();
                if (originalIds.contains(d.id)) return null;
                final slotLimit = originalIds.length;
                final pos = _selectedSetDishIds.toList().indexOf(d.id);
                final overSlot = pos >= slotLimit;
                final charge =
                    overSlot ? d.additionalChargeAmount : 0;
                if (charge <= 0 && !overSlot) {
                  return const Text(
                    'Added dish — add\'l charge editable by staff',
                    style: TextStyle(fontSize: 11),
                  );
                }
                if (charge <= 0) return null;
                return Text(
                  'Add\'l charge: PHP ${charge.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AntdTokens.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }(),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedSetDishIds.add(d.id);
                  } else {
                    _selectedSetDishIds.remove(d.id);
                  }
                  _localError = null;
                });
                _emitSelection();
              },
            ),
          const SizedBox(height: 10),
          _buildSetMenuModificationsPreview(selected),
        ],
      ),
    );
  }

  Widget _buildSetMenuModificationsPreview(SetMenu selected) {
    final originalIds = _visibleSetDishIds(selected).toSet();
    final removedIds =
        originalIds.where((id) => !_selectedSetDishIds.contains(id)).toList()
          ..sort();
    final addedIds =
        _selectedSetDishIds.where((id) => !originalIds.contains(id)).toList()
          ..sort();
    if (removedIds.isEmpty && addedIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <Map<String, String>>[];
    final pairCount = removedIds.length < addedIds.length
        ? removedIds.length
        : addedIds.length;
    for (var i = 0; i < pairCount; i++) {
      rows.add({
        'dish': _dishNameById[removedIds[i]] ?? removedIds[i],
        'action': 'REPLACED',
        'result': _dishNameById[addedIds[i]] ?? addedIds[i],
        'charge': '—',
      });
    }
    if (removedIds.length > pairCount) {
      for (var i = pairCount; i < removedIds.length; i++) {
        rows.add({
          'dish': _dishNameById[removedIds[i]] ?? removedIds[i],
          'action': 'REMOVED',
          'result': '—',
          'charge': '—',
        });
      }
    }
    if (addedIds.length > pairCount) {
      final slotLimit = originalIds.length;
      final overage =
          (_selectedSetDishIds.length - slotLimit).clamp(0, 9999);
      for (var i = pairCount; i < addedIds.length; i++) {
        final id = addedIds[i];
        MenuDish? dish;
        for (final d in widget.cateringDishes) {
          if (d.id == id) {
            dish = d;
            break;
          }
        }
        final addIndex = i - pairCount;
        final addCharge =
            addIndex < overage ? (dish?.additionalChargeAmount ?? 0) : 0;
        rows.add({
          'dish': '—',
          'action': 'ADDED',
          'result': _dishNameById[id] ?? id,
          'charge': addCharge > 0 ? 'PHP ${addCharge.toStringAsFixed(2)}' : '—',
        });
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu modifications',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 34,
                    dataRowMinHeight: 34,
                    dataRowMaxHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Dish')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Result')),
                      DataColumn(label: Text('Add\'l charge')),
                    ],
                    rows: rows
                        .map(
                          (r) => DataRow(
                            cells: [
                              DataCell(Text(r['dish']!)),
                              DataCell(Text(r['action']!)),
                              DataCell(Text(r['result']!)),
                              DataCell(Text(r['charge']!)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final Map<String, Uint8List> _imageCache = {};

  Widget _dishThumb(MenuDish dish) {
    if (dish.imageBase64?.isNotEmpty != true) {
      return const CircleAvatar(child: Icon(Icons.restaurant, size: 18));
    }
    final bytes = _imageCache.putIfAbsent(
      dish.id,
      () => base64Decode(dish.imageBase64!),
    );
    return RepaintBoundary(
      key: ValueKey('thumb_${dish.id}'),
      child: CircleAvatar(
        backgroundImage: MemoryImage(bytes),
      ),
    );
  }

  Widget _buildExclusiveContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildErrorBanner(),
        if (!widget.embedded) ...[
          TabBar(
            controller: _tabController,
            labelColor: AntdTokens.brandOnPrimary,
            unselectedLabelColor: Colors.grey.shade700,
            indicatorColor: AntdTokens.brandPrimary,
            tabs: const [
              Tab(text: 'I want to make my own menu'),
              Tab(text: 'Choose from Set Menu'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildCustomDishesPanel(),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSetMenusPanel(),
                      _buildSetDishCustomizer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AntdCancelButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              AntdPrimaryButton(label: 'Done', onPressed: _onDone),
            ],
          ),
        ] else
          _buildEmbeddedMenuPanel(),
      ],
    );
  }

  /// Inline inquiry form: fixed max height + scroll (avoids IndexedStack empty gap).
  Widget _buildEmbeddedMenuPanel() {
    final maxHeight = widget.twoColumnSetMenu && _activeTab == 1
        ? 360.0
        : widget.visibleRowCount * 52.0 + 100;
    final panel =
        _activeTab == 0
            ? _buildCustomDishesPanel()
            : (widget.twoColumnSetMenu
                ? SizedBox(
                  height: 340,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: _buildSetMenusPanel(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: _buildSetDishCustomizer(),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [_buildSetMenusPanel(), _buildSetDishCustomizer()],
                ));
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: widget.twoColumnSetMenu && _activeTab == 1
          ? panel
          : Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 4),
              child: panel,
            ),
          ),
    );
  }

  Widget _buildSinglePickBody() {
    if (widget.setMenus.isEmpty) {
      return const Text('No set menus are available yet.');
    }
    return SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildErrorBanner(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final set in widget.setMenus) ...[
                  Text(
                    set.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in set.dishIds)
                        ChoiceChip(
                          label: Text(_dishNameById[id] ?? id),
                          selected: _pickDishId == id,
                          selectedColor: AntdTokens.brandPrimary,
                          labelStyle: TextStyle(
                            color:
                                _pickDishId == id
                                    ? AntdTokens.brandOnPrimary
                                    : Colors.black87,
                            fontWeight:
                                _pickDishId == id
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _pickDishId = id;
                              _pickSetMenuName = set.name;
                              _localError = null;
                            });
                            _emitSelection();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          if (!widget.embedded)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AntdCancelButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                AntdPrimaryButton(label: 'Done', onPressed: _onDone),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == InquiryMenuPickerMode.setMenuSinglePickOnly) {
      return _buildSinglePickBody();
    }

    if (widget.embedded) {
      return _buildExclusiveContent();
    }

    return SizedBox(height: 420, child: _buildExclusiveContent());
  }
}
