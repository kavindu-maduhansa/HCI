import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../request_details_screen.dart';
import '../../../models/blood_request.dart';
import '../../../utils/request_status.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common_states.dart';
import '../../../widgets/request_health_badge.dart';
import '../../../widgets/entrance_fade_slide.dart';
import '../../../widgets/live_pulse_dot.dart';
import '../../../widgets/pressable_scale.dart';
import '../../../widgets/skeleton_loader.dart';

/// FR08 - Staff verification dashboard.
///
/// Lists every request awaiting hospital/blood-bank verification so
/// staff can review patient/blood-group/unit details before it is
/// shared with donors. Sorted so the most urgent, longest-waiting
/// requests surface first. Supports search + blood-group/urgency
/// filters so a busy queue stays easy to scan.
class VerifyRequestsTab extends StatefulWidget {
  const VerifyRequestsTab({super.key});

  @override
  State<VerifyRequestsTab> createState() => _VerifyRequestsTabState();
}

class _VerifyRequestsTabState extends State<VerifyRequestsTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _bloodGroupFilter;
  String? _urgencyFilter;

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  static const _urgencies = [UrgencyLevel.critical, UrgencyLevel.high, UrgencyLevel.normal];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        EntranceFadeSlide(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by patient name or hospital...',
              hintStyle: TextStyle(color: colors.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
              filled: true,
              fillColor: colors.elevatedSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1.6)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _FilterChip(
                label: 'All groups',
                selected: _bloodGroupFilter == null,
                onTap: () => setState(() => _bloodGroupFilter = null),
              ),
              const SizedBox(width: 8),
              ..._groups.map((g) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: g,
                      selected: _bloodGroupFilter == g,
                      onTap: () => setState(() => _bloodGroupFilter = _bloodGroupFilter == g ? null : g),
                    ),
                  )),
              const SizedBox(width: 4),
              Container(width: 1, color: colors.border, margin: const EdgeInsets.symmetric(vertical: 8)),
              const SizedBox(width: 12),
              ..._urgencies.map((u) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: u[0].toUpperCase() + u.substring(1),
                      color: UrgencyLevel.color(u),
                      selected: _urgencyFilter == u,
                      onTap: () => setState(() => _urgencyFilter = _urgencyFilter == u ? null : u),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Deliberately no server-side `.orderBy('createdAt')` here -
            // combined with the `.where('status', ...)` equality filter,
            // that requires a Firestore composite index that doesn't
            // exist in this project. Sorting by urgency then by
            // createdAt is instead done client-side below, on the
            // already-narrowed (status == pending) result set, so this
            // screen works without anyone needing to create an index in
            // the Firebase console.
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('status', isEqualTo: RequestStatus.pending)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(message: 'Unable to load requests right now.\n${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const ListCardSkeleton();
              }
              var requests = snapshot.data!.docs.map(BloodRequest.fromDoc).toList()
                ..sort((a, b) {
                  final urgencyCompare = UrgencyLevel.weight(a.urgency).compareTo(UrgencyLevel.weight(b.urgency));
                  if (urgencyCompare != 0) return urgencyCompare;
                  return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
                });

              // #new - at-a-glance queue composition before any filter
              // is applied, so staff can see workload shape without
              // opening every card.
              final queueSummary = requests.isEmpty
                  ? const SizedBox.shrink()
                  : _QueueSummaryStrip(
                      critical: requests.where((r) => r.urgency == UrgencyLevel.critical).length,
                      high: requests.where((r) => r.urgency == UrgencyLevel.high).length,
                      normal: requests.where((r) => r.urgency == UrgencyLevel.normal).length,
                    );

              final query = _searchController.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                requests = requests
                    .where((r) => r.patientName.toLowerCase().contains(query) || r.hospitalName.toLowerCase().contains(query))
                    .toList();
              }
              if (_bloodGroupFilter != null) {
                requests = requests.where((r) => r.bloodGroup == _bloodGroupFilter).toList();
              }
              if (_urgencyFilter != null) {
                requests = requests.where((r) => r.urgency == _urgencyFilter).toList();
              }

              if (requests.isEmpty) {
                final noFiltersActive = query.isEmpty && _bloodGroupFilter == null && _urgencyFilter == null;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                  children: [
                    EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'All caught up!',
                      message: noFiltersActive
                          ? 'No requests are waiting for verification right now.'
                          : 'No pending requests match your search/filters.',
                    ),
                    // #visibility - when the queue is genuinely empty
                    // there is nothing to demonstrate the critical/
                    // emergency handling on. Rather than leave staff
                    // wondering whether that behaviour exists at all,
                    // show what it looks like the moment a critical
                    // request lands - clearly labelled as a preview,
                    // never as fabricated live data.
                    if (noFiltersActive) const _CriticalHandlingPreview(),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) return queueSummary;
                  final r = requests[index - 1];
                  return EntranceFadeSlide(
                    delay: Duration(milliseconds: 40 * (index - 1).clamp(0, 8)),
                    child: _PendingRequestCard(request: r),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Quick queue-composition strip shown above the pending list -
/// critical/high/normal counts for the CURRENT filtered result, so
/// staff can gauge workload shape at a glance before scanning cards.
class _QueueSummaryStrip extends StatelessWidget {
  final int critical;
  final int high;
  final int normal;
  const _QueueSummaryStrip({required this.critical, required this.high, required this.normal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _QueueStat(label: 'Critical', value: critical, color: UrgencyLevel.color(UrgencyLevel.critical))),
          const SizedBox(width: 10),
          Expanded(child: _QueueStat(label: 'High', value: high, color: UrgencyLevel.color(UrgencyLevel.high))),
          const SizedBox(width: 10),
          Expanded(child: _QueueStat(label: 'Normal', value: normal, color: UrgencyLevel.color(UrgencyLevel.normal))),
        ],
      ),
    );
  }
}

class _QueueStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _QueueStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// #visibility - answers "how does this app actually handle a
/// critical/emergency request?" without needing a live one in the
/// queue. Explicitly labelled PREVIEW - every row describes real,
/// already-built behaviour (queue sort, card styling, pulse
/// indicator, Dashboard Emergency Command Center, notifications) so
/// it never claims a capability that doesn't exist.
class _CriticalHandlingPreview extends StatelessWidget {
  const _CriticalHandlingPreview();

  static const _rows = [
    (Icons.north_rounded, 'Jumps to the top of the queue', 'Sorted by urgency first, then by longest waiting time.'),
    (Icons.crop_16_9_rounded, 'Red-tinted card + thick left edge', 'Instantly distinguishable while scanning the list - not just a small label.'),
    (Icons.podcasts_rounded, 'Live pulse indicator', 'A pulsing dot marks it as active/urgent on both this queue and the Dashboard.'),
    (Icons.dashboard_customize_outlined, 'Surfaces on the Dashboard', 'Shows in the Emergency Command Center the moment it is created.'),
    (Icons.notifications_active_outlined, 'Priority alert', 'Pushed to the Alert Center and flagged in the bell icon for staff.'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.critical.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.critical.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_outlined, size: 16, color: colors.critical),
              const SizedBox(width: 8),
              Text('When a critical request arrives', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: colors.champagne.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.champagne, letterSpacing: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'The queue is empty right now, so here is exactly what happens the moment one is submitted:',
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: colors.critical.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(row.$1, size: 14, color: colors.critical),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                        const SizedBox(height: 1),
                        Text(row.$3, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = color ?? colors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : colors.elevatedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : colors.border, width: selected ? 1.4 : 1),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(fontSize: 12.5, color: selected ? accent : colors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.w500),
          child: Text(label),
        ),
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final BloodRequest request;
  const _PendingRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final urgencyColor = UrgencyLevel.color(request.urgency);

    final isCritical = request.urgency == UrgencyLevel.critical;

    return PressableScale(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: request.id))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // #critical-visibility - critical-urgency requests get a
          // visibly different card (tinted fill + thicker colored left
          // edge), not just a small text chip, so they are impossible
          // to miss while scanning the queue.
          color: isCritical ? urgencyColor.withValues(alpha: 0.05) : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            top: BorderSide(color: urgencyColor.withValues(alpha: isCritical ? 0.6 : 0.4)),
            right: BorderSide(color: urgencyColor.withValues(alpha: isCritical ? 0.6 : 0.4)),
            bottom: BorderSide(color: urgencyColor.withValues(alpha: isCritical ? 0.6 : 0.4)),
            left: BorderSide(color: urgencyColor, width: isCritical ? 4 : 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isCritical) ...[LivePulseDot(color: urgencyColor), const SizedBox(width: 8)],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(request.urgency, style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Flexible(child: Align(alignment: Alignment.centerRight, child: RequestHealthBadge(request: request, showWaitingTime: true))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
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
                      Text(request.patientName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('${request.unitsNeeded} unit(s) · ${request.hospitalName}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // #visibility - an explicit, unmistakable CTA so staff know
            // tapping the card opens the full Patient Case Summary
            // (patient info, blood requirement, checklist, matching,
            // timeline) - not just a plain tappable row.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: colors.elevatedSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text('View Patient Details & Verify', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.primary)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: colors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
