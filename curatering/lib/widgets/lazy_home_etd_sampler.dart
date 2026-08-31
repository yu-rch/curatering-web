import 'package:flutter/material.dart';

import 'home_etd_sampler.dart' deferred as etd;

/// Loads [HomeEtdSampler] in a separate deferred chunk after first frame.
class LazyHomeEtdSampler extends StatefulWidget {
  const LazyHomeEtdSampler({super.key, this.compact = true});

  final bool compact;

  @override
  State<LazyHomeEtdSampler> createState() => _LazyHomeEtdSamplerState();
}

class _LazyHomeEtdSamplerState extends State<LazyHomeEtdSampler> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      etd.loadLibrary().then((_) {
        if (mounted) setState(() => _ready = true);
      });
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
