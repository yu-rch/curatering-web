import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_session.dart';
import '../config.dart';

/// Points earning condition (minimum cost to earn points)
class PointsCondition {
  String id;
  double minimumCost;
  int pointsApplication;
  bool isActive;
  String orderType; // 'restaurant' or 'catering'

  PointsCondition({
    required this.id,
    required this.minimumCost,
    required this.pointsApplication,
    this.isActive = true,
    this.orderType = 'restaurant',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'minimumCost': minimumCost,
    'pointsApplication': pointsApplication,
    'isActive': isActive,
    'orderType': orderType,
  };

  factory PointsCondition.fromJson(Map<String, dynamic> json) =>
      PointsCondition(
        id: json['id'] as String,
        minimumCost: (json['minimumCost'] as num?)?.toDouble() ?? 0.0,
        pointsApplication: (json['pointsApplication'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        orderType: json['orderType'] as String? ?? 'restaurant',
      );
}

/// Reward redemption condition (points range to redeem a reward)
class RewardsCondition {
  String id;
  int minimumPoints;
  int maximumPoints;
  String reward;
  String size;
  bool isActive;
  String orderType; // 'restaurant' or 'catering'

  RewardsCondition({
    required this.id,
    required this.minimumPoints,
    required this.maximumPoints,
    required this.reward,
    required this.size,
    this.isActive = true,
    this.orderType = 'restaurant',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'minimumPoints': minimumPoints,
    'maximumPoints': maximumPoints,
    'reward': reward,
    'size': size,
    'isActive': isActive,
    'orderType': orderType,
  };

  factory RewardsCondition.fromJson(Map<String, dynamic> json) =>
      RewardsCondition(
        id: json['id'] as String,
        minimumPoints: (json['minimumPoints'] as num?)?.toInt() ?? 0,
        maximumPoints: (json['maximumPoints'] as num?)?.toInt() ?? 0,
        reward: json['reward'] as String? ?? '',
        size: json['size'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        orderType: json['orderType'] as String? ?? 'restaurant',
      );

  /// Get description for display
  String get description => size;
}

/// Store for managing loyalty points conditions and reward redemption conditions.
/// Source of truth is the database (`system_settings.loyalty_program_config`).
class LoyaltyRewardsStore extends ChangeNotifier {
  LoyaltyRewardsStore._();
  static final LoyaltyRewardsStore instance = LoyaltyRewardsStore._();

  static const _prefsKey = 'loyalty_rewards_cache_v2';

  List<PointsCondition> _pointsConditions = [];
  List<RewardsCondition> _rewardsConditions = [];

  List<PointsCondition> get pointsConditions =>
      List.unmodifiable(_pointsConditions.where((p) => p.isActive));
  List<RewardsCondition> get rewardsConditions =>
      List.unmodifiable(_rewardsConditions.where((r) => r.isActive));
  List<PointsCondition> get allPointsConditions =>
      List.unmodifiable(_pointsConditions);
  List<RewardsCondition> get allRewardsConditions =>
      List.unmodifiable(_rewardsConditions);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await _loadFromApi();
  }

  Future<void> reloadFromApi() async {
    await _loadFromApi();
    notifyListeners();
  }

  Future<void> _loadFromApi() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/loyalty/program-config'),
      );
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        _applyConfig(map);
        await _cacheLocally();
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error loading loyalty program from API: $e');
    }

    await _loadFromCache();
    notifyListeners();
  }

  void _applyConfig(Map<String, dynamic> map) {
    final pointsList = map['pointsConditions'] as List<dynamic>?;
    final rewardsList = map['rewardsConditions'] as List<dynamic>?;

    _pointsConditions =
        pointsList
            ?.map((p) => PointsCondition.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];
    _rewardsConditions =
        rewardsList
            ?.map((r) => RewardsCondition.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      _applyConfig(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading loyalty cache: $e');
    }
  }

  Future<void> _cacheLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'pointsConditions': _pointsConditions.map((p) => p.toJson()).toList(),
          'rewardsConditions':
              _rewardsConditions.map((r) => r.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint('Error caching loyalty program: $e');
    }
  }

  Future<void> _persist() async {
    await _cacheLocally();
    final token = AuthSession.instance.token;
    if (token == null || token.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/manager/loyalty/program-config'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pointsConditions': _pointsConditions.map((p) => p.toJson()).toList(),
          'rewardsConditions':
              _rewardsConditions.map((r) => r.toJson()).toList(),
        }),
      );
      if (response.statusCode >= 400) {
        debugPrint('Failed to save loyalty program: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error saving loyalty program: $e');
    }
  }

  // Points Conditions Methods
  void addPointsCondition({
    required double minimumCost,
    required int pointsApplication,
    String orderType = 'restaurant',
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _pointsConditions.add(
      PointsCondition(
        id: id,
        minimumCost: minimumCost,
        pointsApplication: pointsApplication,
        orderType: orderType,
      ),
    );
    _persist();
    notifyListeners();
  }

  void updatePointsCondition(PointsCondition condition) {
    final index = _pointsConditions.indexWhere((p) => p.id == condition.id);
    if (index >= 0) {
      _pointsConditions[index] = condition;
      _persist();
      notifyListeners();
    }
  }

  void archivePointsCondition(String id) {
    final index = _pointsConditions.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _pointsConditions[index].isActive = false;
      _persist();
      notifyListeners();
    }
  }

  void deletePointsCondition(String id) {
    _pointsConditions.removeWhere((p) => p.id == id);
    _persist();
    notifyListeners();
  }

  // Rewards Conditions Methods
  void addRewardsCondition({
    required int minimumPoints,
    required int maximumPoints,
    required String reward,
    required String size,
    String orderType = 'restaurant',
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _rewardsConditions.add(
      RewardsCondition(
        id: id,
        minimumPoints: minimumPoints,
        maximumPoints: maximumPoints,
        reward: reward,
        size: size,
        orderType: orderType,
      ),
    );
    _persist();
    notifyListeners();
  }

  void updateRewardsCondition(RewardsCondition condition) {
    final index = _rewardsConditions.indexWhere((r) => r.id == condition.id);
    if (index >= 0) {
      _rewardsConditions[index] = condition;
      _persist();
      notifyListeners();
    }
  }

  void archiveRewardsCondition(String id) {
    final index = _rewardsConditions.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _rewardsConditions[index].isActive = false;
      _persist();
      notifyListeners();
    }
  }

  void deleteRewardsCondition(String id) {
    _rewardsConditions.removeWhere((r) => r.id == id);
    _persist();
    notifyListeners();
  }

  /// Get the applicable points earning for a given order cost and order type
  int getPointsForOrder(double orderCost, {String orderType = 'restaurant'}) {
    for (final condition in _pointsConditions.where(
      (p) => p.isActive && p.orderType == orderType,
    )) {
      if (orderCost >= condition.minimumCost) {
        final rawPoints = (orderCost * condition.pointsApplication) / 100;
        final decimal = rawPoints % 1;
        int points = rawPoints.floor();

        if (decimal >= 0.7) {
          points += 1;
        }

        return points;
      }
    }
    return 0;
  }

  double minimumOrderForPoints({String orderType = 'restaurant'}) {
    final filtered =
        _pointsConditions
            .where((p) => p.isActive && p.orderType == orderType)
            .toList();
    if (filtered.isEmpty) return orderType == 'restaurant' ? 100.0 : 500.0;
    return filtered.map((p) => p.minimumCost).reduce((a, b) => a < b ? a : b);
  }

  /// Percentage rate applied to qualifying order totals (not absolute points).
  int pointsRatePercent({String orderType = 'restaurant'}) {
    final filtered =
        _pointsConditions
            .where((p) => p.isActive && p.orderType == orderType)
            .toList();
    if (filtered.isEmpty) return orderType == 'restaurant' ? 2 : 8;
    return filtered.first.pointsApplication;
  }

  /// @deprecated Use [pointsRatePercent] — this returns the earn rate %, not points.
  int pointsEarned({String orderType = 'restaurant'}) =>
      pointsRatePercent(orderType: orderType);
}
