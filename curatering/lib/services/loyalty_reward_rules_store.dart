import 'package:flutter/foundation.dart';

import 'menu_store.dart';

/// Loyalty reward rows (min points + dish + size) kept in sync with [MenuStore] dishes.
class LoyaltyRewardRule {
  final String id;
  final String dishId;
  final int minPoints;
  final String sizeLabel;

  const LoyaltyRewardRule({
    required this.id,
    required this.dishId,
    required this.minPoints,
    required this.sizeLabel,
  });
}

class LoyaltyRewardRulesStore extends ChangeNotifier {
  LoyaltyRewardRulesStore._();
  static final LoyaltyRewardRulesStore instance = LoyaltyRewardRulesStore._();

  List<LoyaltyRewardRule> _rules = [];

  List<LoyaltyRewardRule> get rules => List.unmodifiable(_rules);

  void addRule({
    required String dishId,
    required int minPoints,
    required String sizeLabel,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _rules = [
      ..._rules,
      LoyaltyRewardRule(
        id: id,
        dishId: dishId,
        minPoints: minPoints,
        sizeLabel: sizeLabel.trim(),
      ),
    ];
    notifyListeners();
  }

  void removeRule(String id) {
    _rules = _rules.where((r) => r.id != id).toList();
    notifyListeners();
  }

  /// Archives the linked menu dish and drops this reward row (dish no longer active).
  void archiveRuleAndDish(String ruleId) {
    LoyaltyRewardRule? rule;
    for (final r in _rules) {
      if (r.id == ruleId) {
        rule = r;
        break;
      }
    }
    if (rule == null) return;
    MenuStore.instance.archiveDish(rule.dishId, archived: true);
    removeRule(ruleId);
  }
}
