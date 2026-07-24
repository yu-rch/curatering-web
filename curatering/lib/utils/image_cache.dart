import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// LRU cache for decoded base64 images to prevent repeated decoding
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  final Map<String, Uint8List> _imageBytesCache = {};
  final Map<String, ui.Image> _uiImageCache = {};
  final List<String> _accessOrder = [];
  static const int _maxCacheSize = 50; // Maximum cached images

  /// Get cached image bytes or decode and cache
  Uint8List? getImageBytes(String base64String) {
    if (base64String.isEmpty) return null;

    // Update access order
    _accessOrder.remove(base64String);
    _accessOrder.add(base64String);

    // Return from cache if available
    if (_imageBytesCache.containsKey(base64String)) {
      return _imageBytesCache[base64String];
    }

    // Decode and cache
    try {
      final bytes = base64Decode(base64String);
      _addToCache(base64String, bytes);
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Pre-decode image to ui.Image for faster rendering
  Future<ui.Image?> getUIImage(String base64String) async {
    if (base64String.isEmpty) return null;

    if (_uiImageCache.containsKey(base64String)) {
      return _uiImageCache[base64String];
    }

    final bytes = getImageBytes(base64String);
    if (bytes == null) return null;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _uiImageCache[base64String] = frame.image;
      return frame.image;
    } catch (e) {
      return null;
    }
  }

  void _addToCache(String key, Uint8List bytes) {
    // Evict oldest if at capacity
    if (_imageBytesCache.length >= _maxCacheSize && _accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      _imageBytesCache.remove(oldest);
      _uiImageCache.remove(oldest);
    }

    _imageBytesCache[key] = bytes;
  }

  /// Clear all cached images
  void clear() {
    for (final image in _uiImageCache.values) {
      image.dispose();
    }
    _uiImageCache.clear();
    _imageBytesCache.clear();
    _accessOrder.clear();
  }

  /// Preload images for smoother scrolling
  Future<void> preloadImages(List<String> base64Strings) async {
    for (final base64 in base64Strings) {
      if (base64.isNotEmpty && !_imageBytesCache.containsKey(base64)) {
        getImageBytes(base64);
      }
    }
  }
}

  /// Optimized widget for displaying cached base64 images
class CachedBase64Image extends StatelessWidget {
  final String? base64String;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const CachedBase64Image({
    super.key,
    required this.base64String,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.isEmpty) {
      return placeholder ?? _defaultPlaceholder();
    }

    final normalized =
        base64String!
            .replaceFirst(RegExp(r'^data:image\/[^;]+;base64,'), '')
            .replaceAll('\n', '')
            .trim();
    final bytes = ImageCacheManager().getImageBytes(normalized);
    if (bytes == null) {
      return placeholder ?? _defaultPlaceholder();
    }

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheW =
        width != null && width!.isFinite && width! > 0
            ? (width! * dpr).round()
            : null;
    final cacheH =
        height != null && height!.isFinite && height! > 0
            ? (height! * dpr).round()
            : null;

    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      cacheHeight: cacheW == null ? cacheH : null,
      errorBuilder: (context, error, stackTrace) {
        return placeholder ?? _defaultPlaceholder();
      },
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
    );
  }
}
