import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'tabs/overview_tab.dart';
import 'tabs/verify_requests_tab.dart';
import 'tabs/donor_search_tab.dart';
import 'tabs/history_tab.dart';
import 'alert_center_screen.dart';
import 'request_details_screen.dart';
import '../../services/alert_watcher.dart';
import '../../services/presence_service.dart';
import '../../theme/app_colors.dart';
import '../../models/blood_request.dart';
import '../../utils/request_status.dart';
import '../../widgets/appearance_selector_sheet.dart';
import '../../widgets/command_palette.dart';
import '../../widgets/live_pulse_dot.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    PresenceService.instance.start(staffName: user?.email ?? 'Staff');
  }

  @override
  void dispose() {
    _alertWatcher.dispose();
    PresenceService.instance.dispose();
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
          const _StaffPresenceChip(),
          const SizedBox(width: 4),
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
      body: Column(
        children: [
          // #critical - a persistent, app-wide banner (visible from
          // every tab, not just Verify) the instant any active request
          // crosses its urgency-specific critical-attention SLA. This
          // is deliberately not dismissible - a genuinely critical
          // situation should not be silence-able by an accidental tap.
          _CriticalEscalationBanner(onTap: () => setState(() => _tabIndex = 1)),
          Expanded(
            child: LayoutBuilder(
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
          ),
        ],
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

/// #critical - App-wide critical-attention escalation banner. Shows
/// the count of ACTIVE requests whose [RequestHealth] has crossed
/// CRITICAL_ATTENTION (the same real waiting-time/urgency/coverage
/// heuristic used everywhere else in the module - nothing new is
/// invented here, this just surfaces it globally instead of only on
/// the Verify tab). Renders nothing when the count is zero.
///
/// Expandable: tapping the chevron drops down the actual list of
/// critical requests (patient, blood group, waiting time) so staff can
/// jump straight into the one that needs them, instead of only a
/// count + "go look at the tab yourself".
class _CriticalEscalationBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _CriticalEscalationBanner({required this.onTap});

  @override
  State<_CriticalEscalationBanner> createState() => _CriticalEscalationBannerState();
}

class _CriticalEscalationBannerState extends State<_CriticalEscalationBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('requests').where('status', whereIn: RequestStatus.activeStatuses).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final criticalRequests = docs
            .map(BloodRequest.fromDoc)
            .where((r) {
              final level = RequestHealth.computeLevel(
                status: r.status,
                urgency: r.urgency,
                createdAt: r.createdAt,
                unitsNeeded: r.unitsNeeded,
                unitsConfirmed: r.unitsConfirmed,
              );
              return level == RequestHealth.criticalAttention;
            })
            .toList()
          ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
        final criticalCount = criticalRequests.length;

        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: criticalCount == 0
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: colors.critical.withValues(alpha: 0.12),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.critical.withValues(alpha: 0.35)))),
                          child: Row(
                            children: [
                              LivePulseDot(color: colors.critical),
                              const SizedBox(width: 8),
                              Icon(Icons.emergency_outlined, size: 15, color: colors.critical),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  criticalCount == 1
                                      ? '1 request needs immediate attention - waiting time has passed the critical threshold.'
                                      : '$criticalCount requests need immediate attention - waiting time has passed the critical threshold.',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.critical),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(_expanded ? 'Hide' : 'Show', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.critical)),
                              AnimatedRotation(
                                duration: const Duration(milliseconds: 200),
                                turns: _expanded ? 0.5 : 0,
                                child: Icon(Icons.expand_more_rounded, size: 18, color: colors.critical),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: !_expanded
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.critical.withValues(alpha: 0.35)))),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: criticalRequests.length,
                                  itemBuilder: (context, i) {
                                    final r = criticalRequests[i];
                                    return InkWell(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: r.id))),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(color: colors.critical.withValues(alpha: 0.15), shape: BoxShape.circle),
                                              child: Text(r.bloodGroup, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.critical)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(r.patientName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary), overflow: TextOverflow.ellipsis),
                                                  Text('Waiting ${WaitingTime.format(r.createdAt)} · ${r.hospitalName}', style: TextStyle(fontSize: 11, color: colors.textSecondary), overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded, size: 16, color: colors.critical),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                      if (_expanded)
                        InkWell(
                          onTap: widget.onTap,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            alignment: Alignment.center,
                            child: Text('Open full Verify Requests queue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.critical, decoration: TextDecoration.underline)),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// #live-presence - "N staff online" indicator, backed by
/// [PresenceService]'s Firestore heartbeat. Renders nothing while the
/// count is 0 or 1 (just this session) so it never claims a co-worker
/// is online when nobody else actually is.
class _StaffPresenceChip extends StatelessWidget {
  const _StaffPresenceChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<int>(
      stream: PresenceService.instance.onlineCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 1;
        if (count <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Tooltip(
            message: '$count staff currently active in this module',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: colors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LivePulseDot(color: colors.success),
                  const SizedBox(width: 6),
                  Text('$count online', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.success)),
                ],
              ),
            ),
          ),
        );
      },
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
