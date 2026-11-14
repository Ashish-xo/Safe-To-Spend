import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/recurring_payment_model.dart';
import '../../models/user_settings_model.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';

/// Recurring payments screen — matches the APK's Payments tab:
/// "Add a recurring payment", "Due today/tomorrow", "Show active/paused",
/// "Your subscriptions cost X".
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<RecurringPaymentModel> _payments = [];
  UserSettings? _settings;
  bool _showPaused = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppStore().getSettings();
    final p = await AppStore().getRecurringPayments();
    setState(() {
      _settings = s;
      _payments = p;
    });
  }

  List<RecurringPaymentModel> get _visible =>
      _payments.where((p) => _showPaused || p.isActive).toList()
        ..sort((a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate));

  bool _isDue(RecurringPaymentModel p, int daysFromNow) {
    final target = DateTime.now().add(Duration(days: daysFromNow));
    final d = p.nextPaymentDate;
    return d.year == target.year && d.month == target.month && d.day == target.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = _settings?.currencySymbol ?? '₹';
    final active = _payments.where((p) => p.isActive).toList();
    final monthlyCost = active
        .map((p) => p.frequency == RecurrenceFrequency.daily
            ? p.amount * 30
            : p.frequency == RecurrenceFrequency.weekly
                ? p.amount * 4
                : p.frequency == RecurrenceFrequency.yearly
                    ? p.amount / 12
                    : p.amount)
        .fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: Icon(_showPaused ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: 'Include paused payments',
            onPressed: () => setState(() => _showPaused = !_showPaused),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (active.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.subscriptions_outlined, color: AppColors.accentBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your subscriptions cost $cur${monthlyCost.toStringAsFixed(0)} a month.',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_payments.isEmpty)
            _emptyState(isDark)
          else
            for (final p in _visible) _paymentTile(isDark, p, cur),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(Icons.event_repeat_outlined, size: 56, color: AppColors.textSecondary(isDark)),
        const SizedBox(height: 12),
        const Text('No payments yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Rent, phone bill, subscriptions — add them once and the app counts them for you.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary(isDark)),
        ),
      ],
    );
  }

  Widget _paymentTile(bool isDark, RecurringPaymentModel p, String cur) {
    final dueToday = _isDue(p, 0);
    final dueTomorrow = _isDue(p, 1);
    final overdue = p.nextPaymentDate.isBefore(DateTime.now()) && !dueToday;

    String dueLabel;
    Color dueColor;
    if (dueToday) {
      dueLabel = 'Due today';
      dueColor = AppColors.accentRed;
    } else if (dueTomorrow) {
      dueLabel = 'Due tomorrow';
      dueColor = const Color(0xFFB25E00);
    } else if (overdue) {
      dueLabel = 'Overdue';
      dueColor = AppColors.accentRed;
    } else {
      dueLabel = 'Next payment on ${_fmtDate(p.nextPaymentDate)}';
      dueColor = AppColors.textSecondary(isDark);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.categoryColor(p.name).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_repeat_outlined,
                size: 20, color: AppColors.categoryColor(p.name)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    if (!p.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary(isDark).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('PAUSED',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.textSecondary(isDark))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(dueLabel, style: TextStyle(fontSize: 12.5, color: dueColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$cur${p.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(_freqLabel(p.frequency),
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(isDark))),
            ],
          ),
        ],
      ),
    );
  }

  String _freqLabel(RecurrenceFrequency f) => switch (f) {
        RecurrenceFrequency.daily => 'Daily',
        RecurrenceFrequency.weekly => 'Weekly',
        RecurrenceFrequency.monthly => 'Monthly',
        RecurrenceFrequency.yearly => 'Yearly',
      };

  String _fmtDate(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';

  Future<void> _openSheet([RecurringPaymentModel? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    var frequency = existing?.frequency ?? RecurrenceFrequency.monthly;
    DateTime nextDate = existing?.nextPaymentDate ?? DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existing != null ? 'Edit payment' : 'Add a recurring payment',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Phone bill, on the 9th — a name helps you recognize it.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary(Theme.of(ctx).brightness == Brightness.dark))),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Give this payment a name'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'How much?', prefixText: '₹ '),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null || (double.tryParse(v ?? '0') ?? 0) <= 0
                            ? 'Amount must be more than zero'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('How often?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in RecurrenceFrequency.values)
                        ChoiceChip(
                          label: Text(_freqLabel(f)),
                          selected: frequency == f,
                          onSelected: (_) => setSheet(() => frequency = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined, size: 17),
                          label: Text('Next: ${_fmtDate(nextDate)}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: nextDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) setSheet(() => nextDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        final payment = RecurringPaymentModel(
                          id: existing?.id ?? const Uuid().v4(),
                          name: nameCtrl.text.trim(),
                          amount: double.parse(amountCtrl.text),
                          category: 'bill',
                          frequency: frequency,
                          nextPaymentDate: nextDate,
                          isActive: true,
                        );
                        await AppStore().addRecurringPayment(payment);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      child: Text(existing != null ? 'Save' : 'Add payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
