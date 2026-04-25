import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Editable copy for the Macrina’s customer-facing site (persisted locally).
class GalleryCategoryData {
  final String id;
  String label;
  final List<String> imageBase64List;

  GalleryCategoryData({
    required this.id,
    required this.label,
    List<String>? imageBase64List,
  }) : imageBase64List = imageBase64List ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'images': imageBase64List,
      };

  factory GalleryCategoryData.fromJson(Map<String, dynamic> m) {
    final imgs = m['images'];
    return GalleryCategoryData(
      id: m['id'] as String,
      label: m['label'] as String? ?? '',
      imageBase64List: imgs is List ? imgs.map((e) => e.toString()).toList() : [],
    );
  }
}

class WebsiteContentStore extends ChangeNotifier {
  WebsiteContentStore._();
  static final WebsiteContentStore instance = WebsiteContentStore._();

  static const _prefsKey = 'website_content_v1';

  String homeHeroImageBase64 = '';
  String latestEventTitle = 'Maria Shiloh @ 1';
  String latestEventSubtitle = 'BY MACRINA\'S KITCHEN AND CATERING';
  String latestEventBody =
      'Macrina\'s Kitchen and Catering has been servicing celebrations across Luzon for over two decades.';
  final List<String> latestEventCollageBase64 = <String>[];

  String redBannerText = '!!! WE CATER LUZON-WIDE !!!';

  final List<String> popularDishImageBase64 = <String>[];
  final List<String> popularDishLabels = <String>[];

  final List<String> eventDesignImageBase64 = <String>[];

  final List<GalleryCategoryData> galleryCategories = [
    GalleryCategoryData(id: 'c1', label: 'FIRST BIRTHDAYS'),
    GalleryCategoryData(id: 'c2', label: '18TH BIRTHDAYS'),
    GalleryCategoryData(id: 'c3', label: '50TH BIRTHDAYS'),
    GalleryCategoryData(id: 'c4', label: 'CASUAL CELEBRATIONS'),
    GalleryCategoryData(id: 'c5', label: 'WEDDING RECEPTIONS'),
    GalleryCategoryData(id: 'c6', label: 'COMPANY CELEBRATIONS'),
  ];

  String contactFacebook = 'MACRINA\'S KITCHEN AND CATERING';
  String contactAddress = 'SAMPALOC EXT., TAGUIG, PHILIPPINES, 1633';
  String contactHours = '7:00 AM TO 10:00 PM';
  String contactPhone = '0917 138 7514';
  String contactEmail = 'MACRINA_CATERING@YAHOO.COM';
  String footerCopyright = 'COPYRIGHT © 2026 MACRINA\'S KITCHEN AND CATERING. POWERED BY CURATERING.';

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/website-content',
        useCache: false,
      );
      final content = decoded['content'];
      if (content is Map<String, dynamic>) {
        _applyMap(content);
      } else {
        await _loadFromLocalCache();
      }
    } catch (_) {
      await _loadFromLocalCache();
    }
    notifyListeners();
  }

  void _seedDefaultGallery() {
    galleryCategories
      ..clear()
      ..addAll([
        GalleryCategoryData(id: 'c1', label: 'FIRST BIRTHDAYS'),
        GalleryCategoryData(id: 'c2', label: '18TH BIRTHDAYS'),
        GalleryCategoryData(id: 'c3', label: '50TH BIRTHDAYS'),
        GalleryCategoryData(id: 'c4', label: 'CASUAL CELEBRATIONS'),
        GalleryCategoryData(id: 'c5', label: 'WEDDING RECEPTIONS'),
        GalleryCategoryData(id: 'c6', label: 'COMPANY CELEBRATIONS'),
      ]);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _toMap();

    // Always keep local cache as fallback.
    await prefs.setString(_prefsKey, jsonEncode(map));

    // Best-effort server sync so manager/super-admin edits reflect for customers.
    try {
      await ApiClient.instance.putJson(
        '/api/website-content',
        body: {'content': map},
      );
    } catch (_) {
      // Keep local cache behavior even when server sync fails.
    }
    notifyListeners();
  }

  void touch() => notifyListeners();

  Future<void> _loadFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _applyMap(map);
    } catch (_) {
      /* keep defaults */
    }
  }

  void _applyMap(Map<String, dynamic> map) {
    homeHeroImageBase64 = map['homeHeroImageBase64'] as String? ?? '';
    latestEventTitle = map['latestEventTitle'] as String? ?? latestEventTitle;
    latestEventSubtitle = map['latestEventSubtitle'] as String? ?? latestEventSubtitle;
    latestEventBody = map['latestEventBody'] as String? ?? latestEventBody;
    redBannerText = map['redBannerText'] as String? ?? redBannerText;
    contactFacebook = map['contactFacebook'] as String? ?? contactFacebook;
    contactAddress = map['contactAddress'] as String? ?? contactAddress;
    contactHours = map['contactHours'] as String? ?? contactHours;
    contactPhone = map['contactPhone'] as String? ?? contactPhone;
    contactEmail = map['contactEmail'] as String? ?? contactEmail;
    footerCopyright = map['footerCopyright'] as String? ?? footerCopyright;

    void replaceList(String key, List<String> target) {
      final v = map[key];
      if (v is List) {
        target
          ..clear()
          ..addAll(v.map((e) => e.toString()));
      }
    }

    replaceList('latestEventCollageBase64', latestEventCollageBase64);
    replaceList('popularDishImageBase64', popularDishImageBase64);
    replaceList('popularDishLabels', popularDishLabels);
    replaceList('eventDesignImageBase64', eventDesignImageBase64);

    final g = map['galleryCategories'];
    if (g is List) {
      galleryCategories.clear();
      for (final e in g) {
        if (e is Map) {
          galleryCategories.add(
            GalleryCategoryData.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    if (galleryCategories.isEmpty) {
      _seedDefaultGallery();
    }
  }

  Map<String, dynamic> _toMap() => <String, dynamic>{
        'homeHeroImageBase64': homeHeroImageBase64,
        'latestEventTitle': latestEventTitle,
        'latestEventSubtitle': latestEventSubtitle,
        'latestEventBody': latestEventBody,
        'redBannerText': redBannerText,
        'latestEventCollageBase64': latestEventCollageBase64,
        'popularDishImageBase64': popularDishImageBase64,
        'popularDishLabels': popularDishLabels,
        'eventDesignImageBase64': eventDesignImageBase64,
        'galleryCategories': galleryCategories.map((e) => e.toJson()).toList(),
        'contactFacebook': contactFacebook,
        'contactAddress': contactAddress,
        'contactHours': contactHours,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'footerCopyright': footerCopyright,
      };
}
