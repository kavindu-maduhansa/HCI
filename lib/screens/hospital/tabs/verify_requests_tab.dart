import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // #6 - Operations Table view: a dense, sortable desktop-only
  // alternative to the card list, for staff who prefer to scan a
  // large queue as rows rather than cards. Off by default; only ever
  // offered when the viewport is wide enough to render it well.
  bool _tableView = false;
  _TableSortColumn _sortColumn = _TableSortColumn.urgency;
  bool _sortAscending = true;

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  static const _urgencies = [UrgencyLevel.critical, UrgencyLevel.high, UrgencyLevel.normal];
  static const _kTableBreakpoint = 900.0;

  // #advanced-filters - same on-device Saved Filters pattern already
  // shipped on the History tab (SharedPreferences, no backend needed),
  // extended here so a doctor's frequently-used Verify queue combo
  // (e.g. "Critical O-") survives an app restart too.
  static const _savedFiltersKey = 'verify_saved_filters_v1';
  List<_SavedVerifyFilter> _savedFilters = [];

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedFiltersKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).map((e) => _SavedVerifyFilter.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _savedFilters = list);
    } catch (_) {
      // Corrupt/old-format local data - safe to ignore and start fresh.
    }
  }

  Future<void> _persistSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedFiltersKey, jsonEncode(_savedFilters.map((f) => f.toJson()).toList()));
  }

  bool get _hasActiveFilter => _bloodGroupFilter != null || _urgencyFilter != null;

  void _applyFilter(_SavedVerifyFilter f) {
    setState(() {
      _bloodGroupFilter = f.bloodGroup;
      _urgencyFilter = f.urgency;
    });
  }

  Future<void> _saveCurrentFilter() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this filter'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Critical O- Queue')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _savedFilters = [
          ..._savedFilters,
          _SavedVerifyFilter(name: name, bloodGroup: _bloodGroupFilter, urgency: _urgencyFilter),
        ]);
    await _persistSavedFilters();
  }

  Future<void> _deleteSavedFilter(_SavedVerifyFilter f) async {
    setState(() => _savedFilters = _savedFilters.where((x) => x != f).toList());
    await _persistSavedFilters();
  }

  static final List<_SavedVerifyFilter> _quickPresets = [
    _SavedVerifyFilter(name: 'Critical Only', urgency: UrgencyLevel.critical, icon: Icons.emergency_outlined),
    _SavedVerifyFilter(name: 'O- Requests', bloodGroup: 'O-', icon: Icons.bloodtype_outlined),
    _SavedVerifyFilter(name: 'High Priority', urgency: UrgencyLevel.high, icon: Icons.priority_high_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildBody(context, constraints.maxWidth >= _kTableBreakpoint),
    );
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    final colors = context.colors;
    return Column(
      children: [
        EntranceFadeSlide(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
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
              // #6 - Operations Table toggle, desktop only.
              if (isWide) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: _tableView ? 'Switch to card view' : 'Switch to Operations Table',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _tableView = !_tableView),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: _tableView ? colors.primary : colors.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _tableView ? colors.primary : colors.border),
                      ),
                      child: Icon(Icons.table_rows_outlined, color: _tableView ? Colors.white : colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ],
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
        // #advanced-filters - Quick Presets + on-device Saved Filters,
        // the same pattern already shipped on History, so a doctor's
        // go-to Verify combo is one tap away instead of re-picking
        // blood group + urgency chips every time.
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            children: [
              for (final preset in _quickPresets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(preset.icon, size: 14, color: colors.champagne),
                    label: Text(preset.name, style: const TextStyle(fontSize: 11.5)),
                    backgroundColor: colors.champagne.withValues(alpha: 0.12),
                    side: BorderSide(color: colors.champagne.withValues(alpha: 0.35)),
                    onPressed: () => _applyFilter(preset),
                  ),
                ),
              for (final f in _savedFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    avatar: Icon(f.icon, size: 14, color: colors.primary),
                    label: Text(f.name, style: const TextStyle(fontSize: 11.5)),
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
                    onPressed: () => _applyFilter(f),
                    onDeleted: () => _deleteSavedFilter(f),
                    deleteIconColor: colors.textSecondary,
                  ),
                ),
              if (_hasActiveFilter)
                ActionChip(
                  avatar: Icon(Icons.bookmark_add_outlined, size: 14, color: colors.textSecondary),
                  label: const Text('Save Filter', style: TextStyle(fontSize: 11.5)),
                  backgroundColor: colors.elevatedSurface,
                  side: BorderSide(color: colors.border),
                  onPressed: _saveCurrentFilter,
                ),
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

              if (_tableView && isWide) {
                final sorted = _sortForTable(requests);
                return _OperationsTable(
                  requests: sorted,
                  sortColumn: _sortColumn,
                  ascending: _sortAscending,
                  onSort: (col) => setState(() {
                    if (_sortColumn == col) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortColumn = col;
                      _sortAscending = true;
                    }
                  }),
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

  List<BloodRequest> _sortForTable(List<BloodRequest> requests) {
    final list = [...requests];
    int cmp(BloodRequest a, BloodRequest b) {
      switch (_sortColumn) {
        case _TableSortColumn.id:
          return a.id.compareTo(b.id);
        case _TableSortColumn.patient:
          return a.patientName.compareTo(b.patientName);
        case _TableSortColumn.bloodGroup:
          return a.bloodGroup.compareTo(b.bloodGroup);
        case _TableSortColumn.units:
          return a.unitsNeeded.compareTo(b.unitsNeeded);
        case _TableSortColumn.urgency:
          return UrgencyLevel.weight(a.urgency).compareTo(UrgencyLevel.weight(b.urgency));
        case _TableSortColumn.hospital:
          return a.hospitalName.compareTo(b.hospitalName);
        case _TableSortColumn.waiting:
          return WaitingTime.elapsed(a.createdAt).compareTo(WaitingTime.elapsed(b.createdAt));
        case _TableSortColumn.coverage:
          final aRatio = a.unitsNeeded == 0 ? 0.0 : a.unitsConfirmed / a.unitsNeeded;
          final bRatio = b.unitsNeeded == 0 ? 0.0 : b.unitsConfirmed / b.unitsNeeded;
          return aRatio.compareTo(bRatio);
        case _TableSortColumn.status:
          return a.status.compareTo(b.status);
      }
    }

    list.sort(cmp);
    if (!_sortAscending) return list.reversed.toList();
    return list;
  }
}

enum _TableSortColumn { id, patient, bloodGroup, units, urgency, hospital, waiting, coverage, status }

/// #6 - Operations Table: a dense, sortable data-grid alternative to
/// the card list, for desktop staff who prefer scanning rows. Every
/// column is real request data; clicking a row opens the same Request
/// Details screen the card view uses. Wrapped in horizontal scroll so
/// it degrades gracefully rather than overflowing on a merely-wide
/// (not ultra-wide) desktop window.
class _OperationsTable extends StatelessWidget {
  final List<BloodRequest> requests;
  final _TableSortColumn sortColumn;
  final bool ascending;
  final ValueChanged<_TableSortColumn> onSort;
  const _OperationsTable({required this.requests, required this.sortColumn, required this.ascending, required this.onSort});

  int? _colIndex(_TableSortColumn col) => _TableSortColumn.values.indexOf(col);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              sortColumnIndex: _colIndex(sortColumn),
              sortAscending: ascending,
              headingRowColor: WidgetStateProperty.all(colors.elevatedSurface),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: [
                DataColumn(label: Text('Request ID', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.id)),
                DataColumn(label: Text('Patient', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.patient)),
                DataColumn(label: Text('Group', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.bloodGroup)),
                DataColumn(label: Text('Units', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true, onSort: (_, _) => onSort(_TableSortColumn.units)),
                DataColumn(label: Text('Urgency', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.urgency)),
                DataColumn(label: Text('Hospital', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.hospital)),
                DataColumn(label: Text('Waiting', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.waiting)),
                DataColumn(label: Text('Coverage', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.coverage)),
                DataColumn(label: Text('Status', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)), onSort: (_, _) => onSort(_TableSortColumn.status)),
              ],
              rows: requests.map((r) {
                final urgencyColor = UrgencyLevel.color(r.urgency);
                final coveragePct = r.unitsNeeded == 0 ? 0 : ((r.unitsConfirmed / r.unitsNeeded) * 100).round();
                return DataRow(
                  onSelectChanged: (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: r.id))),
                  cells: [
                    DataCell(Text(r.id.substring(0, r.id.length < 8 ? r.id.length : 8).toUpperCase(), style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontFamily: 'monospace'))),
                    DataCell(Text(r.patientName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary))),
                    DataCell(Text(r.bloodGroup, style: TextStyle(fontSize: 12.5, color: colors.critical, fontWeight: FontWeight.bold))),
                    DataCell(Text('${r.unitsNeeded}', style: TextStyle(fontSize: 12.5, color: colors.textPrimary))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(r.urgency, style: TextStyle(fontSize: 11, color: urgencyColor, fontWeight: FontWeight.bold)),
                    )),
                    DataCell(Text(r.hospitalName, style: TextStyle(fontSize: 12.5, color: colors.textPrimary))),
                    DataCell(Text(WaitingTime.format(r.createdAt), style: TextStyle(fontSize: 12, color: colors.textSecondary))),
                    DataCell(Text('$coveragePct%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: coveragePct >= 100 ? colors.success : colors.textPrimary))),
                    DataCell(Text(RequestStatus.label(r.status), style: TextStyle(fontSize: 11.5, color: RequestStatus.color(r.status), fontWeight: FontWeight.w600))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
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

/// A saved (or quick-preset) filter combo for the Verify Requests
/// queue - blood group + urgency only, mirroring the pattern already
/// shipped on the History tab. Persisted locally (SharedPreferences)
/// under its own key so it never collides with History's saved list.
class _SavedVerifyFilter {
  final String name;
  final String? bloodGroup;
  final String? urgency;
  final IconData icon;
  _SavedVerifyFilter({required this.name, this.bloodGroup, this.urgency, this.icon = Icons.bookmark_rounded});

  Map<String, dynamic> toJson() => {'name': name, 'bloodGroup': bloodGroup, 'urgency': urgency};
  factory _SavedVerifyFilter.fromJson(Map<String, dynamic> json) => _SavedVerifyFilter(
        name: json['name'] as String? ?? 'Filter',
        bloodGroup: json['bloodGroup'] as String?,
        urgency: json['urgency'] as String?,
      );
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
            // #two-person-verification - a critical request with one
            // co-sign already on it needs a visibly different signal in
            // the queue, so staff know one tap here finishes the second
            // approval instead of starting from zero.
            if (request.awaitingSecondApproval) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: colors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gpp_maybe_outlined, size: 12, color: colors.warning),
                    const SizedBox(width: 4),
                    Text('1st approval by ${request.firstApproverName ?? 'staff'} - needs 2nd', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.warning)),
                  ],
                ),
              ),
            ],
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
