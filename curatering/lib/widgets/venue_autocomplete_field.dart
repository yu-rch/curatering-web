import 'package:flutter/material.dart';

import '../services/nominatim_service.dart';

/// Venue / address field with Nominatim autocomplete (debounced).
class VenueAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<String> savedAddresses;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onMapPickerPressed;

  const VenueAutocompleteField({
    super.key,
    required this.controller,
    this.label = 'Venue / address',
    this.savedAddresses = const [],
    this.onSelected,
    this.onMapPickerPressed,
  });

  @override
  State<VenueAutocompleteField> createState() => _VenueAutocompleteFieldState();
}

class _VenueAutocompleteFieldState extends State<VenueAutocompleteField> {
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final q = widget.controller.text.trim();
    if (q.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (widget.controller.text.trim() != q) return;
      final local =
          widget.savedAddresses
              .where((a) => a.toLowerCase().contains(q.toLowerCase()))
              .take(5)
              .toList();
      final remote = await NominatimService.instance.searchAddresses(
        q,
        limit: 5,
      );
      final merged = <String>{...local, ...remote}.take(8).toList();
      if (mounted && widget.controller.text.trim() == q) {
        setState(() => _suggestions = merged);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon:
                widget.onMapPickerPressed == null
                    ? const Icon(Icons.place_outlined)
                    : IconButton(
                      tooltip: 'Pick on map',
                      icon: const Icon(Icons.map_outlined),
                      onPressed: widget.onMapPickerPressed,
                    ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: ListView(
              shrinkWrap: true,
              children:
                  _suggestions
                      .map(
                        (s) => ListTile(
                          dense: true,
                          title: Text(s, style: const TextStyle(fontSize: 13)),
                          onTap: () {
                            widget.controller.text = s;
                            widget.onSelected?.call(s);
                            setState(() => _suggestions = const []);
                          },
                        ),
                      )
                      .toList(),
            ),
          ),
      ],
    );
  }
}
