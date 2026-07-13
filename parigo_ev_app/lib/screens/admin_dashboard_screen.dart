import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_dispatch_tab.dart';
import 'admin_map_tab.dart';
import 'admin_active_rides_tab.dart';
import 'admin_fleet_tab.dart';
import 'admin_customers_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_feedback_tab.dart';
import 'admin_reports_tab.dart';
import '../widgets/admin_drawer.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  static _AdminDashboardScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<_AdminDashboardScreenState>();

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const AdminDispatchTab(),
    const AdminMapTab(),
    const AdminActiveRidesTab(),
    const AdminFleetTab(),
    const AdminCustomersTab(),
    const AdminFeedbackTab(),
    const AdminSettingsTab(),
    const AdminReportsTab(),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int get currentIndex => _currentIndex;

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: const AdminDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
    );
  }
}
