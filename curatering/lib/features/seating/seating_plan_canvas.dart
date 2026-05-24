import 'package:flutter/material.dart';

import '../../widgets/seating_plan_canvas.dart' as current;
import 'seating_plan.dart';

Offset seatNormOnEllipse(SeatingTableSpec table, SeatingSeatSpec seat) {
  return current.seatNormOnEllipse(table, seat);
}

double perimeterTFromNormPoint(SeatingTableSpec table, double nx, double ny) {
  return current.perimeterTFromNormPoint(table, nx, ny);
}

class SeatingPlanInteractive extends StatelessWidget {
  const SeatingPlanInteractive({
    super.key,
    required this.plan,
    this.editable = false,
    this.layoutEditable = true,
    this.onChanged,
    this.venueReferencePhotosBase64 = const [],
  });

  final SeatingPlanData plan;
  final bool editable;
  final bool layoutEditable;
  final ValueChanged<SeatingPlanData>? onChanged;
  final List<String> venueReferencePhotosBase64;

  @override
  Widget build(BuildContext context) {
    return current.SeatingPlanInteractive(
      plan: plan,
      editable: editable,
      layoutEditable: layoutEditable,
      onChanged: onChanged,
    );
  }
}
