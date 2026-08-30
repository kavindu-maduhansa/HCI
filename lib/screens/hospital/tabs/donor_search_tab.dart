import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/request_status.dart';
import '../../../theme/app_colors.dart';
import '../../../models/blood_request.dart';
import '../../../services/request_service.dart';
import '../../../widgets/common_states.dart';
import '../../../widgets/entrance_fade_slide.dart';
import '../../../widgets/pressable_scale.dart';
import '../../../widgets/skeleton_loader.dart';

/// FR09 - Donor availability search, upgraded into a professional
/// donor-matching workspace.
///
/// Lets hospital/blood-bank staff search the donor pool by blood
/// group and location instead of manually phoning contacts one by
/// one. When [selectMode] is true (opened from a request's "Find
/// Matching Donors" action) results are ranked by a transparent,
/// deterministic APPLICATION MATCH SCORE against that request - never
/// presented as medical certainty - and tapping a donor returns their
/// data to the caller for notification/assignment.
///
/// #16 Donor privacy: only name, blood group, approximate location
/// and eligibility are ever shown here - phone numbers are read but
/// never rendered in this list.
class DonorSearchTab extends StatefulWidget {
  final bool selectMode;
  final String? initialBloodGroupFilter;
  final String? requestLocation;

  const DonorSearchTab({super.key, this.selectMode = false, this.initialBloodGroupFilter, this.requestLocation});

  @override
  State<DonorSearchTab> createState() => _DonorSearchTabState();
}

enum _SortMode { bestMatch, recentlyAvailable, name }

class _DonorSearchTabState extends State<DonorSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _bloodGroupFilter;
  bool _onlyEligible = false;
  bool _onlyVerified = false;
  bool _onlyAvailable = false;
  _SortMode _sortMode = _SortMode.bestMatch;

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  List<String>? get _compatibleGroups => widget.initialBloodGroupFilter != null
      ? BloodCompatibility.compatibleDonorGroups(widget.initialBloodGroupFilter!)
      : null;

  @override
  void initState() {
    super.initState();
    if (!widget.selectMode) _sortMode = _SortMode.recentlyAvailable;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compatibleGroups = _compatibleGroups;

    return Column(
      children: [
        if (compatibleGroups != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing donors compatible with ${widget.initialBloodGroupFilter}: ${compatibleGroups.join(', ')}. Ranked by application match score.',
                    style: TextStyle(fontSize: 11.5, color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
        EntranceFadeSlide(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by name or location...',
                        hintStyle: TextStyle(color: colors.textSecondary),
                        prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.elevatedSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1.6)),
                      ),
                    ),
                  ),
                  if (!widget.selectMode) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Register Walk-in Donor',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _RegisterWalkInDonorSheet.show(context),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: compatibleGroups != null ? 'All Compatible' : 'All Groups',
                      selected: _bloodGroupFilter == null,
                      onTap: () => setState(() => _bloodGroupFilter = null),
                    ),
                    ...(compatibleGroups ?? _groups).map((g) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _FilterChip(label: g, selected: _bloodGroupFilter == g, onTap: () => setState(() => _bloodGroupFilter = g)),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ToggleFilterChip(label: 'Eligible only', selected: _onlyEligible, onChanged: (v) => setState(() => _onlyEligible = v)),
                        _ToggleFilterChip(label: 'Verified only', selected: _onlyVerified, onChanged: (v) => setState(() => _onlyVerified = v)),
                        _ToggleFilterChip(label: 'Available only', selected: _onlyAvailable, onChanged: (v) => setState(() => _onlyAvailable = v)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_SortMode>(
                    tooltip: 'Sort donors',
                    initialValue: _sortMode,
                    onSelected: (v) => setState(() => _sortMode = v),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: _SortMode.bestMatch, child: Text('Best Match')),
                      PopupMenuItem(value: _SortMode.recentlyAvailable, child: Text('Recently Available')),
                      PopupMenuItem(value: _SortMode.name, child: Text('Name (A-Z)')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.elevatedSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_rounded, size: 15, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(_sortLabel(_sortMode), style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
        Expanded(
          // #reliability - a collectionGroup read of every donor's real
          // response history (completed vs declined), aggregated once
          // per rebuild into a donorId -> (completed, declined) map.
          // Donors with zero resolved responses get no score at all
          // (shown as "New donor" instead of a fabricated number).
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collectionGroup('responses').snapshots(),
            builder: (context, reliabilitySnap) {
              final reliability = <String, (int completed, int declined)>{};
              if (!reliabilitySnap.hasError) {
                for (final doc in reliabilitySnap.data?.docs ?? const []) {
                  final data = doc.data();
                  final donorId = data['donorId'] as String?;
                  if (donorId == null) continue;
                  final status = data['status'] as String?;
                  if (status != 'completed' && status != 'declined') continue;
                  final prev = reliability[donorId] ?? (0, 0);
                  reliability[donorId] = status == 'completed' ? (prev.$1 + 1, prev.$2) : (prev.$1, prev.$2 + 1);
                }
              }
              return _DonorListStream(
                bloodGroupFilter: _bloodGroupFilter,
                compatibleGroups: compatibleGroups,
                onlyVerified: _onlyVerified,
                onlyEligible: _onlyEligible,
                onlyAvailable: _onlyAvailable,
                searchQuery: _searchController.text,
                sortMode: _sortMode,
                selectMode: widget.selectMode,
                requestLocation: widget.requestLocation,
                reliability: reliability,
              );
            },
          ),
        ),
      ],
    );
  }

  static String _sortLabel(_SortMode mode) {
    switch (mode) {
      case _SortMode.bestMatch:
        return 'Best Match';
      case _SortMode.recentlyAvailable:
        return 'Recently Available';
      case _SortMode.name:
        return 'Name';
    }
  }
}

/// Extracted so the donor-list StreamBuilder (and its filtering/sorting
/// logic) stays exactly as it was, just now also receiving the
/// donor-reliability map computed by its parent.
class _DonorListStream extends StatelessWidget {
  final String? bloodGroupFilter;
  final List<String>? compatibleGroups;
  final bool onlyVerified;
  final bool onlyEligible;
  final bool onlyAvailable;
  final String searchQuery;
  final _SortMode sortMode;
  final bool selectMode;
  final String? requestLocation;
  final Map<String, (int completed, int declined)> reliability;

  const _DonorListStream({
    required this.bloodGroupFilter,
    required this.compatibleGroups,
    required this.onlyVerified,
    required this.onlyEligible,
    required this.onlyAvailable,
    required this.searchQuery,
    required this.sortMode,
    required this.selectMode,
    required this.requestLocation,
    required this.reliability,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compatibleGroups = this.compatibleGroups;
    final _bloodGroupFilter = bloodGroupFilter;
    final _onlyVerified = onlyVerified;
    final _onlyEligible = onlyEligible;
    final _onlyAvailable = onlyAvailable;
    final _sortMode = sortMode;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Donor').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(message: 'Unable to load donors right now.\n${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const ListCardSkeleton();
              }

              final query = searchQuery.trim().toLowerCase();
              var donors = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final name = (data['fullName'] as String? ?? '').toLowerCase();
                final location = (data['location'] as String? ?? '').toLowerCase();
                final group = data['bloodGroup'] as String?;
                final verified = data['verified'] == true;
                final available = data['availableNow'] != false; // missing = assumed available
                final lastDonation = (data['lastDonationDate'] as Timestamp?)?.toDate();
                final eligible = DonorEligibility.isEligible(lastDonation);

                if (data['isActive'] == false) return false;
                if (_bloodGroupFilter != null) {
                  if (group != _bloodGroupFilter) return false;
                } else if (compatibleGroups != null) {
                  if (group == null || !compatibleGroups.contains(group)) return false;
                }
                if (_onlyVerified && !verified) return false;
                if (_onlyEligible && !eligible) return false;
                if (_onlyAvailable && !available) return false;
                if (query.isNotEmpty && !name.contains(query) && !location.contains(query)) return false;
                return true;
              }).toList();

              // #14 - Smart Donor Matching: transparent, deterministic
              // ranking. Never presented as medical certainty - every
              // contributing factor is shown as a checkmark tag below.
              switch (_sortMode) {
                case _SortMode.bestMatch:
                  donors.sort((a, b) => _matchScore(b.data(), requestLocation).compareTo(_matchScore(a.data(), requestLocation)));
                case _SortMode.recentlyAvailable:
                  donors.sort((a, b) {
                    final aAvail = a.data()['availableNow'] != false;
                    final bAvail = b.data()['availableNow'] != false;
                    if (aAvail != bAvail) return aAvail ? -1 : 1;
                    final aTime = (a.data()['lastDonationDate'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bTime = (b.data()['lastDonationDate'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });
                case _SortMode.name:
                  donors.sort((a, b) => (a.data()['fullName'] as String? ?? '').compareTo(b.data()['fullName'] as String? ?? ''));
              }

              if (donors.isEmpty) {
                return EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No available donors',
                  message: 'No compatible available donors were found. Try widening your filters.',
                );
              }

              final verifiedCount = donors.where((d) => d.data()['verified'] == true).length;
              final availableCount = donors.where((d) => d.data()['availableNow'] != false).length;
              final eligibleCount = donors.where((d) => DonorEligibility.isEligible((d.data()['lastDonationDate'] as Timestamp?)?.toDate())).length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(child: _DonorStatChip(label: 'Found', value: donors.length, color: colors.textPrimary)),
                        const SizedBox(width: 8),
                        Expanded(child: _DonorStatChip(label: 'Verified', value: verifiedCount, color: colors.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _DonorStatChip(label: 'Available', value: availableCount, color: colors.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _DonorStatChip(label: 'Eligible', value: eligibleCount, color: colors.warning)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: donors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = donors[index];
                        return EntranceFadeSlide(
                          delay: Duration(milliseconds: 35 * index.clamp(0, 10)),
                          child: _DonorCard(
                            donorId: doc.id,
                            data: doc.data(),
                            selectMode: selectMode,
                            requestLocation: requestLocation,
                            rank: selectMode ? index : null,
                            reliability: reliability[doc.id],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      'Matching assistance only — final donor selection remains with authorized medical staff.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: colors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              );
            },
          );
  }
}

/// Simple, transparent 0-100 match score used only to rank/annotate
/// results when searching for a specific request (#14/#15). Every
/// contributing factor is shown to the doctor as a checkmark, so
/// nothing is a hidden "black box" score. Labelled APPLICATION MATCH
/// SCORE wherever shown - never presented as medical certainty.
int _matchScore(Map<String, dynamic> data, String? requestLocation) {
  var score = 0;
  if (data['verified'] == true) score += 20;
  final available = data['availableNow'] != false;
  if (available) score += 20;
  final lastDonation = (data['lastDonationDate'] as Timestamp?)?.toDate();
  if (DonorEligibility.isEligible(lastDonation)) score += 30;
  final donorLocation = (data['location'] as String? ?? '').toLowerCase().trim();
  if (requestLocation != null && donorLocation.isNotEmpty && requestLocation.toLowerCase().trim().contains(donorLocation)) {
    score += 30;
  } else if (requestLocation == null) {
    // No specific request to compare against - don't penalise.
    score += 15;
  }
  return score;
}

/// #14 - One line item of the Match Score breakdown: a single scored
/// factor (Compatibility / Availability / Eligibility / Location),
/// with the exact points it contributed and a plain-language reason.
/// Built from the same fields [_matchScore] uses - nothing invented,
/// this just makes the existing arithmetic visible to staff.
class _MatchFactor {
  final String label;
  final IconData icon;
  final int points;
  final int maxPoints;
  final String detail;
  const _MatchFactor({required this.label, required this.icon, required this.points, required this.maxPoints, required this.detail});
}

List<_MatchFactor> _matchBreakdown(Map<String, dynamic> data, String? requestLocation) {
  final verified = data['verified'] == true;
  final available = data['availableNow'] != false;
  final lastDonation = (data['lastDonationDate'] as Timestamp?)?.toDate();
  final eligible = DonorEligibility.isEligible(lastDonation);
  final donorLocation = (data['location'] as String? ?? '').toLowerCase().trim();
  final nearby = requestLocation != null && donorLocation.isNotEmpty && requestLocation.toLowerCase().trim().contains(donorLocation);

  return [
    _MatchFactor(
      label: 'Verified Donor',
      icon: Icons.verified_outlined,
      points: verified ? 20 : 0,
      maxPoints: 20,
      detail: verified ? 'Identity verified by hospital/blood-bank staff.' : 'Not yet verified by staff.',
    ),
    _MatchFactor(
      label: 'Availability',
      icon: Icons.event_available_outlined,
      points: available ? 20 : 0,
      maxPoints: 20,
      detail: available ? 'Marked available to donate right now.' : 'Currently marked unavailable.',
    ),
    _MatchFactor(
      label: 'Eligibility (90-day rule)',
      icon: Icons.health_and_safety_outlined,
      points: eligible ? 30 : 0,
      maxPoints: 30,
      detail: eligible
          ? (lastDonation == null ? 'No prior donation on record - eligible by default.' : 'Past the required 90-day recovery window since last donation.')
          : 'Still inside the 90-day recovery window since last donation.',
    ),
    _MatchFactor(
      label: 'Location Proximity',
      icon: Icons.location_on_outlined,
      points: requestLocation == null ? 15 : (nearby ? 30 : 0),
      maxPoints: 30,
      detail: requestLocation == null
          ? 'No request location to compare against - neutral score.'
          : (nearby ? 'Donor location matches the request location.' : 'Donor location does not match the request location.'),
    ),
  ];
}

/// #14 - Match tier label + medal, purely a presentation layer over
/// the same transparent [_matchScore].
class _MatchTier {
  final String emoji;
  final String label;
  final Color Function(AppColors) color;
  const _MatchTier(this.emoji, this.label, this.color);
}

/// #14 - "WHY this donor matched": tapping the score/tier chip opens a
/// transparent, factor-by-factor breakdown of the exact same points
/// used to rank the donor, so staff never have to trust a bare number.
void _showMatchBreakdown(BuildContext context, AppColors colors, int score, _MatchTier? tier, Map<String, dynamic> data, String? requestLocation) {
  final factors = _matchBreakdown(data, requestLocation);
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            if (tier != null) ...[Text(tier.emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8)],
            Expanded(child: Text('$score% Application Match', style: TextStyle(color: colors.textPrimary, fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in factors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(f.icon, size: 15, color: f.points > 0 ? colors.success : colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(f.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                                Text('+${f.points}/${f.maxPoints}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: f.points > 0 ? colors.success : colors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(f.detail, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: colors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Matching assistance only. Final donor selection remains with authorized medical staff.',
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      );
    },
  );
}

_MatchTier? _tierFor(int score) {
  if (score >= 85) return _MatchTier('🥇', 'BEST MATCH', (c) => c.success);
  if (score >= 70) return _MatchTier('🥈', 'STRONG MATCH', (c) => c.primary);
  if (score >= 50) return _MatchTier('🥉', 'SUITABLE MATCH', (c) => c.warning);
  return null;
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.15) : colors.elevatedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: selected ? colors.primary : colors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }
}

class _ToggleFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const _ToggleFilterChip({required this.label, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.15) : colors.elevatedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: selected ? colors.primary : colors.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, color: selected ? colors.primary : colors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  final String donorId;
  final Map<String, dynamic> data;
  final bool selectMode;
  final String? requestLocation;
  final int? rank;
  final (int completed, int declined)? reliability;

  const _DonorCard({required this.donorId, required this.data, required this.selectMode, this.requestLocation, this.rank, this.reliability});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = data['fullName'] as String? ?? 'Donor';
    final group = data['bloodGroup'] as String? ?? '-';
    final location = (data['location'] as String?)?.trim();
    final verified = data['verified'] == true;
    final available = data['availableNow'] != false;
    final lastDonation = (data['lastDonationDate'] as Timestamp?)?.toDate();
    final eligible = DonorEligibility.isEligible(lastDonation);
    final daysLeft = DonorEligibility.daysUntilEligible(lastDonation);
    final score = _matchScore(data, requestLocation);
    final tier = selectMode && rank != null && rank! < 3 ? _tierFor(score) : null;

    return PressableScale(
      borderRadius: BorderRadius.circular(14),
      onTap: selectMode
          ? () => Navigator.pop(context, {
                'donorId': donorId,
                'donorName': name,
                'donorPhone': data['phoneNumber'] ?? '',
                'bloodGroup': group,
              })
          : () => _showDonorProfile(context, colors),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tier != null ? tier.color(colors).withValues(alpha: 0.5) : colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tier != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showMatchBreakdown(context, colors, score, tier, data, requestLocation),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tier.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(tier.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tier.color(colors), letterSpacing: 0.4)),
                      const SizedBox(width: 3),
                      Icon(Icons.info_outline_rounded, size: 10, color: tier.color(colors).withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.critical.withValues(alpha: 0.1),
                  child: Text(group, style: TextStyle(color: colors.critical, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          ),
                          if (verified) ...[const SizedBox(width: 4), Icon(Icons.verified_rounded, size: 15, color: colors.primary)],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(location?.isNotEmpty == true ? location! : 'Location not set', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    ],
                  ),
                ),
                if (selectMode)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showMatchBreakdown(context, colors, score, tier, data, requestLocation),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$score% Match', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary)),
                          const SizedBox(width: 2),
                          Icon(Icons.info_outline_rounded, size: 10, color: colors.primary.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(label: 'Compatible', ok: true),
                _Tag(label: 'Available', ok: available),
                _Tag(label: 'Eligible', ok: eligible, hint: eligible ? null : 'in ${daysLeft}d'),
                if (requestLocation != null) _Tag(label: 'Nearby', ok: score >= 50 && (location?.isNotEmpty ?? false)),
                if (reliability != null) _ReliabilityBadge(reliability: reliability!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// #8 - Donor Profile. Shown when browsing (not select mode).
  /// Deliberately omits phone number and any other sensitive contact
  /// detail - matching/coordination purposes never require exposing
  /// that here. The donation-history section below is built entirely
  /// from this donor's real `responses` subcollection entries across
  /// every request they were ever notified on - nothing invented.
  void _showDonorProfile(BuildContext context, AppColors colors) {
    final name = data['fullName'] as String? ?? 'Donor';
    final group = data['bloodGroup'] as String? ?? '-';
    final location = (data['location'] as String?)?.trim();
    final verified = data['verified'] == true;
    final available = data['availableNow'] != false;
    final lastDonation = (data['lastDonationDate'] as Timestamp?)?.toDate();
    final eligible = DonorEligibility.isEligible(lastDonation);
    final daysLeft = DonorEligibility.daysUntilEligible(lastDonation);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.critical.withValues(alpha: 0.1),
                  child: Text(group, style: TextStyle(color: colors.critical, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      Text('Donor ID ${donorId.substring(0, donorId.length < 8 ? donorId.length : 8).toUpperCase()}', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                      Text(location?.isNotEmpty == true ? location! : 'Location not set', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(label: 'Verified', ok: verified),
                _Tag(label: 'Available', ok: available),
                _Tag(label: 'Eligible', ok: eligible, hint: eligible ? null : 'in ${daysLeft}d'),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(label: 'Last Donation', value: lastDonation == null ? 'Not on record' : _formatDate(lastDonation)),
            _InfoLine(label: 'Next Eligible', value: eligible ? 'Eligible now' : (daysLeft != null ? _formatDate(DateTime.now().add(Duration(days: daysLeft))) : '—')),
            const SizedBox(height: 20),
            Text('DONATION HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: colors.textSecondary)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collectionGroup('responses').where('donorId', isEqualTo: donorId).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)));
                }
                final records = snap.data!.docs.map(DonorResponseRecord.fromDoc).toList()
                  ..sort((a, b) => (b.respondedAt ?? b.notifiedAt ?? DateTime(2000)).compareTo(a.respondedAt ?? a.notifiedAt ?? DateTime(2000)));

                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No response history yet - this donor has not been notified for a request.', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                  );
                }

                final completed = records.where((r) => r.status == 'completed').length;
                final declined = records.where((r) => r.status == 'declined').length;
                final resolved = completed + declined;
                final responseRate = records.isEmpty ? 0 : (records.where((r) => r.status != 'notified').length / records.length * 100).round();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MiniStat(label: 'Completed', value: '$completed', color: colors.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _MiniStat(label: 'Declined', value: '$declined', color: colors.critical)),
                        const SizedBox(width: 8),
                        Expanded(child: _MiniStat(label: 'Response Rate', value: '$responseRate%', color: colors.primary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStat(
                            label: 'Reliability',
                            value: resolved == 0 ? '—' : '${(completed / resolved * 100).round()}%',
                            color: resolved == 0 ? colors.textSecondary : (completed / resolved >= 0.8 ? colors.success : colors.warning),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final r in records.take(8)) _DonationHistoryRow(record: r),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showVerifyDialog(context, colors);
                },
                icon: Icon(Icons.edit_rounded, size: 17, color: colors.primary),
                label: Text(verified ? 'Update Verification' : 'Verify Donor', style: TextStyle(color: colors.primary)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: colors.primary), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  void _showVerifyDialog(BuildContext context, AppColors colors) {
    final name = data['fullName'] as String? ?? 'Donor';
    final verified = data['verified'] == true;
    String? selectedGroup = data['bloodGroup'] as String?;
    final locationController = TextEditingController(text: data['location'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Verify $name'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verified ? 'Already verified. Update details below if needed.' : 'Confirm this donor\'s blood group before they appear in matching search results.',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  decoration: const InputDecoration(labelText: 'Confirmed Blood Group', border: OutlineInputBorder()),
                  items: const ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setDialogState(() => selectedGroup = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Location / City',
                    border: const OutlineInputBorder(),
                    errorText: locationController.text.trim().isEmpty ? 'Location is required' : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
              onPressed: (selectedGroup == null || locationController.text.trim().isEmpty)
                  ? null
                  : () async {
                      final doctor = FirebaseAuth.instance.currentUser;
                      await FirebaseFirestore.instance.collection('users').doc(donorId).update({
                        'bloodGroup': selectedGroup,
                        'location': locationController.text.trim(),
                        'verified': true,
                        'verifiedBy': doctor?.email ?? 'Hospital Staff',
                        'verifiedAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Confirm Verification'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets hospital/blood-bank staff register a donor who walks into the
/// facility in person, without duplicating the Donor module's own
/// app-based registration flow. Writes a normal, staff-verified
/// `users` document using the exact same field names every other
/// donor query in this module already reads (see
/// `RequestService.registerWalkInDonor`) - so the new donor appears
/// in search results immediately, indistinguishable from a
/// self-registered one except for its `source: 'walk-in'` label.
class _RegisterWalkInDonorSheet extends StatefulWidget {
  const _RegisterWalkInDonorSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _RegisterWalkInDonorSheet(),
    );
  }

  @override
  State<_RegisterWalkInDonorSheet> createState() => _RegisterWalkInDonorSheetState();
}

class _RegisterWalkInDonorSheetState extends State<_RegisterWalkInDonorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  String? _bloodGroup;
  bool _submitting = false;

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _bloodGroup == null) {
      if (_bloodGroup == null) showErrorSnack(context, 'Please select a blood group.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final doctor = FirebaseAuth.instance.currentUser;
      await RequestService.instance.registerWalkInDonor(
        fullName: _nameController.text.trim(),
        bloodGroup: _bloodGroup!,
        phoneNumber: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        doctorId: doctor?.uid ?? '',
        doctorName: doctor?.email ?? 'Hospital Staff',
      );
      if (mounted) {
        Navigator.pop(context);
        showSuccessSnack(context, '${_nameController.text.trim()} registered as a verified donor.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showErrorSnack(context, 'Could not register donor.\n$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Text('Register Walk-in Donor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'For a donor present in person at this facility. They will appear as a staff-verified donor in search immediately.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Full name is required.';
                  if (name.length < 3) return 'Name looks too short.';
                  if (!RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(name)) return 'Name should only contain letters.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _bloodGroup = v),
                validator: (v) => v == null ? 'Please select a blood group.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'e.g. 0771234567', border: OutlineInputBorder()),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
                  if (digits.isEmpty) return 'Phone number is required.';
                  if (digits.replaceAll('+', '').length < 9) return 'Enter a valid phone number.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Location / City', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required.' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Register Donor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small stat pill shown above the donor results list - lets staff
/// see how many of the currently filtered donors are verified /
/// available / eligible without reading every card individually.
class _DonorStatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _DonorStatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// #reliability - a real, computed-from-history badge: how often this
/// donor's accepted pledges actually turned into a completed
/// donation (`completed / (completed + declined)`), from every
/// request they've ever responded to across the whole system. Donors
/// with no resolved history yet (brand-new, or only ever "notified")
/// intentionally get no percentage - shown as "New donor" instead of
/// a fabricated number.
class _ReliabilityBadge extends StatelessWidget {
  final (int completed, int declined) reliability;
  const _ReliabilityBadge({required this.reliability});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (completed, declined) = reliability;
    final total = completed + declined;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: colors.textSecondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 11, color: colors.textSecondary),
            const SizedBox(width: 3),
            Text('New donor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.textSecondary)),
          ],
        ),
      );
    }
    final pct = (completed / total * 100).round();
    final color = pct >= 80 ? colors.success : (pct >= 50 ? colors.warning : colors.critical);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 11, color: color),
          const SizedBox(width: 3),
          Text('$pct% reliable ($completed/$total)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// A single entry in a donor's donation-history mini timeline - one
/// real `responses` subcollection document, nothing synthesized.
class _DonationHistoryRow extends StatelessWidget {
  final DonorResponseRecord record;
  const _DonationHistoryRow({required this.record});

  Color _color(AppColors colors) {
    switch (record.status) {
      case 'completed':
        return colors.success;
      case 'declined':
        return colors.critical;
      case 'accepted':
        return colors.primary;
      default:
        return colors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _color(colors);
    final date = record.respondedAt ?? record.notifiedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              record.status[0].toUpperCase() + record.status.substring(1) + (record.unitsPledged > 0 && record.status != 'notified' ? ' · ${record.unitsPledged} unit(s)' : ''),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ),
          Text(date == null ? '—' : _DonorCard._formatDate(date), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool ok;
  final String? hint;
  const _Tag({required this.label, required this.ok, this.hint});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = ok ? colors.success : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(hint != null ? '$label ($hint)' : label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
