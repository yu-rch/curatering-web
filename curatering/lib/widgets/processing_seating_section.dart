import 'package:flutter/material.dart';

import '../models/event_order.dart';
import '../models/seating_plan.dart';
import '../services/events_api.dart';
import 'async_dialogs.dart';
import 'seating_plan_canvas.dart';

/// Seating editor for a processing event order (catering + event only).
class ProcessingSeatingSection extends StatefulWidget {
  final EventOrderDto order;
  final Future<void> Function() onSaved;

  const ProcessingSeatingSection({
    super.key,
    required this.order,
    required this.onSaved,
  });

  @override
  State<ProcessingSeatingSection> createState() => _ProcessingSeatingSectionState();
}

class _ProcessingSeatingSectionState extends State<ProcessingSeatingSection> {
  late SeatingPlanData _plan;
  late SeatingPlanData _initialPlan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.order.seatingPlan;
    _initialPlan = _plan;
  }

  @override
  void didUpdateWidget(covariant ProcessingSeatingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order.id != oldWidget.order.id) {
      _plan = widget.order.seatingPlan;
      _initialPlan = _plan;
    }
  }

  bool get _isDirty => _plan.toJson().toString() != _initialPlan.toJson().toString();

  Future<void> _save() async {
    final ok = await showConfirmActionDialog(
      context,
      title: 'Save seating layout?',
      message: 'This will update the seating plan for this event order.',
      confirmLabel: 'Save',
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    try {
      await EventsApi.instance.putStaffSeatingPlan(
        orderId: widget.order.id,
        seatingPlan: _plan.toJson(),
      );
      if (!mounted) return;
      _initialPlan = _plan;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seating layout saved.'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save seating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _discardChanges() async {
    if (!_isDirty) return;
    final ok = await showConfirmActionDialog(
      context,
      title: 'Discard changes?',
      message: 'Unsaved seating edits will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _plan = _initialPlan);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'SEATING LAYOUT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E2E2E),
                    ),
                  ),
                ),
                const Spacer(),
                if (_isDirty)
                  TextButton(
                    onPressed: _saving ? null : _discardChanges,
                    child: const Text('Discard'),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: const Text('Save seating'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SeatingPlanInteractive(
              plan: _plan,
              editable: true,
              onChanged: (next) => setState(() => _plan = next),
            ),
          ],
        ),
      ),
    );
  }
}
