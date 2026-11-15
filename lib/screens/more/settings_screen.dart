import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user_settings_model.dart';
import '../../services/app_store.dart';
import '../../calculations/safe_to_spend_engine.dart';

/// Settings screen opened from More → "Safe to Spend rules" (and it hosts
/// the Appearance + App lock toggles). Everything saves instantly to the
/// store — no explicit save button to forget.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _horizons = {7: '1 week', 14: '2 weeks', 30: '1 month', 60: '2 months'};

  UserSettings? _settings;
  int _horizon = 30;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = AppStore();
    final s = await store.getSettings();
    if (!mounted) return;
    setState(() => _settings = s);
  }

  Future<void> _save(UserSettings s) async {
    setState(() => _saving = true);
    final store = AppStore();
    await store.updateSettings(s.copyWith(updatedAt: DateTime.now()));
    if (!mounted) return;
    setState(() {
      _settings = s;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _settings;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Safe to Spend rules')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // --- Look-ahead horizon ---
          Text(
            'How far ahead should Safe to Spend look when counting upcoming payments?',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary(isDark), height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in _horizons.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _horizon == entry.key,
                  onSelected: (_) => setState(() => _horizon = entry.key),
                  selectedColor: AppColors.primaryGreen.withValues(alpha: 0.25),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview with your current data',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary(isDark))),
                const SizedBox(height: 8),
                _PreviewRow(horizon: _horizon),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- Appearance ---
          _sectionLabel(isDark, 'APPEARANCE'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {Theme.of(context).brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light},
            onSelectionChanged: (modes) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Theme setting applies app-wide on restart: ${modes.first.name}'),
              ));
            },
          ),
          const SizedBox(height: 28),

          // --- Security ---
          _sectionLabel(isDark, 'SECURITY'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App lock', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('Require unlock when opening the app',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark))),
            value: s.isBiometricEnabled,
            onChanged: (v) => _save(s.copyWith(isBiometricEnabled: v)),
          ),
          const SizedBox(height: 8),
          Text(
            _saving ? 'Saving…' : 'All settings save instantly to this phone.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark)),
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
}

/// Live preview: recomputes Safe to Spend with the chosen horizon.
class _PreviewRow extends StatefulWidget {
  final int horizon;
  const _PreviewRow({required this.horizon});

  @override
  State<_PreviewRow> createState() => _PreviewRowState();
}

class _PreviewRowState extends State<_PreviewRow> {
  static const _horizons = {7: '1 week', 14: '2 weeks', 30: '1 month', 60: '2 months'};
  double? _result;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant _PreviewRow old) {
    super.didUpdateWidget(old);
    if (old.horizon != widget.horizon) _compute();
  }

  Future<void> _compute() async {
    final store = AppStore();
    final s = await store.getSettings();
    final payments = await store.getRecurringPayments();
    if (!mounted) return;
    setState(() {
      _result = SafeToSpendEngine.calculateSafeToSpend(
        currentBalance: s.currentBalance,
        recurringPayments: payments,
        daysAhead: widget.horizon,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Safe to Spend (${_horizons[widget.horizon]} ahead)',
            style: const TextStyle(fontSize: 14)),
        Text(
          _result == null ? '…' : '₹${_result!.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryGreen),
        ),
      ],
    );
  }
}
