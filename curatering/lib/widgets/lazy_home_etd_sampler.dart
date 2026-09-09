import 'package:flutter/material.dart';

import 'home_etd_sampler.dart' deferred as etd;

/// Loads [HomeEtdSampler] only when near the viewport so cold load skips
/// the ETD sample images (~40–140 KiB).
class LazyHomeEtdSampler extends StatefulWidget {
  const LazyHomeEtdSampler({super.key, this.compact = true});

  final bool compact;

  @override
  State<LazyHomeEtdSampler> createState() => _LazyHomeEtdSamplerState();
}

class _LazyHomeEtdSamplerState extends State<LazyHomeEtdSampler> {
  bool _ready = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    // Defer until idle so LCP / first paint are not competing with ETD assets.
    Future<void>.delayed(const Duration(seconds: 3), _requestLoad);
  }

  void _requestLoad() {
    if (_requested || !mounted) return;
    _requested = true;
    etd.loadLibrary().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return SizedBox(
        height: widget.compact ? 180 : 260,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return etd.HomeEtdSampler(compact: widget.compact);
  }
}
