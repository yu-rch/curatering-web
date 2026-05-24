import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/event_design/theme_design_export.dart';
import '../features/seating/seating_layout_export.dart';
import '../features/seating/seating_plan.dart';
import '../features/seating/seating_plan_canvas.dart';
import '../utils/allergen_ui.dart';
import '../utils/theme_design_venue_refs.dart';

Future<void> showSeatingLayoutFullscreen(
  BuildContext context, {
  required SeatingPlanData plan,
  List<String> venueReferencePhotosBase64 = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder:
        (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Seating layout',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SeatingPlanInteractive(
                    plan: plan,
                    editable: false,
                    venueReferencePhotosBase64: venueReferencePhotosBase64,
                  ),
                ),
              ),
            ],
          ),
        ),
  );
}

Widget buildManagerThemeDesignBlock({
  required BuildContext context,
  required Map<String, dynamic> themeDesign,
  required VoidCallback? onOpenEditor,
  required String openEditorLabel,
  String eventTitle = '',
  String transactionNo = '',
  bool showCostFields = false,
  TextEditingController? noteController,
  TextEditingController? costController,
  bool readOnlyCostFields = false,
}) {
  final hasImage =
      '${themeDesign['generatedImageUrl'] ?? themeDesign['imageUrl'] ?? themeDesign['image'] ?? ''}'
          .trim()
          .isNotEmpty;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap:
              hasImage
                  ? () => showThemeDesignFullscreen(context, themeDesign)
                  : null,
          child: managerThemeDesignImagePreview(themeDesign),
        ),
      ),
      if (hasImage)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Tap the image for full-screen preview.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      const SizedBox(height: 8),
      if (onOpenEditor != null)
        FilledButton.icon(
          onPressed: onOpenEditor,
          icon: const Icon(Icons.auto_awesome),
          label: Text(openEditorLabel),
        ),
      if (hasImage) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed:
                  () => previewThemeDesignPdf(
                    context: context,
                    themeDesign: themeDesign,
                    eventTitle: eventTitle,
                    transactionNo: transactionNo,
                  ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Preview PDF'),
            ),
            OutlinedButton.icon(
              onPressed:
                  () => saveThemeDesignImageToGallery(
                    context: context,
                    themeDesign: themeDesign,
                  ),
              icon: const Icon(Icons.download),
              label: const Text('Download image'),
            ),
          ],
        ),
      ],
      if (showCostFields &&
          noteController != null &&
          costController != null) ...[
        const SizedBox(height: 10),
        TextField(
          controller: noteController,
          readOnly: readOnlyCostFields,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Theme notes'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: costController,
          keyboardType: TextInputType.number,
          readOnly: readOnlyCostFields,
          decoration: const InputDecoration(labelText: 'Theme design cost'),
        ),
      ],
    ],
  );
}

Widget buildManagerSeatingLayoutBlock({
  required BuildContext context,
  required Map<String, dynamic> seatingPlanJson,
  required String helperText,
  required String buttonLabel,
  VoidCallback? onOpenEditor,
  bool exportOnly = false,
  String eventTitle = '',
  String transactionNo = '',
  String eventDateTime = '',
  String venueAddress = '',
  Map<String, dynamic> themeDesign = const {},
}) {
  final plan = SeatingPlanData.fromJson(seatingPlanJson);
  final hasPlan = !plan.isEffectivelyEmpty;
  final venueRefs = venueReferencePhotosFromThemeDesign(themeDesign);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        helperText,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      if (venueRefs.isNotEmpty) ...[
        Text(
          'Venue reference photos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: venueRefs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder:
                (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(venueRefs[index]),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (hasPlan)
        SizedBox(
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(
                color: Colors.grey.shade50,
                child: InkWell(
                  onTap:
                      () => showSeatingLayoutFullscreen(
                        context,
                        plan: plan,
                        venueReferencePhotosBase64: venueRefs,
                      ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 520,
                      height: 320,
                      child: SeatingPlanInteractive(
                        plan: plan,
                        editable: false,
                        venueReferencePhotosBase64: venueRefs,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      else
        Text(
          'No seating layout yet.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (onOpenEditor != null)
            FilledButton.icon(
              onPressed: onOpenEditor,
              icon: const Icon(Icons.event_seat_outlined),
              label: Text(buttonLabel),
            ),
          if (hasPlan) ...[
            OutlinedButton.icon(
              onPressed:
                  () => previewSeatingLayoutPdf(
                    context: context,
                    plan: plan,
                    eventTitle: eventTitle,
                    transactionNo: transactionNo,
                    eventDateTime: eventDateTime,
                    venueAddress: venueAddress,
                  ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Preview PDF'),
            ),
            OutlinedButton.icon(
              onPressed:
                  () => saveSeatingLayoutImageToGallery(
                    context: context,
                    plan: plan,
                  ),
              icon: const Icon(Icons.download),
              label: const Text('Download image'),
            ),
          ],
        ],
      ),
    ],
  );
}
