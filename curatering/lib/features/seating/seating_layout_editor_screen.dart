import 'dart:convert';

import 'package:flutter/material.dart';

import '../../utils/theme_design_venue_refs.dart';
import '../../widgets/antd_message.dart';
import '../event_design/events_feature_api.dart';
import 'seating_layout_export.dart';
import 'seating_plan.dart';
import 'seating_plan_canvas.dart';

class SeatingLayoutEditorScreen extends StatefulWidget {
  const SeatingLayoutEditorScreen({
    super.key,
    required this.apiBase,
    required this.userEmail,
    this.orderId = '',
    required this.orderKind,
    this.initialPlan,
    this.cashierEmail,
    this.cashierPassword,
    this.readOnly = false,
    this.draftOnly = false,
    this.eventTitle = '',
    this.transactionNo = '',
    this.themeDesign = const {},
  });

  final String apiBase;
  final String userEmail;
  final String orderId;
  final String orderKind;
  final SeatingPlanData? initialPlan;
  final String? cashierEmail;
  final String? cashierPassword;
  final bool readOnly;
  final bool draftOnly;
  final String eventTitle;
  final String transactionNo;
  final Map<String, dynamic> themeDesign;

  @override
  State<SeatingLayoutEditorScreen> createState() =>
      _SeatingLayoutEditorScreenState();
}

class _SeatingLayoutEditorScreenState extends State<SeatingLayoutEditorScreen> {
  late SeatingPlanData _plan;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan ?? SeatingPlanData.empty;
    if (widget.draftOnly ||
        widget.initialPlan != null ||
        widget.orderId.trim().isEmpty) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await EventsFeatureApi(
        apiBase: widget.apiBase,
      ).getSeatingPlan(
        orderId: widget.orderId,
        orderKind: widget.orderKind,
        userEmail: widget.userEmail,
        cashierEmail: widget.cashierEmail,
        cashierPassword: widget.cashierPassword,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (widget.readOnly) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Unsaved seating layout changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    if (widget.readOnly) return;
    if (widget.draftOnly || widget.orderId.trim().isEmpty) {
      Navigator.pop(context, _plan);
      return;
    }
    setState(() => _saving = true);
    try {
      await EventsFeatureApi(apiBase: widget.apiBase).saveSeatingPlan(
        orderId: widget.orderId,
        orderKind: widget.orderKind,
        plan: _plan,
        userEmail: widget.userEmail,
        cashierEmail: widget.cashierEmail,
        cashierPassword: widget.cashierPassword,
      );
      if (!mounted) return;
      showAntdMessage(context, 'Seating layout saved.');
      Navigator.pop(context, _plan);
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(context, '$e', type: AntdMessageType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueRefs = venueReferencePhotosFromThemeDesign(widget.themeDesign);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.readOnly ? 'Seating layout' : 'Edit seating layout',
          ),
          actions: [
            if (!_plan.isEffectivelyEmpty) ...[
              IconButton(
                tooltip: 'Preview PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed:
                    () => previewSeatingLayoutPdf(
                      context: context,
                      plan: _plan,
                      eventTitle: widget.eventTitle,
                      transactionNo: widget.transactionNo,
                    ),
              ),
              IconButton(
                tooltip: 'Download image',
                icon: const Icon(Icons.image_outlined),
                onPressed:
                    () => saveSeatingLayoutImageToGallery(
                      context: context,
                      plan: _plan,
                    ),
              ),
            ],
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : Column(
                  children: [
                    if (venueRefs.isNotEmpty)
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(10),
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
                                ),
                              ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SeatingPlanInteractive(
                          plan: _plan,
                          editable: !widget.readOnly,
                          onChanged:
                              widget.readOnly
                                  ? null
                                  : (next) => setState(() => _plan = next),
                          venueReferencePhotosBase64: venueRefs,
                        ),
                      ),
                    ),
                    if (!widget.readOnly)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed:
                                    _saving
                                        ? null
                                        : () async {
                                          if (await _confirmDiscard() &&
                                              context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                child: const Text('Cancel'),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}
