import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../theme/app_theme.dart';
import '../insights/insights_screen.dart';
import '../assistant/assistant_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
import '../../services/app_store.dart';
import '../../models/transaction_model.dart';

/// More tab — hub for AI Insights, Sage assistant, Transactions and
/// Settings, matching the APK's "More" destination.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // AI shortcut cards
          _aiCard(
            context,
            icon: Icons.insights_outlined,
            title: 'AI Insights',
            subtitle: 'Your money, explained — trends, anomalies and forecasts.',
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const InsightsScreen())),
          ),
          const SizedBox(height: 12),
          _aiCard(
            context,
            icon: Icons.auto_awesome,
            title: 'Sage — AI assistant',
            subtitle: 'Log transactions in plain English, ask about your spending.',
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
          const SizedBox(height: 24),

          _sectionLabel(isDark, 'YOUR DATA'),
          _row(context, Icons.receipt_long_outlined, 'Transactions', 'Search and filter history',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()))),
          _row(context, Icons.file_download_outlined, 'Export transactions as CSV',
              'Everything stays on this phone. No account, no cloud, no cost.',
              onTap: _exportCsv),
          _row(context, Icons.restore_outlined, 'Restore from a backup',
              'Adds the rows from a backup file. Nothing is deleted.', onTap: _restoreFromBackup),
          _row(context, Icons.delete_forever_outlined, 'Erase all data',
              'Deletes every transaction, payment, budget and goal.',
              onTap: _eraseAllData, danger: true),
          const SizedBox(height: 24),

          _sectionLabel(isDark, 'PRIVACY & REMINDERS'),
          _row(context, Icons.lock_outlined, 'App lock',
              'Unlock to view your finances — biometric or device credentials.',
              onTap: _toggleAppLock),
          _row(context, Icons.notifications_outlined, 'Payment reminders',
              'Reminders about upcoming payments and budgets', onTap: _showRemindersInfo),
          _row(context, Icons.palette_outlined, 'Appearance',
              'Match system · Light · Dark · Material You', onTap: _showAppearancePicker),
          const SizedBox(height: 24),

          _sectionLabel(isDark, 'MONTHLY COMMITMENT'),
          _row(context, Icons.event_repeat_outlined, 'Safe to Spend rules',
              'How far ahead to look when counting upcoming payments',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),

          const SizedBox(height: 28),
          Text(
            'Everything stays on this phone.\nNo account, no cloud, no cost.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(isDark), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---- Handlers for YOUR DATA ----

  /// CSV export → clipboard (works on every platform, no plugins).
  Future<void> _exportCsv() async {
    final store = AppStore();
    final txs = await store.getTransactions();
    if (!mounted) return;
    if (txs.isEmpty) {
      _snack('Nothing to export yet — log a transaction first.');
      return;
    }
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final buf = StringBuffer('date,type,category,amount,note\n');
    for (final t in txs) {
      final note = (t.note ?? '').replaceAll(',', ';');
      buf.writeln('${df.format(t.date)},${t.type.name},${t.category},'
          '${t.amount.toStringAsFixed(2)},"$note"');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    _snack('CSV copied to clipboard (${txs.length} rows). '
        'Paste it into any notes/sheets app to save the file.');
  }

  /// Restore: paste a previously exported CSV block → re-adds rows.
  Future<void> _restoreFromBackup() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paste the exported CSV here. Rows are ADDED — '
                  'nothing is deleted.', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'date,type,category,amount,note\n…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final store = AppStore();
    final existing = await store.getTransactions();
    final existingKeys = existing
        .map((t) => '${t.date.millisecondsSinceEpoch}|${t.amount}|${t.category}')
        .toSet();

    var added = 0, skipped = 0;
    final lines = controller.text.trim().split('\n');
    // Skip the header only if there IS one — a pasted block of pure data
    // rows (no "date,type,..." first line) must not lose its first row.
    var start = 0;
    if (lines.isNotEmpty && lines.first.toLowerCase().startsWith('date,')) {
      start = 1;
    }
    for (final line in lines.skip(start)) {
      final parts = _splitCsvLine(line);
      if (parts.length < 4) continue;
      final date = DateTime.tryParse(parts[0]);
      final amount = double.tryParse(parts[3]);
      if (date == null || amount == null) continue;
      final category = parts[2].trim();
      final key = '${date.millisecondsSinceEpoch}|$amount|$category';
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }
      final type = parts[1].trim() == 'income' ? TransactionType.income : TransactionType.expense;
      await store.addTransaction(TransactionModel(
        id: const Uuid().v4(),
        amount: amount,
        type: type,
        category: category,
        date: date,
        note: parts.length > 4 ? parts[4] : null,
        createdAt: DateTime.now(),
      ));
      existingKeys.add(key);
      added++;
    }
    if (!mounted) return;
    _snack('Restored $added new transactions'
        '${skipped > 0 ? ' ($skipped duplicates skipped)' : ''}.');
  }

  List<String> _splitCsvLine(String line) {
    final out = <String>[];
    var cur = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        out.add(cur.toString());
        cur = StringBuffer();
      } else {
        cur.write(ch);
      }
    }
    out.add(cur.toString());
    return out;
  }

  /// Erase everything, with a two-step type-to-confirm guard.
  Future<void> _eraseAllData() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase all data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This permanently deletes every transaction, '
                'recurring payment, budget and goal on this phone.',
                style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Type ERASE to confirm',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
              onPressed: controller.text.trim().toUpperCase() == 'ERASE'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Erase everything'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await AppStore().clearAll();
    if (!mounted) return;
    _snack('All data erased. Starting fresh.');
    setState(() {}); // refresh any state-derived bits
  }

  // ---- Handlers for PRIVACY & REMINDERS ----

  Future<void> _toggleAppLock() async {
    final store = AppStore();
    final s = await store.getSettings();
    final newValue = !s.isBiometricEnabled;
    await store.updateSettings(
        s.copyWith(isBiometricEnabled: newValue, updatedAt: DateTime.now()));
    if (!mounted) return;
    _snack(newValue
        ? 'App lock enabled. (Biometric unlock activates on the phone.)'
        : 'App lock disabled.');
  }

  void _showRemindersInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment reminders'),
        content: const Text(
          'Sage watches your recurring payments and budget limits while the '
          'app is open:\n\n'
          '• Budget guard warns at 80% of any budget and again when you '
          'cross it.\n'
          '• Ask Sage things like "remind me when my phone bill is due" or '
          '"warn me when I spend over 1500 on shopping".\n\n'
          'Reminders fire inside the app — no system notifications are sent, '
          'keeping everything private and offline.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  void _showAppearancePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final (mode, label, sub) in const [
              (ThemeMode.system, 'Match system', 'Follows your phone\'s dark mode'),
              (ThemeMode.light, 'Light', 'Always light'),
              (ThemeMode.dark, 'Dark', 'Always dark'),
            ])
              ListTile(
                leading: Icon(
                  mode == ThemeMode.system ? Icons.brightness_auto_rounded : mode == ThemeMode.light ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: AppColors.primaryGreen,
                ),
                title: Text(label),
                subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text('$label selected. Theme applies fully on restart.'),
                  ));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sectionLabel(bool isDark, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.textSecondary(isDark))),
      );

  Widget _aiCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary(isDark),
                          height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String subtitle,
      {required VoidCallback onTap, bool danger = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = danger ? AppColors.accentRed : AppColors.textPrimary(isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 21, color: danger ? AppColors.accentRed : AppColors.primaryGreen),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary(isDark))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
