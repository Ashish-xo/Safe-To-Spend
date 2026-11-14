import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'insights/insights_screen.dart';
import 'assistant/assistant_screen.dart';

/// Main app shell: Home (original) + AI Insights + AI Assistant.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: const [
          HomeScreen(),
          InsightsScreen(),
          AssistantScreen(),
        ],
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryGreen,
          tabs: const [
            Tab(icon: Icon(Icons.home_outlined), text: 'Home'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Insights'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Assistant'),
          ],
        ),
      ),
    );
  }
}
