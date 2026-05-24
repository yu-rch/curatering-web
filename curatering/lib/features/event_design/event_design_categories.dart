import 'event_design_constants.dart';

class EventDesignCategories {
  const EventDesignCategories({
    required this.styles,
    required this.moods,
    required this.palettes,
    required this.decor,
  });

  final List<String> styles;
  final List<String> moods;
  final List<String> palettes;
  final List<String> decor;

  static EventDesignCategories get defaults => EventDesignCategories(
    styles: List<String>.from(kEventDesignStyles),
    moods: List<String>.from(kEventDesignMoods),
    palettes: List<String>.from(kEventDesignPalettes),
    decor: List<String>.from(kEventDesignDecor),
  );

  factory EventDesignCategories.fromJson(dynamic raw) {
    if (raw is! Map) return EventDesignCategories.defaults;
    List<String> list(dynamic key, List<String> fallback) {
      final value = raw[key];
      if (value is! List) return List<String>.from(fallback);
      final out =
          value.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
      return out.isEmpty ? List<String>.from(fallback) : out;
    }

    return EventDesignCategories(
      styles: list('styles', kEventDesignStyles),
      moods: list('moods', kEventDesignMoods),
      palettes: list('palettes', kEventDesignPalettes),
      decor: list('decor', kEventDesignDecor),
    );
  }

  Map<String, dynamic> toJson() => {
    'styles': styles,
    'moods': moods,
    'palettes': palettes,
    'decor': decor,
  };
}
