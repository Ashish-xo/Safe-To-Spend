import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'insights/insights_screen.dart';
import 'assistant/assistant_screen.dart';

/// Main app shell: Home (original) + AI Insights + AI Assistant,
/// with a floating pill navigation bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [HomeScreen(), InsightsScreen(), AssistantScreen()];

  void _onTap(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // Keep all three alive so state (chat history) persists.
          IndexedStack(
            index: _index,
            children: _screens,
          ),
          // Floating pill nav
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: isDark
                    ? Border.all(color: AppColors.darkDivider)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _navItem(context, isDark, 0, Icons.home_outlined, 'Home'),
                  _navItem(context, isDark, 1, Icons.insights_outlined, 'Insights'),
                  _navItem(context, isDark, 2, Icons.auto_awesome, 'Sage'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, bool isDark, int i, IconData icon, String label) {
    final active = _index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryGreen.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? AppColors.primaryGreen : AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
