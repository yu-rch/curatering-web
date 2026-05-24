import 'package:flutter/material.dart';

import 'event_design_categories.dart';
import 'events_feature_api.dart';

class EventDesignAdminScreen extends StatefulWidget {
  const EventDesignAdminScreen({
    super.key,
    required this.apiBase,
    this.staffEmail = '',
    this.staffPassword = '',
  });

  final String apiBase;
  final String staffEmail;
  final String staffPassword;

  @override
  State<EventDesignAdminScreen> createState() => _EventDesignAdminScreenState();
}

class _EventDesignAdminScreenState extends State<EventDesignAdminScreen> {
  EventDesignCategories _categories = EventDesignCategories.defaults;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = EventsFeatureApi(apiBase: widget.apiBase);
      final categories = await api.getEventDesignCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await EventsFeatureApi(apiBase: widget.apiBase).saveEventDesignCategories(
        categories: _categories,
        staffEmail: widget.staffEmail,
        staffPassword: widget.staffPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event design categories saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _replace(String field, List<String> values) {
    setState(() {
      _categories = EventDesignCategories(
        styles: field == 'styles' ? values : _categories.styles,
        moods: field == 'moods' ? values : _categories.moods,
        palettes: field == 'palettes' ? values : _categories.palettes,
        decor: field == 'decor' ? values : _categories.decor,
      );
    });
  }

  void _addOption(String field, String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final current = switch (field) {
      'styles' => _categories.styles,
      'moods' => _categories.moods,
      'palettes' => _categories.palettes,
      _ => _categories.decor,
    };
    if (current.contains(clean)) return;
    _replace(field, [...current, clean]);
  }

  void _removeOption(String field, String value) {
    final current = switch (field) {
      'styles' => _categories.styles,
      'moods' => _categories.moods,
      'palettes' => _categories.palettes,
      _ => _categories.decor,
    };
    _replace(field, current.where((item) => item != value).toList());
  }

  Future<void> _promptAdd(String field, String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Add $title'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'New option'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Add'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value != null) _addOption(field, value);
  }

  Widget _categoryEditor(String field, String title, List<String> options) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _promptAdd(field, title),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  InputChip(
                    label: Text(option),
                    onDeleted: () => _removeOption(field, option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event theme design options'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
            ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      'These options appear in the customer Event Theme Design flow.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _categoryEditor('styles', 'Style', _categories.styles),
                    _categoryEditor(
                      'moods',
                      'Mood / lighting',
                      _categories.moods,
                    ),
                    _categoryEditor(
                      'palettes',
                      'Color palette',
                      _categories.palettes,
                    ),
                    _categoryEditor(
                      'decor',
                      'Decor elements',
                      _categories.decor,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Save all categories'),
                    ),
                  ],
                ),
              ),
    );
  }
}
