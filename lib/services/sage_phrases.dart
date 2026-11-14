import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/recurring_payment_model.dart';
import '../models/user_settings_model.dart';
import '../services/app_store.dart';
import '../calculations/safe_to_spend_engine.dart';
import 'chat_assistant.dart' show AssistantReply;

/// Sage's response phrase templates — every reply is filled with REAL
/// numbers from the local DB. All handlers are 100% offline (no LLM call).
///
/// Handlers run BEFORE the LLM. Each returns null when the message doesn't
/// match, so unmatched messages fall through to the normal flow.
class SagePhrases {
  final AppStore store;
  SagePhrases(this.store);

  String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1000000) return v.round().toString();
    return v.toStringAsFixed(v.abs() < 100 ? 2 : 0);
  }

  int get _daysLeftInMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1).difference(now).inDays;
  }

  Future<double> _safeToSpend(UserSettings settings) async {
    final recurring = await store.getRecurringPayments();
    return SafeToSpendEngine.calculateSafeToSpend(
        currentBalance: settings.currentBalance,
        recurringPayments: recurring);
  }

  /// MAIN ENTRY: try every phrase handler. Returns null if none match.
  Future<AssistantReply?> handle(String message, UserSettings settings) async {
    final m = message.toLowerCase().trim();
    final cur = settings.currencySymbol;

    // --- 6. Conversational: thanks / help ---
    final casual = _casual(m);
    if (casual != null) return casual;

    // --- 1a. Remaining balance / daily limit ---
    if (RegExp(r'\b(how much is left|safe to spend|how much can i spend|'
            r'left to spend|remaining balance|how much (?:do|have) i (?:have|got) left)\b')
        .hasMatch(m)) {
      return _checkRemaining(settings, cur);
    }

    // --- 1b. Affordability: "can i afford a 800 concert ticket?" ---
    final afford = RegExp(
            r'can i afford[ a-z]*?\s*₹?\s*(\d+(?:\.\d+)?)')
        .firstMatch(m);
    if (afford != null) {
      return _affordabilityCheck(double.parse(afford.group(1)!), settings, cur);
    }

    // --- 2a. Undo / delete last ---
    if (RegExp(r'\b(undo|delete|remove)\b.*\b(last|recent|entry|expense|transaction|it|that)\b')
            .hasMatch(m) ||
        RegExp(r'^(undo|delete last|remove last)\b[.! ]*$').hasMatch(m)) {
      return _undoLast(settings, cur);
    }

    // --- 2b. Edit last entry ---
    if (RegExp(r'\b(change|edit|update|make)\b.*\bto\s+₹?\s*\d').hasMatch(m) &&
        RegExp(r'\b(last|it|that)\b').hasMatch(m)) {
      return _editLast(message, settings, cur);
    }

    // --- 3a. Today's spend ---
    if (RegExp(r'\b(spent|spend|spending)\b.*\btoday\b').hasMatch(m) ||
        RegExp(r'\btoday\b.*\b(spent|spend|spending)\b').hasMatch(m)) {
      return _todaySpend(cur);
    }

    // --- 3b. This week vs last week ---
    if (RegExp(r'\b(this week|this wk)\b').hasMatch(m) &&
        RegExp(r'\b(spend|spent|spending)\b').hasMatch(m)) {
      return _weekCompare(cur);
    }

    // --- 3c. Top spending category this month ---
    if (RegExp(r'\b(top|highest|most)\b.*\b(categor|spend|spent|money)\b')
        .hasMatch(m)) {
      return _topCategory(cur);
    }

    return null; // no match — fall through to the normal chat flow
  }

  // ============ 1. SAFE-TO-SPEND & DAILY LIMITS ============

  Future<AssistantReply> _checkRemaining(UserSettings settings, String cur) async {
    final remaining = await _safeToSpend(settings);
    final days = _daysLeftInMonth;
    if (remaining > 0 && days >= 2) {
      final dailyLimit = remaining / days;
      return AssistantReply(
          text: 'You have $cur${_fmt(remaining)} left to spend safely. '
              'That\'s roughly $cur${_fmt(dailyLimit)} per day until the end '
              'of the month.');
    }
    return AssistantReply(
        text: 'Your Safe to Spend balance is $cur${_fmt(remaining)} for the '
            'rest of the month.');
  }

  Future<AssistantReply> _affordabilityCheck(
      double amount, UserSettings settings, String cur) async {
    final remaining = await _safeToSpend(settings);
    final newRemaining = remaining - amount;
    if (newRemaining >= remaining * 0.25) {
      return AssistantReply(
          text: 'Yes — spending $cur${_fmt(amount)} leaves you with '
              '$cur${_fmt(newRemaining)} in your Safe to Spend balance.');
    } else if (newRemaining >= 0) {
      return AssistantReply(
          text: '⚠️ That\'s tight. Spending $cur${_fmt(amount)} will drop '
              'your Safe to Spend balance to $cur${_fmt(newRemaining)}.');
    }
    final shortfall = amount - remaining;
    return AssistantReply(
        text: '⚠️ Not recommended. $cur${_fmt(amount)} exceeds your remaining '
            'Safe to Spend limit by $cur${_fmt(shortfall)}.');
  }

  // ============ 2. EDITING & DELETING ============

  Future<AssistantReply> _undoLast(UserSettings settings, String cur) async {
    final txs = await store.getTransactions();
    if (txs.isEmpty) {
      return AssistantReply(text: 'There are no recent transactions to undo.');
    }
    final last = txs.last;
    await store.deleteTransaction(last.id);
    // Restore the balance so Safe to Spend reflects the removal.
    final delta = last.type == TransactionType.expense ? last.amount : -last.amount;
    await store.updateSettings(UserSettings(
      initialBalance: settings.initialBalance,
      currentBalance: settings.currentBalance + delta,
      currencySymbol: settings.currencySymbol,
      isBiometricEnabled: settings.isBiometricEnabled,
      updatedAt: DateTime.now(),
    ));
    final updated = await store.getSettings();
    final remaining = await _safeToSpend(updated);
    final note = (last.note != null && last.note!.isNotEmpty)
        ? ' ("${last.note}")' : '';
    return AssistantReply(
        text: 'Deleted your last entry: $cur${_fmt(last.amount)} for '
            '${last.category}$note. Your Safe to Spend balance is restored '
            '(now $cur${_fmt(remaining)}).');
  }

  Future<AssistantReply> _editLast(
      String message, UserSettings settings, String cur) async {
    final m = message.toLowerCase().trim();
    final match =
        RegExp(r'\bto\s+₹?\s*(\d+(?:\.\d+)?)').firstMatch(m);
    if (match == null) {
      return AssistantReply(text: 'How much should I change it to?');
    }
    final newAmount = double.parse(match.group(1)!);
    final txs = await store.getTransactions();
    if (txs.isEmpty) {
      return AssistantReply(text: 'There are no recent transactions to edit.');
    }
    final last = txs.last;
    String? newCat;
    for (final c in [
      'food', 'transport', 'groceries', 'entertainment', 'shopping',
      'health', 'education', 'rent', 'utilities'
    ]) {
      if (m.contains(c)) {
        newCat = c;
        break;
      }
    }
    final cat = newCat ?? last.category;

    // Balance adjustment: undo the old effect, apply the new.
    final delta = last.type == TransactionType.expense
        ? (last.amount - newAmount)
        : (newAmount - last.amount);
    await store.updateSettings(UserSettings(
      initialBalance: settings.initialBalance,
      currentBalance: settings.currentBalance + delta,
      currencySymbol: settings.currencySymbol,
      isBiometricEnabled: settings.isBiometricEnabled,
      updatedAt: DateTime.now(),
    ));
    // Replace: delete + re-add (no updateTransaction in the store yet).
    await store.deleteTransaction(last.id);
    await store.addTransaction(TransactionModel(
      id: const Uuid().v4(),
      amount: newAmount,
      type: last.type,
      category: cat,
      date: last.date,
      note: last.note,
      createdAt: DateTime.now(),
    ));
    return AssistantReply(
        text: 'Updated! Changed that expense to $cur${_fmt(newAmount)} under $cat.');
  }

  // ============ 3. TIME-BASED & COMPARATIVE INSIGHTS ============

  Future<AssistantReply> _todaySpend(String cur) async {
    final txs = await store.getTransactions();
    double total = 0;
    int count = 0;
    final now = DateTime.now();
    for (final t in txs) {
      if (t.type == TransactionType.expense &&
          t.date.year == now.year && t.date.month == now.month &&
          t.date.day == now.day) {
        total += t.amount;
        count++;
      }
    }
    return AssistantReply(
        text: 'Today, you\'ve spent $cur${_fmt(total)} across $count transactions.');
  }

  Future<AssistantReply> _weekCompare(String cur) async {
    final txs = await store.getTransactions();
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    double thisWeek = 0, lastWeek = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (!t.date.isBefore(weekStart)) thisWeek += t.amount;
      if (t.date.isAfter(lastWeekStart) && t.date.isBefore(weekStart)) {
        lastWeek += t.amount;
      }
    }
    if (lastWeek == 0) {
      return AssistantReply(
          text: 'You spent $cur${_fmt(thisWeek)} this week. No spending '
              'logged for last week to compare with yet.');
    }
    final pct = (((thisWeek - lastWeek).abs() / lastWeek) * 100).round();
    final moreOrLess = thisWeek >= lastWeek ? 'more' : 'less';
    return AssistantReply(
        text: 'You spent $cur${_fmt(thisWeek)} this week, which is $pct% '
            '$moreOrLess than last week.');
  }

  Future<AssistantReply> _topCategory(String cur) async {
    final txs = await store.getTransactions();
    final now = DateTime.now();
    final totals = <String, double>{};
    for (final t in txs) {
      if (t.type == TransactionType.expense &&
          t.date.year == now.year && t.date.month == now.month) {
        totals[t.category] = (totals[t.category] ?? 0) + t.amount;
      }
    }
    if (totals.isEmpty) {
      return AssistantReply(
          text: 'No spending logged this month yet — log an expense and '
              'I\'ll find your top category.');
    }
    var bestCat = '';
    var best = 0.0;
    totals.forEach((cat, amt) {
      if (amt > best) {
        best = amt;
        bestCat = cat;
      }
    });
    return AssistantReply(
        text: 'Your top spending category this month is $bestCat at '
            '$cur${_fmt(best)}. Most of your money went toward $bestCat '
            '($cur${_fmt(best)}) so far.');
  }

  // ============ 4. INCOME & ADDING FUNDS ============

  /// Called by ChatAssistant after logging an INCOME transaction, so the
  /// confirmation uses the template + live Safe to Spend. Settings are
  /// re-fetched because addTransaction already updated the balance.
  Future<String> incomeConfirmation(UserSettings oldSettings, TransactionModel tx) async {
    final settings = await store.getSettings();
    final cur = settings.currencySymbol;
    final remaining = await _safeToSpend(settings);
    final note = (tx.note != null && tx.note!.isNotEmpty) ? ' ("${tx.note}")' : '';
    return 'Got it! Logged $cur${_fmt(tx.amount)} under Income$note. '
        'Your Safe to Spend balance increased to $cur${_fmt(remaining)}.';
  }

  // ============ 5. RECURRING BILLS & SUBSCRIPTIONS ============

  Future<AssistantReply?> recurringReminder(
      String message, UserSettings settings) async {
    final m = message.toLowerCase().trim();
    if (!RegExp(r'\b(bill|subscription|remind|recurring|monthly|every)\b')
        .hasMatch(m)) {
      return null;
    }
    final match = RegExp(r'₹?\s*(\d+(?:\.\d+)?)').firstMatch(m) ??
        RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(m);
    if (match == null) return null;
    final amount = double.parse(match.group(1)!);
    if (amount <= 0) return null;

    // Name: word(s) between the amount and "bill/subscription/payment".
    final nameMatch = RegExp(
            r'\d+(?:\.\d+)?\s+(?:for\s+|rs\.?\s*|₹\s*)?([a-z0-9][a-z0-9 \-]*?)\s*(?:bill|payment|subscription|$)')
        .firstMatch(m);
    final name = (nameMatch?.group(1) ?? '').trim();
    final nameClean = name.isEmpty ? 'bill' : name;

    var freq = RecurrenceFrequency.monthly;
    if (m.contains('week')) freq = RecurrenceFrequency.weekly;
    if (m.contains('year') || m.contains('annual')) freq = RecurrenceFrequency.yearly;
    if (m.contains('daily') || m.contains('every day')) {
      freq = RecurrenceFrequency.daily;
    }

    final dayMatch = RegExp(r'on the (\d+)(?:st|nd|rd|th)?').firstMatch(m);
    var nextDate = DateTime.now().add(const Duration(days: 30));
    if (dayMatch != null) {
      final day = int.parse(dayMatch.group(1)!);
      final now = DateTime.now();
      nextDate = DateTime(now.year, now.month, day);
      if (nextDate.isBefore(now)) nextDate = DateTime(now.year, now.month + 1, day);
    }

    await store.addRecurringPayment(RecurringPaymentModel(
      id: const Uuid().v4(),
      name: nameClean,
      amount: amount,
      category: _guessCategoryFromText(nameClean),
      frequency: freq,
      nextPaymentDate: nextDate,
    ));

    final cur = settings.currencySymbol;
    final daysAway = nextDate.difference(DateTime.now()).inDays;
    final dayOrdinal = _ordinal(nextDate.day);
    return AssistantReply(
        text: 'Noted. I\'ll remind you about your $cur${_fmt(amount)} '
            '$nameClean bill on the $dayOrdinal of every month.\n\n'
            '📅 Reminder: Your $cur${_fmt(amount)} $nameClean bill is due in '
            '$daysAway days. I\'ve factored this into your Safe to Spend.');
  }

  String _guessCategoryFromText(String text) {
    final t = text.toLowerCase();
    if (t.contains('netflix') || t.contains('spotify') || t.contains('movie')) {
      return 'entertainment';
    }
    if (t.contains('wifi') || t.contains('internet') || t.contains('mobile') ||
        t.contains('recharge') || t.contains('electricity')) {
      return 'utilities';
    }
    if (t.contains('rent') || t.contains('hostel') || t.contains('pg')) {
      return 'rent';
    }
    if (t.contains('gym') || t.contains('doctor') || t.contains('medicine')) {
      return 'health';
    }
    return 'utilities';
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  // ============ 6. CASUAL / CONVERSATIONAL ============

  AssistantReply? _casual(String m) {
    if (RegExp(r'^(thanks|thank you|thx|ty|shukriya|dhanyavaad)\b[!.,? ]*$')
        .hasMatch(m)) {
      return AssistantReply(
          text: 'You\'re welcome! Let me know whenever you want to log '
              'another expense.');
    }
    if (RegExp(r'^what can you do\??$|^help$|^what should i say\??$')
        .hasMatch(m)) {
      return AssistantReply(
          text: 'I work 100% offline to track your money. You can say things like:\n'
              '• \'Spent 120 on auto\'\n'
              '• \'How much is left to spend?\'\n'
              '• \'Delete my last entry\'\n'
              '• \'Set a 2000 limit for shopping\'');
    }
    return null;
  }
}
