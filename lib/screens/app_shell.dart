import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'payments/payments_screen.dart';
import 'budgets/budgets_screen.dart';
import 'goals/goals_screen.dart';
import 'more/more_screen.dart';
import 'insights/insights_screen.dart';
import 'assistant/assistant_screen.dart';

/// Main app shell matching the APK navigation:
/// Home / Payments / Budgets / Goals / More — with Insights, Sage,
/// Transactions and Settings reachable from More.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Sub-screens pushed from "More" keep their own back navigation.
  final _screens = const [
    HomeScreen(),
    PaymentsScreen(),
    BudgetsScreen(),
    GoalsScreen(),
    MoreScreen(),
  ];

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.event_repeat_outlined, Icons.event_repeat_rounded, 'Payments'),
    (Icons.savings_outlined, Icons.savings_rounded, 'Budgets'),
    (Icons.flag_outlined, Icons.flag_rounded, 'Goals'),
    (Icons.menu_rounded, Icons.menu_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 72,
        backgroundColor: AppColors.card(isDark),
        indicatorColor: AppColors.primaryGreen.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        destinations: [
          for (final (on, off, label) in _items)
            NavigationDestination(
              icon: Icon(on, color: AppColors.textSecondary(isDark)),
              selectedIcon: Icon(off, color: AppColors.primaryGreen),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// Routes for sub-screens opened from More.
/// (Sage and Insights remain flagship features, so they also get
/// a shortcut chip row in More.)
class MoreRoutes {
  static const insights = '/insights';
  static const sage = '/sage';
  static const transactions = '/transactions';
  static const settings = '/settings';

  static Map<String, WidgetBuilder> build() => {
        insights: (_) => const InsightsScreen(),
        sage: (_) => const AssistantScreen(),
      };
}
