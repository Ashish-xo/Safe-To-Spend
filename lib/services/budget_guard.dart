import '../models/budget_goal_models.dart';
import '../models/transaction_model.dart';

/// Monitors spending against budgets. Sage runs this after EVERY logged
/// transaction, so threshold warnings fire the moment a limit is hit —
/// not the next time the user opens a screen.
class BudgetGuard {
  final List<BudgetModel> budgets;
  final List<TransactionModel> transactions;

  BudgetGuard({required this.budgets, required this.transactions});

  double spentInPeriod(String category) {
    final now = DateTime.now();
    var total = 0.0;
    for (final t in transactions) {
      if (t.type == TransactionType.expense &&
          t.category.toLowerCase() == category.toLowerCase() &&
          t.date.year == now.year &&
          t.date.month == now.month) {
        total += t.amount;
      }
    }
    return total;
  }

  /// The single most urgent alert across all budgets (for the Home banner).
  BudgetAlert? worstAlert() {
    BudgetAlert? worst;
    for (final b in budgets) {
      final a = alertFor(b);
      if (a == null) continue;
      if (worst == null || a.severity > worst.severity) worst = a;
    }
    return worst;
  }

  /// All currently active alerts, most severe first.
  List<BudgetAlert> activeAlerts() {
    final out = <BudgetAlert>[];
    for (final b in budgets) {
      final a = alertFor(b);
      if (a != null) out.add(a);
    }
    out.sort((x, y) => y.severity.compareTo(x.severity));
    return out;
  }

  /// Alert state for one budget: over (2) > approaching (1) > none.
  BudgetAlert? alertFor(BudgetModel b) {
    final spent = spentInPeriod(b.category);
    if (b.limitAmount <= 0) return null;
    final pct = spent / b.limitAmount;
    if (pct >= 1.0) {
      return BudgetAlert(
        budget: b,
        spent: spent,
        pct: pct,
        severity: 2,
        overBy: spent - b.limitAmount,
      );
    }
    if (pct >= b.warnAtPct / 100) {
      return BudgetAlert(
        budget: b,
        spent: spent,
        pct: pct,
        severity: 1,
        overBy: 0,
      );
    }
    return null;
  }

  /// Pre-flight check for a hypothetical expense: what will the user's
  /// budget state look like AFTER spending [amount] on [category]?
  /// Returns null if the category has no budget or stays comfortably under.
  BudgetAlert? checkAfterExpense(String category, double amount) {
    BudgetModel? b;
    for (final cand in budgets) {
      if (cand.category.toLowerCase() == category.toLowerCase()) b = cand;
    }
    if (b == null || b.limitAmount <= 0) return null;
    final spent = spentInPeriod(category) + amount;
    final pct = spent / b.limitAmount;
    if (pct >= 1.0) {
      return BudgetAlert(budget: b, spent: spent, pct: pct, severity: 2, overBy: spent - b.limitAmount);
    }
    if (pct >= b.warnAtPct / 100) {
      return BudgetAlert(budget: b, spent: spent, pct: pct, severity: 1, overBy: 0);
    }
    return null;
  }
}

class BudgetAlert {
  final BudgetModel budget;
  final double spent;
  final double pct; // 0..n, can exceed 1
  final int severity; // 1 = approaching, 2 = over
  final double overBy;

  BudgetAlert({
    required this.budget,
    required this.spent,
    required this.pct,
    required this.severity,
    required this.overBy,
  });

  bool get isOver => severity >= 2;

  /// The warning text Sage appends to a reply when a limit is hit.
  String warningText(String cur) {
    final cat = budget.category[0].toUpperCase() + budget.category.substring(1);
    if (isOver) {
      return '⚠️ You\'ve crossed your $cat budget — $cur${spent.toStringAsFixed(0)} of '
          '$cur${budget.limitAmount.toStringAsFixed(0)} (over by $cur${overBy.toStringAsFixed(0)}).';
    }
    return '⚠️ Heads up — that puts you at ${(pct * 100).toStringAsFixed(0)}% of your '
        '$cat budget ($cur${spent.toStringAsFixed(0)} of $cur${budget.limitAmount.toStringAsFixed(0)}).';
  }
}
