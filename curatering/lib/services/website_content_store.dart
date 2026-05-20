import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../utils/api_cache.dart';

/// Single gallery photo with optional search tags.
class GalleryImageData {
  final String id;
  String imageBase64;
  List<String> tags;

  GalleryImageData({
    required this.id,
    required this.imageBase64,
    List<String>? tags,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageBase64': imageBase64,
    'tags': tags,
  };

  factory GalleryImageData.fromJson(dynamic raw) {
    if (raw is String) {
      return GalleryImageData(
        id: 'img_${raw.hashCode.abs()}',
        imageBase64: raw,
      );
    }
    final m = Map<String, dynamic>.from(raw as Map);
    final tagsRaw = m['tags'];
    return GalleryImageData(
      id:
          (m['id'] ?? 'img_${DateTime.now().microsecondsSinceEpoch}')
              .toString(),
      imageBase64: (m['imageBase64'] ?? m['image'] ?? '').toString(),
      tags:
          tagsRaw is List
              ? tagsRaw
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : [],
    );
  }

  static GalleryImageData fromBase64(String b64, {List<String>? tags}) {
    return GalleryImageData(
      id: 'img_${DateTime.now().microsecondsSinceEpoch}',
      imageBase64: b64,
      tags: tags,
    );
  }
}

/// Editable copy for the Macrina’s customer-facing site (persisted locally).
class GalleryCategoryData {
  final String id;
  String label;
  final List<GalleryImageData> images;

  /// Applied to photos added via CMS before upload.
  List<String> defaultTagsForUpload = [];

  GalleryCategoryData({
    required this.id,
    required this.label,
    List<GalleryImageData>? images,
    List<String>? imageBase64List,
  }) : images =
           images ??
           (imageBase64List != null
               ? imageBase64List
                   .map((b) => GalleryImageData.fromBase64(b))
                   .toList()
               : []);

  /// Legacy access for callers still using base64 strings only.
  List<String> get imageBase64List => images.map((e) => e.imageBase64).toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'images': images.map((e) => e.toJson()).toList(),
  };

  factory GalleryCategoryData.fromJson(Map<String, dynamic> m) {
    final imgs = m['images'];
    final parsed = <GalleryImageData>[];
    if (imgs is List) {
      for (final e in imgs) {
        parsed.add(GalleryImageData.fromJson(e));
      }
    }
    return GalleryCategoryData(
      id: m['id'] as String,
      label: m['label'] as String? ?? '',
      images: parsed,
    );
  }

  void addImagesFromBase64(
    List<String> base64List, {
    List<String> defaultTags = const [],
  }) {
    for (final b64 in base64List) {
      images.add(GalleryImageData.fromBase64(b64, tags: defaultTags));
    }
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
      '<p>Macrina\'s Kitchen and Catering has been around servicing different types of events from birthday to company celebrations for more than 2 decades!</p>'
      '<p>Have an upcoming celebration? <strong>INQUIRE NOW!</strong> or checkout our event design works menu first.</p>';
  String redBannerText = '!!! WE CATER LUZON-WIDE !!!';
  String latestEventSectionLabel = 'LATEST EVENT';
  String popularDishesSectionLabel = 'POPULAR DISHES';
  String popularDishesSubtitle = 'Our all-time most requested dishes!';
  String eventDesignsSectionLabel = 'EVENT DESIGNS';
  String eventDesignsSubtitle = 'From decorations to dinnerware!';
  String galleryTitle = 'Gallery';
  String galleryIntro =
      'WE CATER TO MANY DIFFERENT TYPES OF EVENTS. TAKE A LOOK AT OUR WORK AND SEE SOME THINGS YOU MIGHT LIKE!';
  String contactTitle = 'Contact Us';
  String contactBannerText = 'WE\'D LOVE TO HEAR FROM YOU!';
  String contactReachUsLabel = 'YOU CAN REACH US VIA:';
  String footerPrivacyLabel = 'PRIVACY POLICY';
  final List<String> latestEventCollageBase64 = <String>[];

  final List<String> popularDishImageBase64 = <String>[];
  final List<String> popularDishLabels = <String>[];

  final List<String> eventDesignImageBase64 = <String>[];
  final Map<String, Map<String, double>> imageAlignments =
      <String, Map<String, double>>{};

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
  String contactPageIntro =
      '<p>We\'d love to hear from you. Send us a message and we\'ll respond as soon as possible.</p>';
  String footerCopyright =
      'COPYRIGHT © 2026 MACRINA\'S KITCHEN AND CATERING. POWERED BY CURATERING.';

  bool _loaded = false;

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    _loaded = true;
    try {
      ApiCache().invalidate('/api/website-content');
      final decoded = await ApiClient.instance.getJson(
        '/api/website-content',
        useCache: false,
      );
      final content = decoded['content'];
      if (content is Map<String, dynamic> && content.isNotEmpty) {
        _applyMap(content);
        await _writeLocalCacheBestEffort(_toMap());
      } else {
        await _loadFromLocalCache();
      }
    } catch (_) {
      await _loadFromLocalCache();
    }
    notifyListeners();
  }

  /// Pull latest published content from the server (e.g. after CMS save).
  Future<void> reloadFromServer() async {
    _loaded = false;
    await ensureLoaded(force: true);
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
    final map = _toMap();

    await _writeLocalCacheBestEffort(map);

    final result = await ApiClient.instance.putJson(
      '/api/website-content',
      body: {'content': map},
    );

    ApiCache().invalidate('/api/website-content');

    final saved = result['content'];
    if (saved is Map<String, dynamic> && saved.isNotEmpty) {
      _applyMap(saved);
      await _writeLocalCacheBestEffort(_toMap());
    }

    notifyListeners();
  }

  Future<void> _writeLocalCacheBestEffort(Map<String, dynamic> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (error) {
      debugPrint(
        '[website-content] local cache skipped, likely browser quota: $error',
      );
    }
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
    latestEventSubtitle =
        map['latestEventSubtitle'] as String? ?? latestEventSubtitle;
    latestEventBody = map['latestEventBody'] as String? ?? latestEventBody;
    redBannerText = map['redBannerText'] as String? ?? redBannerText;
    latestEventSectionLabel =
        map['latestEventSectionLabel'] as String? ?? latestEventSectionLabel;
    popularDishesSectionLabel =
        map['popularDishesSectionLabel'] as String? ??
        popularDishesSectionLabel;
    popularDishesSubtitle =
        map['popularDishesSubtitle'] as String? ?? popularDishesSubtitle;
    eventDesignsSectionLabel =
        map['eventDesignsSectionLabel'] as String? ?? eventDesignsSectionLabel;
    eventDesignsSubtitle =
        map['eventDesignsSubtitle'] as String? ?? eventDesignsSubtitle;
    galleryTitle = map['galleryTitle'] as String? ?? galleryTitle;
    galleryIntro = map['galleryIntro'] as String? ?? galleryIntro;
    contactTitle = map['contactTitle'] as String? ?? contactTitle;
    contactBannerText =
        map['contactBannerText'] as String? ?? contactBannerText;
    contactReachUsLabel =
        map['contactReachUsLabel'] as String? ?? contactReachUsLabel;
    footerPrivacyLabel =
        map['footerPrivacyLabel'] as String? ?? footerPrivacyLabel;
    contactFacebook = map['contactFacebook'] as String? ?? contactFacebook;
    contactAddress = map['contactAddress'] as String? ?? contactAddress;
    contactHours = map['contactHours'] as String? ?? contactHours;
    contactPhone = map['contactPhone'] as String? ?? contactPhone;
    contactEmail = map['contactEmail'] as String? ?? contactEmail;
    contactPageIntro = map['contactPageIntro'] as String? ?? contactPageIntro;
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
    final align = map['imageAlignments'];
    imageAlignments.clear();
    if (align is Map) {
      align.forEach((k, v) {
        if (k is! String || v is! Map) return;
        final x = (v['x'] as num?)?.toDouble() ?? 0;
        final y = (v['y'] as num?)?.toDouble() ?? 0;
        imageAlignments[k] = {'x': x, 'y': y};
      });
    }

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
    'latestEventSectionLabel': latestEventSectionLabel,
    'popularDishesSectionLabel': popularDishesSectionLabel,
    'popularDishesSubtitle': popularDishesSubtitle,
    'eventDesignsSectionLabel': eventDesignsSectionLabel,
    'eventDesignsSubtitle': eventDesignsSubtitle,
    'galleryTitle': galleryTitle,
    'galleryIntro': galleryIntro,
    'contactTitle': contactTitle,
    'contactBannerText': contactBannerText,
    'contactReachUsLabel': contactReachUsLabel,
    'footerPrivacyLabel': footerPrivacyLabel,
    'latestEventCollageBase64': latestEventCollageBase64,
    'popularDishImageBase64': popularDishImageBase64,
    'popularDishLabels': popularDishLabels,
    'eventDesignImageBase64': eventDesignImageBase64,
    'imageAlignments': imageAlignments,
    'galleryCategories': galleryCategories.map((e) => e.toJson()).toList(),
    'contactFacebook': contactFacebook,
    'contactAddress': contactAddress,
    'contactHours': contactHours,
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
    'contactPageIntro': contactPageIntro,
    'footerCopyright': footerCopyright,
  };
}
