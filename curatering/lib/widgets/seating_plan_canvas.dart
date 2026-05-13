import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/seating_plan.dart';
import 'venue_floor_shapes.dart';

/// Normalized seat position on an ellipse around the table (matches server expectations).
Offset seatNormOnEllipse(SeatingTableSpec t, SeatingSeatSpec s) {
  final cx = t.xNorm + t.wNorm / 2;
  final cy = t.yNorm + t.hNorm / 2;
  final rx = t.wNorm / 2 + 0.018;
  final ry = t.hNorm / 2 + 0.018;
  final ang = s.perimeterT * 2 * math.pi - math.pi / 2;
  return Offset(cx + rx * math.cos(ang), cy + ry * math.sin(ang));
}

class SeatingPlanInteractive extends StatefulWidget {
  final SeatingPlanData plan;
  final bool editable;
  final ValueChanged<SeatingPlanData>? onChanged;

  const SeatingPlanInteractive({
    super.key,
    required this.plan,
    this.editable = false,
    this.onChanged,
  });

  @override
  State<SeatingPlanInteractive> createState() => _SeatingPlanInteractiveState();
}

class _SeatingPlanInteractiveState extends State<SeatingPlanInteractive> {
  String? _selectedTableId;
  final Map<String, TextEditingController> _labelCtrls = {};

  @override
  void dispose() {
    for (final c in _labelCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SeatingPlanInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.plan.tables.map((t) => t.id).toSet();
    _labelCtrls.removeWhere((id, c) {
      if (!ids.contains(id)) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (final t in widget.plan.tables) {
      final c = _labelCtrls[t.id];
      if (c != null && c.text != t.label) {
        c.value = TextEditingValue(
          text: t.label,
          selection: TextSelection.collapsed(offset: t.label.length),
        );
      }
    }
  }

  TextEditingController _labelCtrl(String tableId, String initial) {
    return _labelCtrls.putIfAbsent(
      tableId,
      () => TextEditingController(text: initial),
    );
  }

  void _emit(SeatingPlanData next) {
    widget.onChanged?.call(next);
  }

  Future<void> _pickFloorImage() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted) return;
    if (r == null || r.files.isEmpty) return;
    final bytes = r.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final b64 = base64Encode(bytes);
    _emit(
      widget.plan.copyWith(
        floorImageBase64: b64,
        clearFloorImageUrl: true,
        clearVenueFloorShape: true,
      ),
    );
  }

  void _clearFloor() {
    _emit(
      widget.plan.copyWith(
        clearFloorImageBase64: true,
        clearFloorImageUrl: true,
        clearVenueFloorShape: true,
      ),
    );
  }

  void _applyVenueFloorShape(String shapeId) {
    _emit(
      widget.plan.copyWith(
        venueFloorShape: shapeId,
        clearFloorImageBase64: true,
        clearFloorImageUrl: true,
      ),
    );
  }

  Future<void> _pickVenueFloorShape() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Venue shape'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pick a common room footprint instead of uploading a photo. '
                    'You can still drag tables on top of it.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < kVenueFloorShapeOptions.length; i++) ...[
                    InkWell(
                      onTap: () => Navigator.pop(ctx, kVenueFloorShapeOptions[i].id),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              kVenueFloorShapeOptions[i].icon,
                              size: 28,
                              color: const Color(0xFF2E2E2E),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    kVenueFloorShapeOptions[i].title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    kVenueFloorShapeOptions[i].subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              height: 36,
                              child: CustomPaint(
                                painter: VenueFloorShapePainter(
                                  kVenueFloorShapeOptions[i].id,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < kVenueFloorShapeOptions.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (!mounted || chosen == null) return;
    _applyVenueFloorShape(chosen);
  }

  void _addTable(String shape) {
    final id = 'tbl-${DateTime.now().millisecondsSinceEpoch}';
    final idx = widget.plan.tables.length + 1;
    final t = SeatingTableSpec(
      id: id,
      shape: shape,
      xNorm: 0.32 + (idx % 3) * 0.06,
      yNorm: 0.28 + (idx % 2) * 0.08,
      wNorm: shape == 'round' ? 0.14 : 0.16,
      hNorm: shape == 'round' ? 0.14 : 0.11,
      rotationDeg: 0,
      label: 'Table $idx',
      seatCount: shape == 'round' ? 8 : 8,
    );
    var next = widget.plan.copyWith(tables: [...widget.plan.tables, t]);
    next = next.withRegeneratedSeatsForTable(id, t);
    setState(() => _selectedTableId = id);
    _emit(next);
  }

  void _deleteSelected() {
    final id = _selectedTableId;
    if (id == null) return;
    _labelCtrls.remove(id)?.dispose();
    final tables = widget.plan.tables.where((t) => t.id != id).toList();
    final seats = widget.plan.seats.where((s) => s.tableId != id).toList();
    setState(() => _selectedTableId = null);
    _emit(widget.plan.copyWith(tables: tables, seats: seats));
  }

  void _bumpSeatCount(int delta) {
    final id = _selectedTableId;
    if (id == null) return;
    final tables = widget.plan.tables.map((t) {
      if (t.id != id) return t;
      final n = math.max(1, math.min(100, t.seatCount + delta));
      return t.copyWith(seatCount: n);
    }).toList();
    final t = tables.firstWhere((e) => e.id == id);
    var next = widget.plan.copyWith(tables: tables);
    next = next.withRegeneratedSeatsForTable(id, t);
    _emit(next);
  }

  void _onPanTable(String tableId, DragUpdateDetails d, double cw, double ch) {
    final dx = d.delta.dx / cw;
    final dy = d.delta.dy / ch;
    final tables = widget.plan.tables.map((t) {
      if (t.id != tableId) return t;
      return t.copyWith(
        xNorm: (t.xNorm + dx).clamp(0.0, 1.0 - t.wNorm),
        yNorm: (t.yNorm + dy).clamp(0.0, 1.0 - t.hNorm),
      );
    }).toList();
    _emit(widget.plan.copyWith(tables: tables));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.editable) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _addTable('rect'),
                icon: const Icon(Icons.table_restaurant, size: 18),
                label: const Text('Add rectangle table'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addTable('round'),
                icon: const Icon(Icons.circle_outlined, size: 18),
                label: const Text('Add round table'),
              ),
              OutlinedButton.icon(
                onPressed: _pickVenueFloorShape,
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('Venue shape'),
              ),
              OutlinedButton.icon(
                onPressed: _pickFloorImage,
                icon: const Icon(Icons.image, size: 18),
                label: const Text('Floor image'),
              ),
              TextButton.icon(
                onPressed:
                    p.floorImageBase64 == null &&
                            p.floorImageUrl == null &&
                            (p.venueFloorShape == null || p.venueFloorShape!.isEmpty)
                        ? null
                        : _clearFloor,
                icon: const Icon(Icons.hide_image_outlined, size: 18),
                label: const Text('Clear floor'),
              ),
              if (_selectedTableId != null) ...[
                IconButton(
                  tooltip: 'Fewer seats',
                  onPressed: () => _bumpSeatCount(-1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: 'More seats',
                  onPressed: () => _bumpSeatCount(1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: 'Delete table',
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ],
          ),
          if (_selectedTableId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final tid = _selectedTableId!;
                        final t = widget.plan.tables.firstWhere((e) => e.id == tid);
                        final ctrl = _labelCtrl(tid, t.label);
                        return TextField(
                          decoration: const InputDecoration(
                            labelText: 'Table label',
                            hintText: 'e.g. Head table, VIP 1',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          controller: ctrl,
                          onChanged: (v) {
                            final tables = widget.plan.tables.map((tb) {
                              if (tb.id != tid) return tb;
                              return tb.copyWith(
                                label: v.trim().isEmpty ? 'Table' : v.trim(),
                              );
                            }).toList();
                            _emit(widget.plan.copyWith(tables: tables));
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Drag the table to move. Use ± to change seat count.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        AspectRatio(
          aspectRatio: 16 / 10,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              return GestureDetector(
                onTap: widget.editable
                    ? () => setState(() => _selectedTableId = null)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _FloorLayer(plan: p),
                      ...p.tables.map((t) {
                        final sel = t.id == _selectedTableId;
                        return Positioned(
                          left: t.xNorm * w,
                          top: t.yNorm * h,
                          width: t.wNorm * w,
                          height: t.hNorm * h,
                          child: GestureDetector(
                            onTap: () {
                              if (!widget.editable) return;
                              setState(() => _selectedTableId = t.id);
                            },
                            onPanUpdate: widget.editable
                                ? (d) => _onPanTable(t.id, d, w, h)
                                : null,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    sel
                                        ? const Color(0xFFFFF3D0)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(
                                  t.shape == 'round' ? 999 : 8,
                                ),
                                border: Border.all(
                                  color:
                                      sel
                                          ? const Color(0xFFF4511E)
                                          : Colors.black45,
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '${t.label}\n(${t.seatCount} seats)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      ...p.seats.map((s) {
                        SeatingTableSpec? table;
                        for (final t in p.tables) {
                          if (t.id == s.tableId) {
                            table = t;
                            break;
                          }
                        }
                        if (table == null) return const SizedBox.shrink();
                        final pos = seatNormOnEllipse(table, s);
                        return Positioned(
                          left: pos.dx * w - 10,
                          top: pos.dy * h - 10,
                          width: 20,
                          height: 20,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                '${s.index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FloorLayer extends StatelessWidget {
  final SeatingPlanData plan;

  const _FloorLayer({required this.plan});

  @override
  Widget build(BuildContext context) {
    final u = plan.floorImageUrl;
    if (u != null && u.isNotEmpty) {
      if (u.startsWith('http://') || u.startsWith('https://')) {
        return Image.network(
          u,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder:
              (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
        );
      }
    }
    final b64 = plan.floorImageBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder:
              (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
        );
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image));
      }
    }
    final shape = plan.venueFloorShape;
    if (shape != null && shape.isNotEmpty) {
      if (isKnownVenueFloorShape(shape)) {
        return CustomPaint(painter: VenueFloorShapePainter(shape));
      }
      return Center(
        child: Text(
          'Saved floor shape is not recognized',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return Center(
      child: Text(
        'No floor — use Venue shape or Floor image',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }
}
