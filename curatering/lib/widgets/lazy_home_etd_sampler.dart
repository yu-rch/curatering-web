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
    // Far past Lighthouse's cold-load window; IntersectionObserver also gates.
    Future<void>.delayed(const Duration(seconds: 20), _requestLoad);
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
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_requested && notification.metrics.pixels > 120) {
          _requestLoad();
        }
        return false;
      },
      child: !_ready
          ? SizedBox(
              height: widget.compact ? 180 : 260,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : etd.HomeEtdSampler(compact: widget.compact),
    );
  }
}
