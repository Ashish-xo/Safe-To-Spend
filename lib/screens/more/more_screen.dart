import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../insights/insights_screen.dart';
import '../assistant/assistant_screen.dart';

/// More tab — hub for AI Insights, Sage assistant, Transactions and
/// Settings, matching the APK's "More" destination.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
              onTap: () {}),
          _row(context, Icons.file_download_outlined, 'Export transactions as CSV',
              'Everything stays on this phone. No account, no cloud, no cost.',
              onTap: () {}),
          _row(context, Icons.restore_outlined, 'Restore from a backup',
              'Adds the rows from a backup file. Nothing is deleted.', onTap: () {}),
          _row(context, Icons.delete_forever_outlined, 'Erase all data',
              'Deletes every transaction, payment, budget and goal.',
              onTap: () {}, danger: true),
          const SizedBox(height: 24),

          _sectionLabel(isDark, 'PRIVACY & REMINDERS'),
          _row(context, Icons.lock_outlined, 'App lock',
              'Unlock to view your finances — biometric or device credentials.',
              onTap: () {}),
          _row(context, Icons.notifications_outlined, 'Payment reminders',
              'Reminders about upcoming payments and budgets', onTap: () {}),
          _row(context, Icons.palette_outlined, 'Appearance',
              'Match system · Light · Dark · Material You', onTap: () {}),
          const SizedBox(height: 24),

          _sectionLabel(isDark, 'MONTHLY COMMITMENT'),
          _row(context, Icons.event_repeat_outlined, 'Safe to Spend rules',
              'How far ahead to look when counting upcoming payments', onTap: () {}),

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
