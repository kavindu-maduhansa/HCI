import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../hospital_home_screen.dart';
import '../../../models/blood_request.dart';
import '../../../utils/request_status.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/request_health_badge.dart';
import '../../../widgets/common_states.dart';
import '../../../widgets/entrance_fade_slide.dart';
import '../../../widgets/animated_count.dart';
import '../../../widgets/live_pulse_dot.dart';
import '../../../widgets/skeleton_loader.dart';
import '../request_details_screen.dart';

/// Overview / analytics tab for the Doctor dashboard - the "Blood Bank
/// Operations Command Center".
///
/// Leads with a compact operational-status header, a row of live stat
/// chips (#1), the Emergency Command Center (most urgent active cases),
/// dashboard-wide analytics (#14, donor response rate), and the donor
/// pool distribution. All real data comes from Firestore; when a
/// section has no real data yet it shows a clearly-labelled DEMO DATA
/// preview instead of a large blank card, so the layout and advanced
/// features stay visible even on a freshly-seeded project. Demo values
/// are never mixed into real figures - real Firestore data is always
/// used the moment it exists.
class OverviewTab extends StatelessWidget {
  final String doctorName;
  const OverviewTab({super.key, required this.doctorName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('requests').snapshots(),
      builder: (context, requestSnap) {
        if (requestSnap.hasError) {
          return const ErrorStateView(message: 'Unable to load the dashboard right now.');
        }
        if (!requestSnap.hasData) {
          return const DashboardSkeleton();
        }

        final allRequests = requestSnap.data!.docs.map(BloodRequest.fromDoc).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Donor').snapshots(),
          builder: (context, donorSnap) {
            final donorDocs = donorSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('alerts').orderBy('createdAt', descending: true).limit(50).snapshots(),
              builder: (context, alertSnap) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                final unreadAlerts = (alertSnap.data?.docs ?? []).where((d) {
                  final readBy = (d.data()['readBy'] as List?)?.cast<String>() ?? const [];
                  return uid == null || !readBy.contains(uid);
                }).length;

                // #18/#19/#20 - Donor Response Tracking analytics.
                // collectionGroup query reads every request's `responses`
                // subcollection in one efficient listener, instead of
                // opening a separate listener per request (no fan-out).
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collectionGroup('responses').snapshots(),
                  builder: (context, responseSnap) {
                    final responseDocs = responseSnap.hasError ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[] : (responseSnap.data?.docs ?? []);

                    // #22 - Live Activity Feed, built from real
                    // `auditLogs` entries (already written by every
                    // action in RequestService) - a single top-level
                    // collection query, not a listener per request.
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('auditLogs').orderBy('timestamp', descending: true).limit(15).snapshots(),
                      builder: (context, auditSnap) {
                        final auditDocs = auditSnap.hasError ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[] : (auditSnap.data?.docs ?? []);

                        // #30 - Pinned Requests. Only ever shown when the
                        // current doctor actually has pins - no demo
                        // fallback, per spec.
                        final pinnedRequests = allRequests.where((r) => r.isPinnedBy(uid)).toList();

                        // Staggered entrance (#dashboard entrance animation): each
                        // section fades/slides in a little after the previous one,
                        // instead of everything appearing at once.
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            EntranceFadeSlide(child: _OperationalHeader(doctorName: doctorName)),
                            const SizedBox(height: 16),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 60),
                              child: _QuickStatsRow(allRequests: allRequests, donorDocs: donorDocs, unreadAlerts: unreadAlerts),
                            ),
                            const SizedBox(height: 16),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 80),
                              child: _WeekComparisonStrip(allRequests: allRequests),
                            ),
                            if (pinnedRequests.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              EntranceFadeSlide(
                                delay: const Duration(milliseconds: 100),
                                child: _PinnedRequestsSection(requests: pinnedRequests),
                              ),
                            ],
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 120),
                              child: _DoctorInsightsSection(allRequests: allRequests, responseDocs: responseDocs),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 140),
                              child: _CommandCenterSection(allRequests: allRequests),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 180),
                              child: _AnalyticsSection(allRequests: allRequests, donorCount: donorDocs.length),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 220),
                              child: _ResponseFunnelSection(responseDocs: responseDocs),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 260),
                              child: _ResponsePerformanceSection(responseDocs: responseDocs),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 280),
                              child: _DonorLeaderboardSection(responseDocs: responseDocs),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 300),
                              child: _LiveActivityFeedSection(auditDocs: auditDocs),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 340),
                              child: _RequestTrendCard(allRequests: allRequests),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 380),
                              child: _BloodDemandCard(allRequests: allRequests),
                            ),
                            const SizedBox(height: 20),
                            EntranceFadeSlide(
                              delay: const Duration(milliseconds: 420),
                              child: _BloodGroupChartCard(donorDocs: donorDocs),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Small "DEMO DATA" chip so any preview/sample content is always
/// unmistakably distinct from real Firebase-backed figures.
class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 11, color: colors.warning),
          const SizedBox(width: 4),
          Text('DEMO DATA', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colors.warning, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// Sophisticated, low-key operational header - replaces the old
/// full-bleed crimson welcome banner. Crimson stays an accent (the
/// small logo mark) rather than the whole surface.
class _OperationalHeader extends StatelessWidget {
  final String doctorName;
  const _OperationalHeader({required this.doctorName});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, Color.alphaBlend(kHospitalPrimary.withValues(alpha: 0.05), colors.surface)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kHospitalPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.local_hospital_rounded, color: kHospitalPrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_greeting, Doctor', style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Blood Bank Operations Overview', style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    LivePulseDot(color: colors.success),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'System Operational · $doctorName',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// #1 - compact operational overview strip: the numbers a doctor needs
/// at a glance, each with a semantic colour (never colour-only - every
/// chip pairs an icon with a label as well).
class _QuickStatsRow extends StatelessWidget {
  final List<BloodRequest> allRequests;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> donorDocs;
  final int unreadAlerts;
  const _QuickStatsRow({required this.allRequests, required this.donorDocs, required this.unreadAlerts});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Stay consistent with the Command Center / Analytics sections
    // below: when there are zero real requests yet, show the SAME
    // demo dataset instead of a misleading row of real zeros.
    final isDemo = allRequests.isEmpty;

    final List<_QuickStat> chips;
    if (isDemo) {
      chips = [
        _QuickStat('Pending', 8, Icons.hourglass_top_rounded, colors.warning),
        _QuickStat('Critical', 3, Icons.priority_high_rounded, colors.critical),
        _QuickStat('Active Responses', 12, Icons.sync_rounded, colors.primary),
        _QuickStat('Verified Donors', 47, Icons.verified_rounded, colors.success),
        _QuickStat('Unread Alerts', 4, Icons.notifications_active_rounded, colors.primary),
      ];
    } else {
      final pending = allRequests.where((r) => r.status == RequestStatus.pending).length;
      final critical = allRequests.where((r) => r.urgency == UrgencyLevel.critical && RequestStatus.activeStatuses.contains(r.status)).length;
      final activeResponses = allRequests.fold<int>(0, (t, r) => t + r.donorsNotifiedCount - r.donorsAcceptedCount).clamp(0, 1 << 30);
      final verifiedDonors = donorDocs.where((d) {
        final data = d.data();
        return data['verified'] == true && data['availableNow'] != false;
      }).length;
      chips = [
        _QuickStat('Pending', pending, Icons.hourglass_top_rounded, colors.warning),
        _QuickStat('Critical', critical, Icons.priority_high_rounded, colors.critical),
        _QuickStat('Active Responses', activeResponses, Icons.sync_rounded, colors.primary),
        _QuickStat('Verified Donors', verifiedDonors, Icons.verified_rounded, colors.success),
        _QuickStat('Unread Alerts', unreadAlerts, Icons.notifications_active_rounded, colors.primary),
      ];
    }

    // #density-fix - a fixed-width horizontal scroll row left a lot of
    // dead space to the right on wide/desktop viewports (the exact
    // "feels empty" complaint). On anything wider than a phone, lay
    // the same 5 stats out as Expanded cards so they fill the row;
    // mobile keeps the horizontal-scroll strip since 5 full-width
    // cards would be too cramped there.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _QuickStatChip(data: chips[i], demo: isDemo)),
                ],
              ],
            ),
          );
        }
        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SizedBox(width: 140, child: _QuickStatChip(data: chips[i], demo: isDemo)),
          ),
        );
      },
    );
  }
}

class _QuickStat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  _QuickStat(this.label, this.value, this.icon, this.color);
}

class _QuickStatChip extends StatelessWidget {
  final _QuickStat data;
  final bool demo;
  const _QuickStatChip({required this.data, this.demo = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: data.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(data.icon, size: 15, color: data.color),
              ),
              if (demo) ...[const Spacer(), Icon(Icons.visibility_outlined, size: 12, color: colors.champagne)],
            ],
          ),
          const SizedBox(height: 10),
          AnimatedCount(value: data.value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 2),
          Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// #1 - Emergency Command Center: the most urgent active cases,
/// ranked by urgency then by longest-waiting, shown with the exact
/// operational detail a triaging doctor needs. Falls back to a clearly
/// labelled demo preview only when there are zero real requests at all.
class _CommandCenterSection extends StatelessWidget {
  final List<BloodRequest> allRequests;
  const _CommandCenterSection({required this.allRequests});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = allRequests.where((r) => RequestStatus.activeStatuses.contains(r.status)).toList()
      ..sort((a, b) {
        final urgencyCompare = UrgencyLevel.weight(a.urgency).compareTo(UrgencyLevel.weight(b.urgency));
        if (urgencyCompare != 0) return urgencyCompare;
        return WaitingTime.elapsed(b.createdAt).compareTo(WaitingTime.elapsed(a.createdAt));
      });
    final topCases = active.take(5).toList();
    final showDemo = allRequests.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emergency_share_rounded, color: colors.critical, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Emergency Command Center',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            ),
            if (showDemo)
              const _DemoBadge()
            else if (active.isNotEmpty)
              Text('${active.length} active', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        if (showDemo)
          Column(
            children: _demoCommandCards.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DemoCommandCard(data: d),
            )).toList(),
          )
        else if (topCases.isEmpty)
          _PolishedEmptyCard(
            icon: Icons.shield_moon_outlined,
            title: 'No critical requests',
            message: 'All current requests are under control.',
          )
        else
          ...topCases.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _CommandCard(request: r))),
      ],
    );
  }
}

class _DemoCommandData {
  final String bloodGroup;
  final String urgency;
  final int units;
  final String waiting;
  const _DemoCommandData(this.bloodGroup, this.urgency, this.units, this.waiting);
}

const _demoCommandCards = [
  _DemoCommandData('O-', 'Emergency', 4, '08 min'),
  _DemoCommandData('A+', 'Urgent', 2, '14 min'),
  _DemoCommandData('B+', 'Critical', 3, '21 min'),
];

/// Visual-only preview card for the Emergency Command Center demo
/// state - intentionally not tappable, since it has no backing
/// Firestore document.
class _DemoCommandCard extends StatelessWidget {
  final _DemoCommandData data;
  const _DemoCommandCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: colors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.critical.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.critical.withValues(alpha: 0.15),
              child: Text(data.bloodGroup, style: TextStyle(color: colors.critical, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${data.urgency} · ${data.units} units required', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${data.waiting} waiting · sample preview', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                ],
              ),
            ),
            const _DemoBadge(),
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  final BloodRequest request;
  const _CommandCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCritical = request.urgency == UrgencyLevel.critical;
    final urgencyColor = UrgencyLevel.color(request.urgency);

    return Container(
      decoration: BoxDecoration(
        color: isCritical ? colors.critical.withValues(alpha: 0.06) : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCritical ? colors.critical : colors.border, width: isCritical ? 1.6 : 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(request.urgency.toUpperCase(),
                    style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              if (isCritical) ...[const SizedBox(width: 8), LivePulseDot(color: colors.critical)],
              const SizedBox(width: 8),
              Flexible(child: Align(alignment: Alignment.centerRight, child: RequestHealthBadge(request: request, showWaitingTime: false))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'bloodgroup-avatar-${request.id}',
                child: CircleAvatar(
                radius: 22,
                backgroundColor: colors.critical.withValues(alpha: 0.1),
                child: Text(request.bloodGroup, style: TextStyle(color: colors.critical, fontWeight: FontWeight.bold)),
              ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${request.unitsNeeded} units required · ${request.hospitalName}',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${request.unitsConfirmed}/${request.unitsNeeded} confirmed · ${request.unitsRemaining} unit(s) remaining',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: colors.textSecondary),
                        const SizedBox(width: 3),
                        Text('${WaitingTime.format(request.createdAt)} waiting', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined, size: 13, color: colors.textSecondary),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            request.location.isNotEmpty ? request.location : 'Location not provided',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // #6 - Donor Coverage: how much of this request's blood-unit
          // need is already covered by confirmed donors, shown as a
          // real animated progress bar (not decorative) plus the
          // notified/accepted counts already on the request document.
          _DonorCoverageBar(
            confirmed: request.unitsConfirmed,
            needed: request.unitsNeeded,
            notified: request.donorsNotifiedCount,
            accepted: request.donorsAcceptedCount,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(RequestStatus.label(request.status), style: TextStyle(fontSize: 11.5, color: RequestStatus.color(request.status), fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: request.id))),
                child: Text('Review Request', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// #6 - Donor Coverage bar. "Coverage" = confirmed units / units still
/// needed, from the request's own `unitsConfirmed`/`unitsNeeded`
/// fields (never invented). Animates in from 0 on first build so it
/// reads as live progress rather than a static decoration.
class _DonorCoverageBar extends StatelessWidget {
  final int confirmed;
  final int needed;
  final int notified;
  final int accepted;
  const _DonorCoverageBar({required this.confirmed, required this.needed, required this.notified, required this.accepted});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ratio = needed <= 0 ? 0.0 : (confirmed / needed).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    final barColor = ratio >= 1.0 ? colors.success : (ratio >= 0.5 ? colors.champagne : colors.critical);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('DONOR COVERAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: colors.textSecondary)),
            const Spacer(),
            Text('$pct%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: barColor)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: colors.elevatedSurface),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: ratio),
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(color: barColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          notified == 0
              ? 'No donors notified yet'
              : '$notified donor(s) notified · $accepted responding · $confirmed/$needed unit(s) confirmed',
          style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// #14 - Better analytics, all derived from real data. Falls back to a
/// clearly-labelled demo preview (never mixed with real figures) only
/// when there is no real Firestore data at all yet.
class _AnalyticsSection extends StatelessWidget {
  final List<BloodRequest> allRequests;
  final int donorCount;
  const _AnalyticsSection({required this.allRequests, required this.donorCount});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (allRequests.isEmpty) {
      const demoStats = [
        _StatData('Pending Verification', '8', Icons.hourglass_top_rounded, null, subtitle: '+2 today'),
        _StatData('Critical Requests', '3', Icons.priority_high_rounded, null, subtitle: '2 need attention'),
        _StatData('Active Donor Responses', '12', Icons.sync_rounded, null, subtitle: '72% response rate'),
        _StatData('Verified Donors', '47', Icons.verified_rounded, null, subtitle: 'Currently available'),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Dashboard Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              const SizedBox(width: 8),
              const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text('Real analytics will replace this preview once requests start coming in from the Recipient app.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: demoStats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 128,
            ),
            itemBuilder: (context, i) => _StatCard(data: demoStats[i], demo: true),
          ),
        ],
      );
    }

    final pending = allRequests.where((r) => r.status == RequestStatus.pending).length;
    final active = allRequests.where((r) => RequestStatus.activeStatuses.contains(r.status)).length;
    final critical = allRequests.where((r) => r.urgency == UrgencyLevel.critical && RequestStatus.activeStatuses.contains(r.status)).length;
    final completed = allRequests.where((r) => r.status == RequestStatus.fulfilled).length;

    final totalNotified = allRequests.fold<int>(0, (total, r) => total + r.donorsNotifiedCount);
    final totalAccepted = allRequests.fold<int>(0, (total, r) => total + r.donorsAcceptedCount);
    final responseRate = totalNotified == 0 ? null : (totalAccepted / totalNotified * 100).round();

    final unitsConfirmed = allRequests.fold<int>(0, (total, r) => total + r.unitsConfirmed);
    final unitsRemaining = allRequests
        .where((r) => RequestStatus.activeStatuses.contains(r.status))
        .fold<int>(0, (total, r) => total + r.unitsRemaining);

    final stats = [
      _StatData('Pending Verification', '$pending', Icons.hourglass_top_rounded, colors.warning, subtitle: 'Awaiting review'),
      _StatData('Active Requests', '$active', Icons.sync_rounded, colors.primary, subtitle: 'In progress'),
      _StatData('Critical Now', '$critical', Icons.priority_high_rounded, colors.critical, subtitle: critical > 0 ? 'Needs attention' : 'Under control'),
      _StatData('Completed', '$completed', Icons.check_circle_rounded, colors.success, subtitle: 'Fulfilled requests'),
      _StatData('Registered Donors', '$donorCount', Icons.groups_rounded, colors.primary, subtitle: 'In donor pool'),
      _StatData('Overall Response Rate', responseRate == null ? 'n/a' : '$responseRate%', Icons.insights_rounded, colors.primary, subtitle: 'Notified → accepted'),
      _StatData('Units Confirmed', '$unitsConfirmed', Icons.check_box_rounded, colors.success, subtitle: 'Across active requests'),
      _StatData('Units Remaining (active)', '$unitsRemaining', Icons.pending_actions_rounded, colors.warning, subtitle: 'Still needed'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dashboard Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 128,
          ),
          itemBuilder: (context, i) => _StatCard(data: stats[i]),
        ),
      ],
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  const _StatData(this.label, this.value, this.icon, this.color, {this.subtitle});
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  final bool demo;
  const _StatCard({required this.data, this.demo = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = data.color ?? colors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(data.icon, color: accent, size: 20),
              if (demo) ...[const Spacer(), Icon(Icons.visibility_outlined, size: 13, color: colors.warning)],
            ],
          ),
          const SizedBox(height: 8),
          Text(data.value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
          const SizedBox(height: 2),
          Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          if (data.subtitle != null) ...[
            const SizedBox(height: 3),
            Text(data.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: colors.textSecondary.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }
}

/// #19 - Donor Response Funnel. Built only from response statuses
/// that are actually tracked in Firestore (notified / accepted /
/// declined / completed) - no invented "viewed" or "confirmed" stage,
/// since nothing in the donor app populates those fields yet. Falls
/// back to one consistent demo funnel when there are zero real
/// responses anywhere.
class _ResponseFunnelSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> responseDocs;
  const _ResponseFunnelSection({required this.responseDocs});

  static const _demoStages = [
    _FunnelStage('Notified', 120),
    _FunnelStage('Responded', 78),
    _FunnelStage('Accepted', 54),
    _FunnelStage('Completed', 41),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDemo = responseDocs.isEmpty;

    List<_FunnelStage> stages;
    int declined = 0;
    if (isDemo) {
      stages = _demoStages;
      declined = 24;
    } else {
      final notified = responseDocs.length;
      var responded = 0, accepted = 0, completed = 0;
      for (final doc in responseDocs) {
        final status = doc.data()['status'] as String? ?? 'notified';
        if (status != 'notified') responded++;
        if (status == 'accepted' || status == 'completed') accepted++;
        if (status == 'completed') completed++;
        if (status == 'declined') declined++;
      }
      stages = [
        _FunnelStage('Notified', notified),
        _FunnelStage('Responded', responded),
        _FunnelStage('Accepted', accepted),
        _FunnelStage('Completed', completed),
      ];
    }

    final maxValue = stages.first.value == 0 ? 1 : stages.first.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Donor Response Funnel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text('Notified → Responded → Accepted → Completed, across all requests', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 18),
          ...List.generate(stages.length, (i) {
            final stage = stages[i];
            final fraction = maxValue == 0 ? 0.0 : stage.value / maxValue;
            final conversion = i == 0 || stages[i - 1].value == 0 ? null : (stage.value / stages[i - 1].value * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(stage.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary))),
                      if (conversion != null) ...[
                        Text('$conversion% conversion', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                        const SizedBox(width: 8),
                      ],
                      Text('${stage.value}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                      duration: Duration(milliseconds: 500 + i * 120),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 16,
                        backgroundColor: colors.elevatedSurface,
                        valueColor: AlwaysStoppedAnimation(colors.primary.withValues(alpha: 1 - (i * 0.15))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (declined > 0) ...[
            const Divider(height: 8),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.cancel_outlined, size: 15, color: colors.critical),
                const SizedBox(width: 6),
                Text('$declined declined (not shown in funnel above)', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FunnelStage {
  final String label;
  final int value;
  const _FunnelStage(this.label, this.value);
}

/// #20 - Donor Response Performance: deterministic stats computed
/// from real `notifiedAt`/`respondedAt` timestamps already stored on
/// each response document.
class _ResponsePerformanceSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> responseDocs;
  const _ResponsePerformanceSection({required this.responseDocs});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDemo = responseDocs.isEmpty;

    String responseRate, acceptanceRate, avgResponse, completionRate;
    if (isDemo) {
      responseRate = '72%';
      acceptanceRate = '64%';
      avgResponse = '11m';
      completionRate = '81%';
    } else {
      final notified = responseDocs.length;
      var responded = 0, accepted = 0, completed = 0;
      final responseTimes = <Duration>[];
      for (final doc in responseDocs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'notified';
        if (status != 'notified') responded++;
        if (status == 'accepted' || status == 'completed') accepted++;
        if (status == 'completed') completed++;

        final notifiedAt = (data['notifiedAt'] as Timestamp?)?.toDate();
        final respondedAt = (data['respondedAt'] as Timestamp?)?.toDate();
        if (notifiedAt != null && respondedAt != null && respondedAt.isAfter(notifiedAt)) {
          responseTimes.add(respondedAt.difference(notifiedAt));
        }
      }
      responseRate = notified == 0 ? 'n/a' : '${(responded / notified * 100).round()}%';
      acceptanceRate = responded == 0 ? 'n/a' : '${(accepted / responded * 100).round()}%';
      completionRate = accepted == 0 ? 'n/a' : '${(completed / accepted * 100).round()}%';
      if (responseTimes.isEmpty) {
        avgResponse = 'n/a';
      } else {
        final avgMinutes = responseTimes.fold<int>(0, (t, d) => t + d.inMinutes) ~/ responseTimes.length;
        avgResponse = avgMinutes < 60 ? '${avgMinutes}m' : '${(avgMinutes / 60).toStringAsFixed(1)}h';
      }
    }

    final stats = [
      _PerfStat('Response Rate', responseRate, Icons.mark_email_read_outlined),
      _PerfStat('Acceptance Rate', acceptanceRate, Icons.thumb_up_outlined),
      _PerfStat('Avg. Response Time', avgResponse, Icons.timer_outlined),
      _PerfStat('Completion Rate', completionRate, Icons.task_alt_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Donor Response Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: stats
                .map((s) => Expanded(
                      child: Column(
                        children: [
                          Icon(s.icon, size: 18, color: colors.primary),
                          const SizedBox(height: 6),
                          Text(s.value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(s.label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PerfStat {
  final String label;
  final String value;
  final IconData icon;
  const _PerfStat(this.label, this.value, this.icon);
}

/// #24 - Doctor Insights ("Today's Operations"). Deterministic,
/// Firebase-calculated observations only - never claims AI, and
/// labelled OPERATIONAL INSIGHTS wherever shown.
class _DoctorInsightsSection extends StatelessWidget {
  final List<BloodRequest> allRequests;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> responseDocs;
  const _DoctorInsightsSection({required this.allRequests, required this.responseDocs});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDemo = allRequests.isEmpty;

    List<String> insights;
    if (isDemo) {
      insights = const [
        '8 requests are awaiting verification.',
        'O− currently has the highest demand.',
        '72% donor response rate over recent activity.',
        '2 requests need attention (long-waiting or under-covered).',
        'Average donor response time: 11 minutes.',
      ];
    } else {
      final pending = allRequests.where((r) => r.status == RequestStatus.pending).length;
      final active = allRequests.where((r) => RequestStatus.activeStatuses.contains(r.status)).toList();

      final demandByGroup = <String, int>{};
      for (final r in active) {
        demandByGroup[r.bloodGroup] = (demandByGroup[r.bloodGroup] ?? 0) + r.unitsRemaining;
      }
      String? topDemandGroup;
      var topDemand = 0;
      demandByGroup.forEach((group, units) {
        if (units > topDemand) {
          topDemand = units;
          topDemandGroup = group;
        }
      });

      final notified = responseDocs.length;
      final responded = responseDocs.where((d) => (d.data()['status'] as String? ?? 'notified') != 'notified').length;
      final responseRateText = notified == 0 ? null : '${(responded / notified * 100).round()}%';

      final needsAttention = active.where((r) {
        final longWaiting = WaitingTime.elapsed(r.createdAt).inMinutes >= 30;
        final underCovered = r.unitsRemaining > 0 && r.donorsNotifiedCount == 0;
        return longWaiting || underCovered || r.status == RequestStatus.rejected;
      }).length;

      final responseTimes = <Duration>[];
      for (final doc in responseDocs) {
        final data = doc.data();
        final notifiedAt = (data['notifiedAt'] as Timestamp?)?.toDate();
        final respondedAt = (data['respondedAt'] as Timestamp?)?.toDate();
        if (notifiedAt != null && respondedAt != null && respondedAt.isAfter(notifiedAt)) {
          responseTimes.add(respondedAt.difference(notifiedAt));
        }
      }
      String? avgResponseText;
      if (responseTimes.isNotEmpty) {
        final avgMinutes = responseTimes.fold<int>(0, (t, d) => t + d.inMinutes) ~/ responseTimes.length;
        avgResponseText = avgMinutes < 60 ? '$avgMinutes minutes' : '${(avgMinutes / 60).toStringAsFixed(1)} hours';
      }

      insights = [
        '$pending request(s) awaiting verification.',
        if (topDemandGroup != null) '$topDemandGroup currently has the highest demand ($topDemand unit(s) needed).',
        if (responseRateText != null) '$responseRateText donor response rate over recent activity.',
        '$needsAttention request(s) need attention (long-waiting or under-covered).',
        if (avgResponseText != null) 'Average donor response time: $avgResponseText.',
      ];
      if (insights.isEmpty || (insights.length == 1 && pending == 0 && needsAttention == 0)) {
        insights = ['No urgent operational signals right now — all active requests are progressing normally.'];
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Operational Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 2),
          Text('Today\'s Operations · deterministic, Firestore-calculated', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          const SizedBox(height: 12),
          ...insights.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 5, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: TextStyle(fontSize: 12.5, color: colors.textPrimary))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// #30 - Pinned Requests. Only rendered by the caller when the current
/// doctor has at least one pin - pin state is real (`pinnedBy` array on
/// the request doc, persisted via [RequestService.togglePin]).
class _PinnedRequestsSection extends StatelessWidget {
  final List<BloodRequest> requests;
  const _PinnedRequestsSection({required this.requests});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.push_pin_rounded, size: 17, color: colors.warning),
            const SizedBox(width: 8),
            Text('Pinned Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          ],
        ),
        const SizedBox(height: 10),
        ...requests.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: r.id))),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.critical.withValues(alpha: 0.1),
                        child: Text(r.bloodGroup, style: TextStyle(color: colors.critical, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.patientName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            Text('${RequestStatus.label(r.status)} · ${r.hospitalName}', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.push_pin_rounded, size: 14, color: colors.warning),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

/// #22 - Live Activity Feed, sourced entirely from real `auditLogs`
/// entries already written by every doctor action (verify, reject,
/// notify donor, response updates, pin, report generation - see
/// RequestService.logAudit). Falls back to one clearly-labelled demo
/// feed only when there is no audit history at all yet.
class _LiveActivityFeedSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> auditDocs;
  const _LiveActivityFeedSection({required this.auditDocs});

  static const _demoFeed = [
    _ActivityItem('Donor responded', 2),
    _ActivityItem('Request verified', 5),
    _ActivityItem('Critical request received', 8),
    _ActivityItem('Donor notification sent', 12),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDemo = auditDocs.isEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LivePulseDot(color: colors.success),
              const SizedBox(width: 8),
              Expanded(child: Text('Live Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 12),
          if (isDemo)
            ..._demoFeed.map((item) => _ActivityRow(icon: _iconFor(item.label), label: item.label, timeLabel: '${item.minutesAgo} min ago'))
          else
            ...auditDocs.map((doc) {
              final data = doc.data();
              final action = data['action'] as String? ?? '';
              final actor = data['performedByName'] as String? ?? '';
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              return _ActivityRow(
                icon: _iconFor(action),
                label: '${_actionLabel(action)}${actor.isNotEmpty ? ' — $actor' : ''}',
                timeLabel: ts == null ? 'just now' : _relativeTime(ts),
              );
            }),
        ],
      ),
    );
  }

  static String _actionLabel(String action) {
    final label = action.replaceAll('_', ' ');
    if (label.isEmpty) return 'Activity';
    return label[0].toUpperCase() + label.substring(1);
  }

  static IconData _iconFor(String action) {
    final a = action.toLowerCase();
    if (a.contains('verif')) return Icons.verified_rounded;
    if (a.contains('reject')) return Icons.cancel_outlined;
    if (a.contains('notif')) return Icons.campaign_outlined;
    if (a.contains('respon') || a.contains('accept') || a.contains('declin')) return Icons.sync_rounded;
    if (a.contains('pin')) return Icons.push_pin_rounded;
    if (a.contains('report')) return Icons.picture_as_pdf_outlined;
    if (a.contains('critical') || a.contains('received')) return Icons.priority_high_rounded;
    return Icons.circle_notifications_outlined;
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActivityItem {
  final String label;
  final int minutesAgo;
  const _ActivityItem(this.label, this.minutesAgo);
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String timeLabel;
  const _ActivityRow({required this.icon, required this.label, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: colors.textPrimary))),
          Text(timeLabel, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// Reusable compact empty state used throughout the dashboard - never
/// a large blank white/dark card.
class _PolishedEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _PolishedEmptyCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.success, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// #25 - Request Trend: requests created per day over the last 7
/// days, computed from real `createdAt` timestamps already on every
/// request. A lightweight bar chart - no charting package dependency
/// needed for this shape of data.
class _RequestTrendCard extends StatelessWidget {
  final List<BloodRequest> allRequests;
  const _RequestTrendCard({required this.allRequests});

  static const _demoCounts = [3, 5, 2, 6, 4, 7, 5];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDemo = allRequests.isEmpty;

    final today = DateTime.now();
    final days = List.generate(7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
    List<int> counts;
    if (isDemo) {
      counts = _demoCounts;
    } else {
      counts = days.map((day) {
        return allRequests.where((r) {
          final created = r.createdAt;
          if (created == null) return false;
          return created.year == day.year && created.month == day.month && created.day == day.day;
        }).length;
      }).toList();
    }
    final maxCount = counts.fold<int>(1, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Request Trend · Last 7 Days', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text('New requests created per day', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 18),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction = maxCount == 0 ? 0.0 : counts[i] / maxCount;
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${counts[i]}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.textSecondary)),
                        const SizedBox(height: 4),
                        // #safety - a plain Column gives non-Expanded children
                        // UNBOUNDED height, so FractionallySizedBox previously
                        // computed heightFactor(0) * Infinity = NaN on the
                        // very first animation frame and crashed layout for
                        // the whole page (this is what broke scrolling/mouse
                        // input across the dashboard). Bounding this bar's
                        // height explicitly with SizedBox before animating it
                        // guarantees the incoming constraint is always finite.
                        SizedBox(
                          height: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: fraction.clamp(0.04, 1.0)),
                              duration: Duration(milliseconds: 500 + i * 80),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => FractionallySizedBox(
                                heightFactor: value.clamp(0.0, 1.0),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isToday ? colors.primary : colors.primary.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_weekdayLabel(days[i]), style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayLabel(DateTime d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[d.weekday - 1];
  }
}

/// #26 - Blood Demand: units still needed per blood group across
/// active requests, with critical-urgency demand visually emphasised.
class _BloodDemandCard extends StatelessWidget {
  final List<BloodRequest> allRequests;
  const _BloodDemandCard({required this.allRequests});

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  static const _demoDemand = {'O-': 14, 'A+': 9, 'B+': 6, 'AB+': 3, 'O+': 5, 'A-': 2, 'B-': 1, 'AB-': 0};
  static const _demoCritical = {'O-', 'B+'};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = allRequests.where((r) => RequestStatus.activeStatuses.contains(r.status)).toList();
    final isDemo = active.isEmpty;

    Map<String, int> demand;
    Set<String> criticalGroups;
    if (isDemo) {
      demand = _demoDemand;
      criticalGroups = _demoCritical;
    } else {
      demand = {for (final g in _groups) g: 0};
      criticalGroups = {};
      for (final r in active) {
        demand[r.bloodGroup] = (demand[r.bloodGroup] ?? 0) + r.unitsRemaining;
        if (r.urgency == UrgencyLevel.critical && r.unitsRemaining > 0) criticalGroups.add(r.bloodGroup);
      }
    }
    final sortedGroups = _groups.toList()..sort((a, b) => (demand[b] ?? 0).compareTo(demand[a] ?? 0));
    final maxDemand = demand.values.fold<int>(1, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Blood Demand', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text('Units still needed by blood group · critical demand highlighted', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 14),
          ...sortedGroups.map((g) {
            final value = demand[g] ?? 0;
            final isCritical = criticalGroups.contains(g);
            final fraction = maxDemand == 0 ? 0.0 : value / maxDemand;
            final barColor = isCritical ? colors.critical : colors.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(g, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: isCritical ? colors.critical : colors.textPrimary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: fraction.clamp(0.015, 1.0),
                        minHeight: 13,
                        backgroundColor: colors.elevatedSurface,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 24, child: Text('$value', style: TextStyle(fontSize: 11.5, color: colors.textSecondary))),
                  if (isCritical) ...[const SizedBox(width: 4), Icon(Icons.priority_high_rounded, size: 12, color: colors.critical)],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// #33 - Donor pool composition as an animated donut chart (replaces
/// the earlier plain bar list - a genuine second chart TYPE on the
/// dashboard, not another progress-bar stack) with a percentage
/// legend. Each blood group gets a stable, distinct color from
/// `context.colors.chartPalette` so groups are told apart by hue, not
/// just by label.
class _BloodGroupChartCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> donorDocs;
  const _BloodGroupChartCard({required this.donorDocs});

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  static const _demoCounts = {'O+': 42, 'O-': 11, 'A+': 30, 'A-': 8, 'B+': 22, 'B-': 6, 'AB+': 9, 'AB-': 3};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDemo = donorDocs.isEmpty;
    final counts = isDemo ? _demoCounts : _realCounts();
    final total = counts.values.fold<int>(0, (t, v) => t + v);
    final palette = colors.chartPalette;

    final slices = <_DonutSlice>[
      for (var i = 0; i < _groups.length; i++)
        if (counts[_groups[i]]! > 0) _DonutSlice(label: _groups[i], value: counts[_groups[i]]!, color: palette[i % palette.length]),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Donor Pool by Blood Group', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              ),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text('Registered donors, grouped by blood type', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 340;
              final donut = Center(
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => CustomPaint(
                      size: const Size(132, 132),
                      painter: _DonutChartPainter(slices: slices, progress: progress, trackColor: colors.elevatedSurface),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$total', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            Text('donors', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final legend = Wrap(
                spacing: 14,
                runSpacing: 8,
                alignment: stacked ? WrapAlignment.center : WrapAlignment.start,
                children: slices.map((s) {
                  final pct = total == 0 ? 0 : ((s.value / total) * 100).round();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${s.label}  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                      Text('${s.value} · $pct%', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                    ],
                  );
                }).toList(),
              );

              if (stacked) {
                return Column(children: [donut, const SizedBox(height: 16), legend]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  donut,
                  const SizedBox(width: 20),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, int> _realCounts() {
    final counts = {for (final g in _groups) g: 0};
    for (final doc in donorDocs) {
      final group = doc.data()['bloodGroup'] as String?;
      if (group != null && counts.containsKey(group)) counts[group] = counts[group]! + 1;
    }
    return counts;
  }
}

class _DonutSlice {
  final String label;
  final int value;
  final Color color;
  const _DonutSlice({required this.label, required this.value, required this.color});
}

/// Paints a donut/ring chart directly on the canvas - a genuinely
/// different chart TYPE from the bar/progress visuals used everywhere
/// else on this dashboard. `progress` (0..1) sweeps every slice in
/// together from 12 o'clock, driven by the caller's TweenAnimationBuilder.
class _DonutChartPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final double progress;
  final Color trackColor;
  const _DonutChartPainter({required this.slices, required this.progress, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 6.2832, false, track);

    final total = slices.fold<int>(0, (t, s) => t + s.value);
    if (total == 0) return;

    var startAngle = -1.5708; // -90deg, start at 12 o'clock
    const gap = 0.035; // small visual separation between slices
    for (final slice in slices) {
      final sweep = (slice.value / total) * 6.2832 * progress;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      final drawSweep = (sweep - gap).clamp(0.0, sweep);
      if (drawSweep > 0) canvas.drawArc(rect, startAngle, drawSweep, false, paint);
      startAngle += (slice.value / total) * 6.2832;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.slices != slices || oldDelegate.trackColor != trackColor;
}

/// #new - Week-over-week trend: requests created in the last 7 days
/// vs the 7 days before that, purely arithmetic on `createdAt` - no
/// invented data, degrades to a neutral "not enough history yet" line
/// when there isn't a full prior week to compare against.
class _WeekComparisonStrip extends StatelessWidget {
  final List<BloodRequest> allRequests;
  const _WeekComparisonStrip({required this.allRequests});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    final thisWeekStart = now.subtract(const Duration(days: 7));
    final lastWeekStart = now.subtract(const Duration(days: 14));

    final thisWeek = allRequests.where((r) => r.createdAt != null && r.createdAt!.isAfter(thisWeekStart)).length;
    final lastWeek = allRequests.where((r) => r.createdAt != null && r.createdAt!.isAfter(lastWeekStart) && r.createdAt!.isBefore(thisWeekStart)).length;

    final hasHistory = allRequests.any((r) => r.createdAt != null && r.createdAt!.isBefore(lastWeekStart));

    String changeLabel;
    Color changeColor;
    IconData changeIcon;
    if (!hasHistory || lastWeek == 0) {
      changeLabel = thisWeek == 0 ? 'Not enough history yet to compare' : 'First week of activity — no prior week to compare';
      changeColor = colors.textSecondary;
      changeIcon = Icons.timeline_rounded;
    } else {
      final deltaPct = (((thisWeek - lastWeek) / lastWeek) * 100).round();
      if (deltaPct > 0) {
        changeLabel = '+$deltaPct% vs last week ($lastWeek → $thisWeek requests)';
        changeColor = colors.critical;
        changeIcon = Icons.trending_up_rounded;
      } else if (deltaPct < 0) {
        changeLabel = '$deltaPct% vs last week ($lastWeek → $thisWeek requests)';
        changeColor = colors.success;
        changeIcon = Icons.trending_down_rounded;
      } else {
        changeLabel = 'Same as last week ($thisWeek requests)';
        changeColor = colors.textSecondary;
        changeIcon = Icons.trending_flat_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(changeIcon, size: 18, color: changeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(changeLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// #new - Top-donor leaderboard, built purely from real `responses`
/// subcollection data (status == 'completed') across all requests via
/// the same collectionGroup stream already used for the Response
/// Funnel/Performance sections - no extra listener, no invented
/// scores. Ranks donors by completed donations; ties broken by total
/// units pledged. Shows a labelled demo preview only when there are
/// zero real completed responses yet.
class _DonorLeaderboardSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> responseDocs;
  const _DonorLeaderboardSection({required this.responseDocs});

  static const _demoEntries = [
    ('Kasun Perera', 5, 6),
    ('Nimali Silva', 4, 4),
    ('Ruwan Fernando', 3, 3),
    ('Ishara Jayasuriya', 2, 2),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final completed = responseDocs.where((d) => d.data()['status'] == 'completed').toList();
    final isDemo = completed.isEmpty;

    // (name, completedCount, totalUnits)
    List<(String, int, int)> entries;
    if (isDemo) {
      entries = _demoEntries;
    } else {
      final byDonor = <String, (String, int, int)>{};
      for (final doc in completed) {
        final data = doc.data();
        final id = data['donorId'] as String? ?? doc.id;
        final name = data['donorName'] as String? ?? 'Donor';
        final units = (data['unitsPledged'] as num?)?.toInt() ?? 1;
        final existing = byDonor[id];
        byDonor[id] = existing == null ? (name, 1, units) : (existing.$1, existing.$2 + 1, existing.$3 + units);
      }
      entries = byDonor.values.toList()
        ..sort((a, b) {
          final byCount = b.$2.compareTo(a.$2);
          if (byCount != 0) return byCount;
          return b.$3.compareTo(a.$3);
        });
      if (entries.length > 10) entries = entries.sublist(0, 10);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 18, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(child: Text('Top Donors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary))),
              if (isDemo) const _DemoBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text('Ranked by completed donations, all time', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No completed donations recorded yet.', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
            )
          else
            ...entries.asMap().entries.map((e) {
              final rank = e.key + 1;
              final (name, count, units) = e.value;
              final medal = rank == 1
                  ? '🥇'
                  : rank == 2
                      ? '🥈'
                      : rank == 3
                          ? '🥉'
                          : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: medal != null
                          ? Text(medal, style: const TextStyle(fontSize: 16))
                          : Text('$rank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textSecondary)),
                    ),
                    Expanded(
                      child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary), overflow: TextOverflow.ellipsis),
                    ),
                    Text('$count donation${count == 1 ? '' : 's'} · $units unit${units == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
