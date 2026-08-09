import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../utils/api_cache.dart';

/// Image that is either inline base64 (legacy) or a media-library id.
class CmsImageRef {
  String base64;
  String? mediaId;

  CmsImageRef({this.base64 = '', this.mediaId});

  bool get isEmpty =>
      (mediaId == null || mediaId!.isEmpty) && base64.trim().isEmpty;

  String get displayBase64 => base64;

  Map<String, dynamic> toJson() {
    if (mediaId != null && mediaId!.isNotEmpty) {
      return {'mediaId': mediaId};
    }
    return {'imageBase64': base64};
  }

  /// Serialize for lists that historically stored plain strings.
  dynamic toLegacyJson() {
    if (mediaId != null && mediaId!.isNotEmpty) {
      return {'mediaId': mediaId};
    }
    return base64;
  }

  factory CmsImageRef.fromDynamic(dynamic raw) {
    if (raw == null) return CmsImageRef();
    if (raw is String) return CmsImageRef(base64: raw);
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return CmsImageRef(
        mediaId: (m['mediaId'] ?? m['media_id'])?.toString(),
        base64: (m['imageBase64'] ?? m['image'] ?? m['dataBase64'] ?? '')
            .toString(),
      );
    }
    return CmsImageRef();
  }
}

/// Single gallery photo with optional search tags.
class GalleryImageData {
  final String id;
  String imageBase64;
  String? mediaId;
  List<String> tags;

  GalleryImageData({
    required this.id,
    this.imageBase64 = '',
    this.mediaId,
    List<String>? tags,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    if (mediaId != null && mediaId!.isNotEmpty) 'mediaId': mediaId,
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
      mediaId: (m['mediaId'] ?? m['media_id'])?.toString(),
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

  static GalleryImageData fromMediaId(String mediaId, {List<String>? tags}) {
    return GalleryImageData(
      id: 'img_$mediaId',
      mediaId: mediaId,
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

enum CmsSectionType { richText, heading, image, imageRow, cta }

class CmsSection {
  CmsSection({
    required this.id,
    required this.type,
    this.heading = '',
    this.bodyHtml = '',
    this.imageBase64 = '',
    this.mediaId,
    this.ctaLabel = '',
    this.ctaUrl = '',
    List<CmsImageRef>? images,
  }) : images = images ?? <CmsImageRef>[];

  final String id;
  CmsSectionType type;
  String heading;
  String bodyHtml;
  String imageBase64;
  String? mediaId;
  String ctaLabel;
  String ctaUrl;
  final List<CmsImageRef> images;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'heading': heading,
    'bodyHtml': bodyHtml,
    'imageBase64': imageBase64,
    if (mediaId != null && mediaId!.isNotEmpty) 'mediaId': mediaId,
    'ctaLabel': ctaLabel,
    'ctaUrl': ctaUrl,
    'images': images.map((e) => e.toJson()).toList(),
  };

  factory CmsSection.fromJson(Map<String, dynamic> m) {
    final typeName = (m['type'] ?? 'richText').toString();
    final type = CmsSectionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => CmsSectionType.richText,
    );
    final imgs = <CmsImageRef>[];
    final rawImgs = m['images'];
    if (rawImgs is List) {
      for (final e in rawImgs) {
        imgs.add(CmsImageRef.fromDynamic(e));
      }
    }
    return CmsSection(
      id: (m['id'] ?? 'sec_${DateTime.now().microsecondsSinceEpoch}').toString(),
      type: type,
      heading: (m['heading'] ?? '').toString(),
      bodyHtml: (m['bodyHtml'] ?? m['body'] ?? '').toString(),
      imageBase64: (m['imageBase64'] ?? '').toString(),
      mediaId: (m['mediaId'] ?? m['media_id'])?.toString(),
      ctaLabel: (m['ctaLabel'] ?? '').toString(),
      ctaUrl: (m['ctaUrl'] ?? '').toString(),
      images: imgs,
    );
  }
}

enum CmsNavTargetType { builtin, customPage, url }

class CmsNavItem {
  CmsNavItem({
    required this.id,
    required this.label,
    required this.targetType,
    required this.target,
    this.visible = true,
  });

  final String id;
  String label;
  CmsNavTargetType targetType;
  String target;
  bool visible;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'targetType': targetType.name,
    'target': target,
    'visible': visible,
  };

  factory CmsNavItem.fromJson(Map<String, dynamic> m) {
    final typeName = (m['targetType'] ?? 'builtin').toString();
    final type = CmsNavTargetType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => CmsNavTargetType.builtin,
    );
    return CmsNavItem(
      id: (m['id'] ?? 'nav_${DateTime.now().microsecondsSinceEpoch}').toString(),
      label: (m['label'] ?? 'Tab').toString(),
      targetType: type,
      target: (m['target'] ?? '/').toString(),
      visible: m['visible'] != false,
    );
  }
}

class CmsCustomPage {
  CmsCustomPage({
    required this.id,
    required this.slug,
    required this.title,
    List<CmsSection>? sections,
  }) : sections = sections ?? <CmsSection>[];

  final String id;
  String slug;
  String title;
  final List<CmsSection> sections;

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'sections': sections.map((e) => e.toJson()).toList(),
  };

  factory CmsCustomPage.fromJson(Map<String, dynamic> m) {
    final secs = <CmsSection>[];
    final raw = m['sections'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          secs.add(CmsSection.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return CmsCustomPage(
      id: (m['id'] ?? 'page_${DateTime.now().microsecondsSinceEpoch}').toString(),
      slug: (m['slug'] ?? 'page').toString(),
      title: (m['title'] ?? 'Untitled').toString(),
      sections: secs,
    );
  }
}

class WebsiteMediaItem {
  final String id;
  final String name;
  final String mime;
  final int byteSize;
  final List<String> tags;
  final DateTime? createdAt;
  String? dataBase64;

  WebsiteMediaItem({
    required this.id,
    required this.name,
    required this.mime,
    required this.byteSize,
    required this.tags,
    this.createdAt,
    this.dataBase64,
  });

  factory WebsiteMediaItem.fromJson(Map<String, dynamic> m) {
    return WebsiteMediaItem(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      mime: (m['mime'] ?? 'image/jpeg').toString(),
      byteSize: (m['byte_size'] is num)
          ? (m['byte_size'] as num).toInt()
          : int.tryParse('${m['byte_size']}') ?? 0,
      tags: m['tags'] is List
          ? (m['tags'] as List).map((e) => e.toString()).toList()
          : const [],
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
      dataBase64: (m['data_base64'] ?? m['dataBase64'])?.toString(),
    );
  }
}

class WebsiteRevisionItem {
  final String id;
  final String? note;
  final String? publishedBy;
  final DateTime? createdAt;

  WebsiteRevisionItem({
    required this.id,
    this.note,
    this.publishedBy,
    this.createdAt,
  });

  factory WebsiteRevisionItem.fromJson(Map<String, dynamic> m) {
    return WebsiteRevisionItem(
      id: (m['id'] ?? '').toString(),
      note: m['note']?.toString(),
      publishedBy: m['published_by']?.toString(),
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
    );
  }
}

class WebsiteContentStore extends ChangeNotifier {
  WebsiteContentStore._();
  static final WebsiteContentStore instance = WebsiteContentStore._();

  static const _prefsKey = 'website_content_v2_meta';

  /// In-memory cache of resolved media base64 by id.
  final Map<String, String> _mediaCache = {};

  String homeHeroImageBase64 = '';
  String? homeHeroMediaId;
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
  String restaurantPageTitle = 'RESTAURANT';
  String restaurantPageSubtitle = 'Order from our delicious restaurant menu';
  String cateringPageTitle = 'CATERING MENU';
  String cateringPageSubtitle =
      'Explore our catering packages and signature dishes';
  String inquiryPageTitle = 'INQUIRE';
  String inquiryPageSubtitle = 'Inquire for Catering or Event';
  String contactTitle = 'Contact Us';
  String contactBannerText = 'WE\'D LOVE TO HEAR FROM YOU!';
  String contactReachUsLabel = 'YOU CAN REACH US VIA:';
  String footerPrivacyLabel = 'Privacy Policy';
  String footerPrivacyBody =
      '<p>We respect your privacy. Contact details and inquiry data are used only to serve your event and orders.</p>';
  String navBrandLabel = 'MACRINA\'S';
  String contactFacebookUrl = 'https://www.facebook.com/3tavs';
  final List<String> latestEventCollageBase64 = <String>[];
  final List<String?> latestEventCollageMediaIds = <String?>[];

  final List<String> popularDishImageBase64 = <String>[];
  final List<String?> popularDishMediaIds = <String?>[];
  final List<String> popularDishLabels = <String>[];

  final List<String> eventDesignImageBase64 = <String>[];
  final List<String?> eventDesignMediaIds = <String?>[];
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

  final List<CmsNavItem> navItems = [
    CmsNavItem(id: 'nav_home', label: 'Home', targetType: CmsNavTargetType.builtin, target: '/'),
    CmsNavItem(id: 'nav_gallery', label: 'Gallery', targetType: CmsNavTargetType.builtin, target: '/gallery'),
    CmsNavItem(id: 'nav_catering', label: 'Catering Menu', targetType: CmsNavTargetType.builtin, target: '/catering-menu'),
    CmsNavItem(id: 'nav_restaurant', label: 'Restaurant', targetType: CmsNavTargetType.builtin, target: '/restaurant'),
    CmsNavItem(id: 'nav_inquire', label: 'Inquire Now', targetType: CmsNavTargetType.builtin, target: '/inquire'),
    CmsNavItem(id: 'nav_contact', label: 'Contact Us', targetType: CmsNavTargetType.builtin, target: '/contact-us'),
  ];

  final List<CmsCustomPage> customPages = [];

  /// Extra CMS sections appended to built-in pages (home, gallery, catering, restaurant, inquiry, contact).
  final Map<String, List<CmsSection>> pageExtraSections = {
    'home': <CmsSection>[],
    'gallery': <CmsSection>[],
    'catering': <CmsSection>[],
    'restaurant': <CmsSection>[],
    'inquiry': <CmsSection>[],
    'contact': <CmsSection>[],
  };

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
  bool _hydratedFromLocalCache = false;
  bool _draftMode = false;
  DateTime? publishedAt;
  DateTime? draftUpdatedAt;

  bool get isDraftMode => _draftMode;

  /// Apply persisted CMS content immediately so the homepage can paint without
  /// waiting for the network round-trip.
  Future<void> hydrateFromLocalCache() async {
    if (_hydratedFromLocalCache) return;
    await _loadFromLocalCache();
    _hydratedFromLocalCache = true;
    notifyListeners();
    // Resolve media IDs from cache refs so hero/collage aren't empty placeholders.
    try {
      await resolveMediaRefs();
      notifyListeners();
    } catch (e) {
      debugPrint('[website-content] hydrate media resolve failed: $e');
    }
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force && !_draftMode) return;

    if (!_hydratedFromLocalCache) {
      await _loadFromLocalCache();
      _hydratedFromLocalCache = true;
      notifyListeners();
      try {
        await resolveMediaRefs();
        notifyListeners();
      } catch (_) {
        /* keep text/metadata already applied */
      }
    }

    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/website-content',
        useCache: !force,
        cacheExpiry: const Duration(minutes: 10),
      );
      final content = decoded['content'];
      if (content is Map && content.isNotEmpty) {
        _applyMap(Map<String, dynamic>.from(content));
        publishedAt = DateTime.tryParse('${decoded['publishedAt'] ?? ''}');
        await _writeLocalCacheBestEffort(_toMap());
        await resolveMediaRefs();
      }
    } catch (_) {
      // Keep local/defaults already applied above.
    }
    _draftMode = false;
    _loaded = true;
    notifyListeners();
  }

  /// Staff: load draft content for CMS editing / preview.
  Future<void> loadDraft({bool force = true}) async {
    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/website-content/draft',
        useCache: false,
      );
      final content = decoded['content'];
      if (content is Map && content.isNotEmpty) {
        _applyMap(Map<String, dynamic>.from(content));
      }
      draftUpdatedAt = DateTime.tryParse('${decoded['draftUpdatedAt'] ?? ''}');
      publishedAt = DateTime.tryParse('${decoded['publishedAt'] ?? ''}');
      await resolveMediaRefs();
      _draftMode = true;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[website-content] loadDraft failed: $e');
      rethrow;
    }
  }

  /// Pull latest published content from the server (e.g. after CMS publish).
  Future<void> reloadFromServer() async {
    _loaded = false;
    _draftMode = false;
    await ensureLoaded(force: true);
  }

  Future<String?> resolveMediaId(String? mediaId) async {
    if (mediaId == null || mediaId.isEmpty) return null;
    final cached = _mediaCache[mediaId];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/website-media/$mediaId/public',
        useCache: true,
        cacheExpiry: const Duration(hours: 1),
      );
      final b64 = (decoded['dataBase64'] ?? '').toString();
      if (b64.isNotEmpty) {
        _mediaCache[mediaId] = b64;
        return b64;
      }
    } catch (e) {
      debugPrint('[website-content] resolveMediaId $mediaId failed: $e');
    }
    return null;
  }

  Future<void> resolveMediaRefs() async {
    if (homeHeroMediaId != null && homeHeroMediaId!.isNotEmpty) {
      homeHeroImageBase64 =
          (await resolveMediaId(homeHeroMediaId)) ?? homeHeroImageBase64;
    }
    await _resolveList(latestEventCollageBase64, latestEventCollageMediaIds);
    await _resolveList(popularDishImageBase64, popularDishMediaIds);
    await _resolveList(eventDesignImageBase64, eventDesignMediaIds);
    for (final cat in galleryCategories) {
      for (final img in cat.images) {
        if ((img.imageBase64.isEmpty) &&
            img.mediaId != null &&
            img.mediaId!.isNotEmpty) {
          img.imageBase64 = (await resolveMediaId(img.mediaId)) ?? '';
        }
      }
    }
  }

  Future<void> _resolveList(List<String> base64List, List<String?> mediaIds) async {
    while (mediaIds.length < base64List.length) {
      mediaIds.add(null);
    }
    for (var i = 0; i < mediaIds.length; i++) {
      final mid = mediaIds[i];
      if (mid == null || mid.isEmpty) continue;
      final b64 = await resolveMediaId(mid);
      if (b64 == null) continue;
      if (i < base64List.length) {
        base64List[i] = b64;
      } else {
        base64List.add(b64);
      }
    }
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

  /// Save draft only (does not publish to customers).
  Future<void> saveDraft() async {
    final map = _toMap();
    final result = await ApiClient.instance.putJson(
      '/api/website-content/draft',
      body: {'content': map},
    );
    ApiCache().invalidate('/api/website-content/draft');
    final saved = result['content'];
    if (saved is Map && saved.isNotEmpty) {
      _applyMap(Map<String, dynamic>.from(saved));
      await resolveMediaRefs();
    }
    draftUpdatedAt = DateTime.tryParse('${result['draftUpdatedAt'] ?? ''}');
    _draftMode = true;
    notifyListeners();
  }

  /// Publish current draft to live customer site.
  Future<void> publish({String note = 'publish'}) async {
    // Ensure latest local edits are in the draft first.
    await saveDraft();
    final result = await ApiClient.instance.postJson(
      '/api/website-content/publish',
      body: {'note': note},
    );
    ApiCache().invalidate('/api/website-content');
    ApiCache().invalidate('/api/website-content/draft');
    final content = result['content'];
    if (content is Map && content.isNotEmpty) {
      _applyMap(Map<String, dynamic>.from(content));
      await _writeLocalCacheBestEffort(_toMap());
      await resolveMediaRefs();
    }
    publishedAt = DateTime.tryParse('${result['publishedAt'] ?? ''}');
    _draftMode = false;
    notifyListeners();
  }

  /// Legacy immediate publish — used only if old callers remain; prefer [saveDraft]/[publish].
  Future<void> save() async {
    await publish(note: 'legacy save');
  }

  Future<List<WebsiteMediaItem>> listMedia({String query = ''}) async {
    final decoded = await ApiClient.instance.getJson(
      '/api/website-media',
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
      useCache: false,
    );
    final list = decoded['media'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => WebsiteMediaItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<WebsiteMediaItem> uploadMedia({
    required String dataBase64,
    String name = 'image',
    String mime = 'image/jpeg',
    List<String> tags = const [],
  }) async {
    final result = await ApiClient.instance.postJson(
      '/api/website-media',
      body: {
        'dataBase64': dataBase64,
        'name': name,
        'mime': mime,
        'tags': tags,
      },
    );
    final media = result['media'];
    final id = (media is Map ? media['id'] : result['id'])?.toString() ?? '';
    _mediaCache[id] = dataBase64.contains('base64,')
        ? dataBase64.split('base64,').last
        : dataBase64;
    return WebsiteMediaItem(
      id: id,
      name: name,
      mime: mime,
      byteSize: 0,
      tags: tags,
      dataBase64: dataBase64,
    );
  }

  Future<void> deleteMedia(String id) async {
    await ApiClient.instance.delete('/api/website-media/$id');
    _mediaCache.remove(id);
  }

  Future<List<WebsiteRevisionItem>> listRevisions() async {
    final decoded = await ApiClient.instance.getJson(
      '/api/website-content/revisions',
      useCache: false,
    );
    final list = decoded['revisions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => WebsiteRevisionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> restoreRevision(String id) async {
    final result = await ApiClient.instance.postJson(
      '/api/website-content/revisions/$id/restore',
    );
    final content = result['content'];
    if (content is Map && content.isNotEmpty) {
      _applyMap(Map<String, dynamic>.from(content));
      await resolveMediaRefs();
      _draftMode = true;
      notifyListeners();
    }
  }

  Future<void> _writeLocalCacheBestEffort(Map<String, dynamic> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final slim = _toLocalCacheMap(map);
      await prefs.setString(_prefsKey, jsonEncode(slim));
    } catch (error) {
      debugPrint(
        '[website-content] local cache skipped, likely browser quota: $error',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey);
        await prefs.remove('website_content_v1');
        await prefs.remove('flutter.website_content_v1');
      } catch (_) {
        /* ignore */
      }
    }
  }

  /// Text/metadata + mediaId refs — strip large base64 blobs, keep image IDs
  /// so first paint can resolve hero/collage without waiting on full API body.
  Map<String, dynamic> _toLocalCacheMap(Map<String, dynamic> full) {
    final slim = Map<String, dynamic>.from(full);

    dynamic hero = full['homeHeroImageBase64'] ?? full['homeHero'];
    if (hero is Map && (hero['mediaId'] ?? '').toString().trim().isNotEmpty) {
      slim['homeHeroImageBase64'] = {
        'mediaId': hero['mediaId'].toString().trim(),
      };
    } else if (homeHeroMediaId != null && homeHeroMediaId!.trim().isNotEmpty) {
      slim['homeHeroImageBase64'] = {'mediaId': homeHeroMediaId!.trim()};
    } else {
      slim['homeHeroImageBase64'] = '';
    }

    slim['latestEventCollageBase64'] = _mediaIdsOnlyList(
      full['latestEventCollageBase64'],
      latestEventCollageMediaIds,
    );
    slim['popularDishImageBase64'] = _mediaIdsOnlyList(
      full['popularDishImageBase64'],
      popularDishMediaIds,
    );
    slim['eventDesignImageBase64'] = _mediaIdsOnlyList(
      full['eventDesignImageBase64'],
      eventDesignMediaIds,
    );
    slim.remove('imageAlignments');
    final cats = slim['galleryCategories'];
    if (cats is List) {
      slim['galleryCategories'] =
          cats.map((raw) {
            if (raw is! Map) return raw;
            final m = Map<String, dynamic>.from(raw);
            final images = m['images'];
            if (images is List) {
              m['images'] =
                  images.map((img) {
                    if (img is! Map) return <String, dynamic>{};
                    final mid = (img['mediaId'] ?? '').toString().trim();
                    if (mid.isEmpty) return <String, dynamic>{};
                    return <String, dynamic>{'mediaId': mid};
                  }).toList();
            } else {
              m['images'] = <dynamic>[];
            }
            m.remove('imageBase64List');
            return m;
          }).toList();
    }
    return slim;
  }

  List<dynamic> _mediaIdsOnlyList(dynamic raw, List<String?> fallbackIds) {
    final out = <dynamic>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final mid = (e['mediaId'] ?? '').toString().trim();
          if (mid.isNotEmpty) out.add({'mediaId': mid});
        }
      }
    }
    if (out.isEmpty) {
      for (final mid in fallbackIds) {
        final id = (mid ?? '').trim();
        if (id.isNotEmpty) out.add({'mediaId': id});
      }
    }
    return out;
  }

  void touch() => notifyListeners();

  Future<void> _loadFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('website_content_v1');
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _applyMap(map);
    } catch (_) {
      /* keep defaults */
    }
  }

  void _applyImageList(
    dynamic raw,
    List<String> base64Target,
    List<String?> mediaIdTarget,
  ) {
    base64Target.clear();
    mediaIdTarget.clear();
    if (raw is! List) return;
    for (final e in raw) {
      final ref = CmsImageRef.fromDynamic(e);
      base64Target.add(ref.base64);
      mediaIdTarget.add(ref.mediaId);
    }
  }

  List<dynamic> _serializeImageList(
    List<String> base64List,
    List<String?> mediaIds,
  ) {
    final out = <dynamic>[];
    final n = base64List.length > mediaIds.length
        ? base64List.length
        : mediaIds.length;
    for (var i = 0; i < n; i++) {
      final mid = i < mediaIds.length ? mediaIds[i] : null;
      final b64 = i < base64List.length ? base64List[i] : '';
      if (mid != null && mid.isNotEmpty) {
        out.add({'mediaId': mid});
      } else {
        out.add(b64);
      }
    }
    return out;
  }

  void _applyMap(Map<String, dynamic> map) {
    final hero = CmsImageRef.fromDynamic(
      map['homeHeroImageBase64'] ?? map['homeHero'],
    );
    homeHeroImageBase64 = hero.base64;
    homeHeroMediaId = hero.mediaId;

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
    restaurantPageTitle =
        map['restaurantPageTitle'] as String? ?? restaurantPageTitle;
    restaurantPageSubtitle =
        map['restaurantPageSubtitle'] as String? ?? restaurantPageSubtitle;
    cateringPageTitle =
        map['cateringPageTitle'] as String? ?? cateringPageTitle;
    cateringPageSubtitle =
        map['cateringPageSubtitle'] as String? ?? cateringPageSubtitle;
    inquiryPageTitle = map['inquiryPageTitle'] as String? ?? inquiryPageTitle;
    inquiryPageSubtitle =
        map['inquiryPageSubtitle'] as String? ?? inquiryPageSubtitle;
    contactTitle = map['contactTitle'] as String? ?? contactTitle;
    contactBannerText =
        map['contactBannerText'] as String? ?? contactBannerText;
    contactReachUsLabel =
        map['contactReachUsLabel'] as String? ?? contactReachUsLabel;
    footerPrivacyLabel =
        map['footerPrivacyLabel'] as String? ?? footerPrivacyLabel;
    footerPrivacyBody =
        map['footerPrivacyBody'] as String? ?? footerPrivacyBody;
    navBrandLabel = map['navBrandLabel'] as String? ?? navBrandLabel;
    contactFacebookUrl =
        map['contactFacebookUrl'] as String? ?? contactFacebookUrl;
    contactFacebook = map['contactFacebook'] as String? ?? contactFacebook;
    contactAddress = map['contactAddress'] as String? ?? contactAddress;
    contactHours = map['contactHours'] as String? ?? contactHours;
    contactPhone = map['contactPhone'] as String? ?? contactPhone;
    contactEmail = map['contactEmail'] as String? ?? contactEmail;
    contactPageIntro = map['contactPageIntro'] as String? ?? contactPageIntro;
    footerCopyright = map['footerCopyright'] as String? ?? footerCopyright;

    _applyImageList(
      map['latestEventCollageBase64'],
      latestEventCollageBase64,
      latestEventCollageMediaIds,
    );
    _applyImageList(
      map['popularDishImageBase64'],
      popularDishImageBase64,
      popularDishMediaIds,
    );
    _applyImageList(
      map['eventDesignImageBase64'],
      eventDesignImageBase64,
      eventDesignMediaIds,
    );

    final labels = map['popularDishLabels'];
    if (labels is List) {
      popularDishLabels
        ..clear()
        ..addAll(labels.map((e) => e.toString()));
    }

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

    final navRaw = map['navItems'];
    if (navRaw is List && navRaw.isNotEmpty) {
      navItems
        ..clear()
        ..addAll(
          navRaw
              .whereType<Map>()
              .map((e) => CmsNavItem.fromJson(Map<String, dynamic>.from(e))),
        );
    }
    if (navItems.isEmpty) {
      _seedDefaultNav();
    }

    final pagesRaw = map['customPages'];
    customPages.clear();
    if (pagesRaw is List) {
      for (final e in pagesRaw) {
        if (e is Map) {
          customPages.add(
            CmsCustomPage.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    final extrasRaw = map['pageExtraSections'];
    if (extrasRaw is Map) {
      for (final key in pageExtraSections.keys) {
        final list = extrasRaw[key];
        pageExtraSections[key] = <CmsSection>[];
        if (list is List) {
          for (final e in list) {
            if (e is Map) {
              pageExtraSections[key]!.add(
                CmsSection.fromJson(Map<String, dynamic>.from(e)),
              );
            }
          }
        }
      }
    }
  }

  void _seedDefaultNav() {
    navItems
      ..clear()
      ..addAll([
        CmsNavItem(id: 'nav_home', label: 'Home', targetType: CmsNavTargetType.builtin, target: '/'),
        CmsNavItem(id: 'nav_gallery', label: 'Gallery', targetType: CmsNavTargetType.builtin, target: '/gallery'),
        CmsNavItem(id: 'nav_catering', label: 'Catering Menu', targetType: CmsNavTargetType.builtin, target: '/catering-menu'),
        CmsNavItem(id: 'nav_restaurant', label: 'Restaurant', targetType: CmsNavTargetType.builtin, target: '/restaurant'),
        CmsNavItem(id: 'nav_inquire', label: 'Inquire Now', targetType: CmsNavTargetType.builtin, target: '/inquire'),
        CmsNavItem(id: 'nav_contact', label: 'Contact Us', targetType: CmsNavTargetType.builtin, target: '/contact-us'),
      ]);
  }

  Map<String, dynamic> _toMap() {
    dynamic heroJson;
    if (homeHeroMediaId != null && homeHeroMediaId!.isNotEmpty) {
      heroJson = {'mediaId': homeHeroMediaId};
    } else {
      heroJson = homeHeroImageBase64;
    }

    return <String, dynamic>{
      'homeHeroImageBase64': heroJson,
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
      'restaurantPageTitle': restaurantPageTitle,
      'restaurantPageSubtitle': restaurantPageSubtitle,
      'cateringPageTitle': cateringPageTitle,
      'cateringPageSubtitle': cateringPageSubtitle,
      'inquiryPageTitle': inquiryPageTitle,
      'inquiryPageSubtitle': inquiryPageSubtitle,
      'contactTitle': contactTitle,
      'contactBannerText': contactBannerText,
      'contactReachUsLabel': contactReachUsLabel,
      'footerPrivacyLabel': footerPrivacyLabel,
      'footerPrivacyBody': footerPrivacyBody,
      'navBrandLabel': navBrandLabel,
      'contactFacebookUrl': contactFacebookUrl,
      'latestEventCollageBase64': _serializeImageList(
        latestEventCollageBase64,
        latestEventCollageMediaIds,
      ),
      'popularDishImageBase64': _serializeImageList(
        popularDishImageBase64,
        popularDishMediaIds,
      ),
      'popularDishLabels': popularDishLabels,
      'eventDesignImageBase64': _serializeImageList(
        eventDesignImageBase64,
        eventDesignMediaIds,
      ),
      'imageAlignments': imageAlignments,
      'galleryCategories': galleryCategories.map((e) => e.toJson()).toList(),
      'navItems': navItems.map((e) => e.toJson()).toList(),
      'customPages': customPages.map((e) => e.toJson()).toList(),
      'pageExtraSections': {
        for (final e in pageExtraSections.entries)
          e.key: e.value.map((s) => s.toJson()).toList(),
      },
      'contactFacebook': contactFacebook,
      'contactAddress': contactAddress,
      'contactHours': contactHours,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'contactPageIntro': contactPageIntro,
      'footerCopyright': footerCopyright,
    };
  }
}
