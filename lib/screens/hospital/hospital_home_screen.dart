import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'tabs/overview_tab.dart';
import 'tabs/verify_requests_tab.dart';
import 'tabs/donor_search_tab.dart';
import 'tabs/history_tab.dart';
import 'alert_center_screen.dart';
import '../../services/alert_watcher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/appearance_selector_sheet.dart';
import '../../widgets/command_palette.dart';

// Burgundy - the Doctor / Blood Bank module's brand identity color
// (Obsidian + Burgundy + Champagne + Ivory visual system). Kept as a
// module-wide constant (rather than only `context.colors.primary`)
// for the couple of places - e.g. this file's badge/logo accents -
// that render before a BuildContext with the theme extension is
// available.
const kHospitalPrimary = Color(0xFF6E1F3A);

/// Breakpoint used across the Doctor module for the mobile ↔ wide
/// (tablet/desktop) responsive layout switch (#17).
const kWideLayoutBreakpoint = 900.0;

/// Hospital / Doctor dashboard shell.
///
/// Implements the staff-facing side of LifeLink for the Doctor / Blood
/// Bank Medical Officer persona:
///   FR08 - Staff verification dashboard (+ Emergency Command Center)
///   FR09 - Donor availability search (+ match ranking)
///   FR10 - Donor response tracking (+ multi-donor coordination)
///   FR14 - Request history (+ advanced search/filters)
/// plus the alert center, audit trail, PDF reporting, pinning, and
/// responsive layout added in the second iteration of this module.
class HospitalHomeScreen extends StatefulWidget {
  const HospitalHomeScreen({super.key});

  @override
  State<HospitalHomeScreen> createState() => _HospitalHomeScreenState();
}

class _HospitalHomeScreenState extends State<HospitalHomeScreen> {
  int _tabIndex = 0;
  final AlertWatcher _alertWatcher = AlertWatcher();

  static const _titles = ['Dashboard', 'Verify Requests', 'Donor Search', 'History'];
  static const _tabIcons = [
    Icons.dashboard_rounded,
    Icons.fact_check_outlined,
    Icons.search_rounded,
    Icons.history_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _alertWatcher.start();
  }

  @override
  void dispose() {
    _alertWatcher.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final tabs = [
      OverviewTab(doctorName: user?.email ?? 'Doctor'),
      const VerifyRequestsTab(),
      const DonorSearchTab(),
      const HistoryTab(),
    ];

    final colors = context.colors;
    // #command-palette - Ctrl+K (Cmd+K on macOS) opens the global
    // "jump to anything" search from anywhere in the Doctor module.
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): () => showCommandPalette(context, onNavigateTab: (i) => setState(() => _tabIndex = i)),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK): () => showCommandPalette(context, onNavigateTab: (i) => setState(() => _tabIndex = i)),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: kHospitalPrimary, shape: BoxShape.circle),
            ),
            Text(_titles[_tabIndex]),
          ],
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Search (Ctrl+K)',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => showCommandPalette(context, onNavigateTab: (i) => setState(() => _tabIndex = i)),
          ),
          const AlertBellIcon(),
          IconButton(
            tooltip: 'Appearance',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => AppearanceSelectorSheet.show(context),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= kWideLayoutBreakpoint;

          if (!isWide) {
            return IndexedStack(index: _tabIndex, children: tabs);
          }

          // Wide (tablet/desktop) layout: navigation rail + larger content area.
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) => setState(() => _tabIndex = i),
                backgroundColor: colors.surface,
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: IconThemeData(color: colors.primary),
                unselectedIconTheme: IconThemeData(color: colors.textSecondary),
                selectedLabelTextStyle: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                unselectedLabelTextStyle: TextStyle(color: colors.textSecondary),
                destinations: List.generate(
                  _titles.length,
                  (i) => NavigationRailDestination(
                    icon: i == 1 ? const _PendingBadgeIcon() : Icon(_tabIcons[i]),
                    selectedIcon: i == 1 ? _PendingBadgeIcon(selected: true, color: colors.primary) : Icon(_tabIcons[i], color: colors.primary),
                    label: Text(_titles[i]),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: IndexedStack(index: _tabIndex, children: tabs),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= kWideLayoutBreakpoint) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            backgroundColor: colors.surface,
            indicatorColor: colors.primary.withValues(alpha: 0.15),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: colors.primary),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: const _PendingBadgeIcon(),
                selectedIcon: _PendingBadgeIcon(selected: true, color: colors.primary),
                label: 'Verify',
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded, color: colors.primary),
                label: 'Donors',
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_rounded, color: colors.primary),
                label: 'History',
              ),
            ],
          );
        },
      ),
        ),
      ),
    );
  }
}

/// Small badge icon showing the live count of requests still awaiting
/// verification, so staff can see workload at a glance.
class _PendingBadgeIcon extends StatelessWidget {
  final bool selected;
  final Color? color;
  const _PendingBadgeIcon({this.selected = false, this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('requests').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final icon = Icon(Icons.fact_check_outlined, color: selected ? color : null);
        if (count == 0) return icon;
        return Badge(label: Text('$count'), backgroundColor: kHospitalPrimary, child: icon);
      },
    );
  }
}
