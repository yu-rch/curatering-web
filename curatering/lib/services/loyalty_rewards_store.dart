import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  RewardsCondition({
    required this.id,
    required this.minimumPoints,
    required this.maximumPoints,
    required this.reward,
    required this.size,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'minimumPoints': minimumPoints,
    'maximumPoints': maximumPoints,
    'reward': reward,
    'size': size,
    'isActive': isActive,
  };

  factory RewardsCondition.fromJson(Map<String, dynamic> json) =>
      RewardsCondition(
        id: json['id'] as String,
        minimumPoints: (json['minimumPoints'] as num?)?.toInt() ?? 0,
        maximumPoints: (json['maximumPoints'] as num?)?.toInt() ?? 0,
        reward: json['reward'] as String? ?? '',
        size: json['size'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
      );

  /// Get description for display
  String get description => size;
}

/// Store for managing loyalty points conditions and reward redemption conditions
class LoyaltyRewardsStore extends ChangeNotifier {
  LoyaltyRewardsStore._();
  static final LoyaltyRewardsStore instance = LoyaltyRewardsStore._();

  static const _prefsKey = 'loyalty_rewards_v1';

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      // Initialize with default values
      _initializeDefaults();
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final pointsList = map['pointsConditions'] as List<dynamic>?;
      final rewardsList = map['rewardsConditions'] as List<dynamic>?;

      if (pointsList != null) {
        _pointsConditions =
            pointsList
                .map((p) => PointsCondition.fromJson(p as Map<String, dynamic>))
                .toList();
      }
      if (rewardsList != null) {
        _rewardsConditions =
            rewardsList
                .map(
                  (r) => RewardsCondition.fromJson(r as Map<String, dynamic>),
                )
                .toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading loyalty rewards: $e');
      _initializeDefaults();
    }
  }

  void _initializeDefaults() {
    // Default points conditions with 2% reward rate (0.02 points per 1 PHP)
    _pointsConditions = [
      // Restaurant: 100 min order to earn 2 points (2% rate)
      PointsCondition(
        id: '${DateTime.now().millisecondsSinceEpoch}_restaurant',
        minimumCost: 100.0,
        pointsApplication: 2,
        orderType: 'restaurant',
      ),
      // Catering: 500 min order to earn 8 points (2% rate)
      PointsCondition(
        id: '${DateTime.now().millisecondsSinceEpoch}_catering',
        minimumCost: 500.0,
        pointsApplication: 8,
        orderType: 'catering',
      ),
    ];
    // Default rewards with 0.02 PHP per point redemption value
    _rewardsConditions = [
      RewardsCondition(
        id: '${DateTime.now().millisecondsSinceEpoch}_1',
        minimumPoints: 100,
        maximumPoints: 100,
        reward: '₱2 Discount',
        size: '100 points = ₱2.00',
      ),
      RewardsCondition(
        id: '${DateTime.now().millisecondsSinceEpoch}_2',
        minimumPoints: 500,
        maximumPoints: 500,
        reward: '₱8 Discount',
        size: '500 points = ₱8.00',
      ),
      RewardsCondition(
        id: '${DateTime.now().millisecondsSinceEpoch}_3',
        minimumPoints: 1000,
        maximumPoints: 1000,
        reward: '₱16 Discount',
        size: '1000 points = ₱16.00',
      ),
    ];
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'pointsConditions': _pointsConditions.map((p) => p.toJson()).toList(),
        'rewardsConditions': _rewardsConditions.map((r) => r.toJson()).toList(),
      };
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving loyalty rewards: $e');
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
    _save();
    notifyListeners();
  }

  void updatePointsCondition(PointsCondition condition) {
    final index = _pointsConditions.indexWhere((p) => p.id == condition.id);
    if (index >= 0) {
      _pointsConditions[index] = condition;
      _save();
      notifyListeners();
    }
  }

  void archivePointsCondition(String id) {
    final index = _pointsConditions.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _pointsConditions[index].isActive = false;
      _save();
      notifyListeners();
    }
  }

  void deletePointsCondition(String id) {
    _pointsConditions.removeWhere((p) => p.id == id);
    _save();
    notifyListeners();
  }

  // Rewards Conditions Methods
  void addRewardsCondition({
    required int minimumPoints,
    required int maximumPoints,
    required String reward,
    required String size,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _rewardsConditions.add(
      RewardsCondition(
        id: id,
        minimumPoints: minimumPoints,
        maximumPoints: maximumPoints,
        reward: reward,
        size: size,
      ),
    );
    _save();
    notifyListeners();
  }

  void updateRewardsCondition(RewardsCondition condition) {
    final index = _rewardsConditions.indexWhere((r) => r.id == condition.id);
    if (index >= 0) {
      _rewardsConditions[index] = condition;
      _save();
      notifyListeners();
    }
  }

  void archiveRewardsCondition(String id) {
    final index = _rewardsConditions.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _rewardsConditions[index].isActive = false;
      _save();
      notifyListeners();
    }
  }

  void deleteRewardsCondition(String id) {
    _rewardsConditions.removeWhere((r) => r.id == id);
    _save();
    notifyListeners();
  }

  /// Get the applicable points earning for a given order cost and order type
  int getPointsForOrder(double orderCost, {String orderType = 'restaurant'}) {
    for (final condition in _pointsConditions.where(
      (p) => p.isActive && p.orderType == orderType,
    )) {
      if (orderCost >= condition.minimumCost) {
        // Calculate points with rounding rule: .2-.6 down, .7-.9 up
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

  /// Get minimum order amount to earn points for a specific order type
  double minimumOrderForPoints({String orderType = 'restaurant'}) {
    final filtered =
        _pointsConditions
            .where((p) => p.isActive && p.orderType == orderType)
            .toList();
    if (filtered.isEmpty) return orderType == 'restaurant' ? 100.0 : 500.0;
    return filtered.map((p) => p.minimumCost).reduce((a, b) => a < b ? a : b);
  }

  /// Get points earned per qualifying order for a specific order type
  int pointsEarned({String orderType = 'restaurant'}) {
    final filtered =
        _pointsConditions
            .where((p) => p.isActive && p.orderType == orderType)
            .toList();
    if (filtered.isEmpty) return orderType == 'restaurant' ? 2 : 8;
    return filtered.first.pointsApplication;
  }
}
