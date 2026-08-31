import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../request_details_screen.dart';
import '../pdf_report.dart';
import '../csv_export.dart';
import '../../../models/blood_request.dart';
import '../../../utils/request_status.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common_states.dart';
import '../../../widgets/entrance_fade_slide.dart';
import '../../../widgets/pressable_scale.dart';
import '../../../widgets/skeleton_loader.dart';

/// FR14 - Request history, upgraded with advanced search (#9) and a
/// compact analytics summary + PDF export.
///
/// The Firestore query only filters by status server-side
/// (`whereIn` history statuses) - it deliberately does NOT add a
/// server-side `orderBy` on a different field, because that combo
/// requires a Firestore composite index that does not exist in this
/// project yet. Sorting by `updatedAt` is instead done client-side on
/// the already-narrowed result set, so History works out of the box
/// without anyone needing to create an index in the Firebase console.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

enum _HistorySortMode { newest, oldest, bloodGroup, patientName }

class _HistoryTabState extends State<HistoryTab> {
  String? _statusFilter;
  String? _priorityFilter;
  String? _bloodGroupFilter;
  DateTimeRange? _dateRange;
  _HistorySortMode _sortMode = _HistorySortMode.newest;
  final TextEditingController _searchController = TextEditingController();

  // #5 - Saved Filters, persisted on this device (SharedPreferences)
  // so a doctor's frequently-used filter combos (e.g. "O- Requests")
  // survive app restarts without needing any backend support.
  static const _savedFiltersKey = 'history_saved_filters_v1';
  List<_SavedFilter> _savedFilters = [];

  static const _groups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  // #pagination - History has no cap on how far back it can go, and
  // rendering every matching request at once gets slow once a
  // hospital has months of closed requests. Firestore itself isn't
  // paginated server-side here (the query already avoids a composite
  // index by sorting client-side - see the StreamBuilder below), so
  // this is a simple client-side "show more" page: only the first
  // _visibleCount of the already-filtered/sorted list are rendered,
  // with a button to reveal the next page. Summary stats and CSV/PDF
  // export still operate on the FULL filtered list, never the
  // truncated one, so exported data is always complete.
  static const _pageSize = 20;
  int _visibleCount = _pageSize;

  // #perf - created once instead of calling `.snapshots()` inline in
  // build(). The search field's onChanged calls setState on every
  // keystroke, so an inline `stream: ....snapshots()` expression in
  // build() would rebuild (and force Firestore to resubscribe) this
  // query on every single keystroke instead of only when the actual
  // status filter changes.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
    _requestsStream = FirebaseFirestore.instance.collection('requests').where('status', whereIn: RequestStatus.historyStatuses).snapshots();
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
      final list = (jsonDecode(raw) as List).map((e) => _SavedFilter.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _savedFilters = list);
    } catch (_) {
      // Corrupt/old-format local data - safe to ignore and start fresh.
    }
  }

  Future<void> _persistSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedFiltersKey, jsonEncode(_savedFilters.map((f) => f.toJson()).toList()));
  }

  bool get _hasActiveFilter => _statusFilter != null || _priorityFilter != null || _bloodGroupFilter != null;

  void _applyFilter(_SavedFilter f) {
    setState(() {
      _statusFilter = f.status;
      _priorityFilter = f.priority;
      _bloodGroupFilter = f.bloodGroup;
    });
  }

  Future<void> _saveCurrentFilter() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this filter'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Critical O- Requests')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _savedFilters = [
          ..._savedFilters,
          _SavedFilter(name: name, status: _statusFilter, priority: _priorityFilter, bloodGroup: _bloodGroupFilter),
        ]);
    await _persistSavedFilters();
  }

  Future<void> _deleteSavedFilter(_SavedFilter f) async {
    setState(() => _savedFilters = _savedFilters.where((x) => x != f).toList());
    await _persistSavedFilters();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (range != null && mounted) setState(() => _dateRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        EntranceFadeSlide(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by request ID, patient, blood group, or hospital...',
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(label: 'All Status', selected: _statusFilter == null, onTap: () => setState(() => _statusFilter = null)),
                ...RequestStatus.historyStatuses.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Chip(label: RequestStatus.label(s), selected: _statusFilter == s, onTap: () => setState(() => _statusFilter = s)),
                    )),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _Chip(label: 'All Priority', selected: _priorityFilter == null, onTap: () => setState(() => _priorityFilter = null)),
                ),
                ...UrgencyLevel.all.map((u) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Chip(label: u, selected: _priorityFilter == u, onTap: () => setState(() => _priorityFilter = u)),
                    )),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(width: 1, color: colors.border, margin: const EdgeInsets.symmetric(vertical: 8)),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _Chip(label: 'All Groups', selected: _bloodGroupFilter == null, onTap: () => setState(() => _bloodGroupFilter = null)),
                ),
                ..._groups.map((g) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Chip(label: g, selected: _bloodGroupFilter == g, onTap: () => setState(() => _bloodGroupFilter = _bloodGroupFilter == g ? null : g)),
                    )),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    avatar: Icon(Icons.date_range_rounded, size: 15, color: colors.primary),
                    label: Text(_dateRange == null ? 'Date Range' : '${_fmt(_dateRange!.start)} - ${_fmt(_dateRange!.end)}',
                        style: TextStyle(fontSize: 11, color: colors.textPrimary)),
                    onPressed: _pickDateRange,
                    backgroundColor: colors.elevatedSurface,
                    side: BorderSide(color: _dateRange == null ? colors.border : colors.primary),
                  ),
                ),
                if (_dateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, size: 16, color: colors.textSecondary),
                      onPressed: () => setState(() => _dateRange = null),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: PopupMenuButton<_HistorySortMode>(
                    tooltip: 'Sort history',
                    initialValue: _sortMode,
                    onSelected: (v) => setState(() => _sortMode = v),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: _HistorySortMode.newest, child: Text('Newest First')),
                      PopupMenuItem(value: _HistorySortMode.oldest, child: Text('Oldest First')),
                      PopupMenuItem(value: _HistorySortMode.bloodGroup, child: Text('Blood Group')),
                      PopupMenuItem(value: _HistorySortMode.patientName, child: Text('Patient Name (A-Z)')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.elevatedSurface,
                        borderRadius: BorderRadius.circular(20),
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
                ),
              ],
            ),
          ),
        ),
        // #5 - Quick Presets (fixed, always available) + Saved Filters
        // (user-defined, persisted on-device). One tap applies the
        // whole status/priority/blood-group combo at once.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final preset in _quickPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: Icon(preset.icon, size: 13, color: colors.champagne),
                      label: Text(preset.name, style: TextStyle(fontSize: 11, color: colors.textPrimary)),
                      backgroundColor: colors.champagne.withValues(alpha: 0.1),
                      side: BorderSide(color: colors.champagne.withValues(alpha: 0.35)),
                      onPressed: () => _applyFilter(preset),
                    ),
                  ),
                for (final f in _savedFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      avatar: Icon(Icons.bookmark_rounded, size: 13, color: colors.primary),
                      label: Text(f.name, style: TextStyle(fontSize: 11, color: colors.textPrimary)),
                      backgroundColor: colors.primary.withValues(alpha: 0.08),
                      side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
                      onPressed: () => _applyFilter(f),
                      onDeleted: () => _deleteSavedFilter(f),
                      deleteIconColor: colors.textSecondary,
                    ),
                  ),
                if (_hasActiveFilter)
                  ActionChip(
                    avatar: Icon(Icons.add_rounded, size: 14, color: colors.textSecondary),
                    label: Text('Save Filter', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                    backgroundColor: colors.elevatedSurface,
                    side: BorderSide(color: colors.border),
                    onPressed: _saveCurrentFilter,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(message: 'Unable to load request history right now.\n${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const ListCardSkeleton();
              }

              var requests = snapshot.data!.docs.map(BloodRequest.fromDoc).toList();
              switch (_sortMode) {
                case _HistorySortMode.newest:
                  requests.sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
                case _HistorySortMode.oldest:
                  requests.sort((a, b) => (a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
                case _HistorySortMode.bloodGroup:
                  requests.sort((a, b) => a.bloodGroup.compareTo(b.bloodGroup));
                case _HistorySortMode.patientName:
                  requests.sort((a, b) => a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase()));
              }

              if (_statusFilter != null) requests = requests.where((r) => r.status == _statusFilter).toList();
              if (_priorityFilter != null) requests = requests.where((r) => r.urgency == _priorityFilter).toList();
              if (_bloodGroupFilter != null) requests = requests.where((r) => r.bloodGroup == _bloodGroupFilter).toList();
              if (_dateRange != null) {
                requests = requests.where((r) {
                  if (r.createdAt == null) return false;
                  final d = r.createdAt!;
                  return !d.isBefore(_dateRange!.start) && d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
                }).toList();
              }
              final query = _searchController.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                requests = requests.where((r) {
                  return r.id.toLowerCase().contains(query) ||
                      r.patientName.toLowerCase().contains(query) ||
                      r.bloodGroup.toLowerCase().contains(query) ||
                      r.hospitalName.toLowerCase().contains(query);
                }).toList();
              }

              final visibleRequests = requests.take(_visibleCount).toList();
              final hasMore = requests.length > visibleRequests.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HistorySummaryBar(requests: requests),
                  Expanded(
                    child: requests.isEmpty
                        ? const EmptyState(icon: Icons.folder_off_outlined, title: 'No matching requests', message: 'Try adjusting your search or filters.')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: visibleRequests.length + (hasMore ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == visibleRequests.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      onPressed: () => setState(() => _visibleCount += _pageSize),
                                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                                      label: Text('Load more (${requests.length - visibleRequests.length} remaining)'),
                                    ),
                                  ),
                                );
                              }
                              return EntranceFadeSlide(
                                delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                                child: _HistoryRequestCard(request: visibleRequests[index]),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) => '${d.day}/${d.month}';

  static String _sortLabel(_HistorySortMode mode) {
    switch (mode) {
      case _HistorySortMode.newest:
        return 'Newest';
      case _HistorySortMode.oldest:
        return 'Oldest';
      case _HistorySortMode.bloodGroup:
        return 'Blood Group';
      case _HistorySortMode.patientName:
        return 'Name';
    }
  }

  // Fixed presets always offered, independent of what the doctor has
  // personally saved - the exact examples from the module spec.
  static final List<_SavedFilter> _quickPresets = [
    _SavedFilter(name: 'O- Requests', bloodGroup: 'O-', icon: Icons.bloodtype_outlined),
    _SavedFilter(name: 'Critical Only', priority: UrgencyLevel.critical, icon: Icons.emergency_outlined),
    _SavedFilter(name: 'Fulfilled', status: RequestStatus.fulfilled, icon: Icons.check_circle_outline_rounded),
    _SavedFilter(name: 'Rejected', status: RequestStatus.rejected, icon: Icons.cancel_outlined),
  ];
}

/// A saved (or quick-preset) filter combo for the History tab -
/// status/priority/blood-group only (date range is deliberately left
/// out of saved filters since "last 30 days" would go stale silently).
class _SavedFilter {
  final String name;
  final String? status;
  final String? priority;
  final String? bloodGroup;
  final IconData icon;
  _SavedFilter({required this.name, this.status, this.priority, this.bloodGroup, this.icon = Icons.bookmark_rounded});

  Map<String, dynamic> toJson() => {'name': name, 'status': status, 'priority': priority, 'bloodGroup': bloodGroup};
  factory _SavedFilter.fromJson(Map<String, dynamic> json) => _SavedFilter(
        name: json['name'] as String? ?? 'Filter',
        status: json['status'] as String?,
        priority: json['priority'] as String?,
        bloodGroup: json['bloodGroup'] as String?,
      );
}

/// Compact, deterministic (non-AI) analytics for the currently filtered
/// history list, plus a PDF export of exactly what's on screen.
class _HistorySummaryBar extends StatelessWidget {
  final List<BloodRequest> requests;
  const _HistorySummaryBar({required this.requests});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (requests.isEmpty) return const SizedBox.shrink();

    final fulfilled = requests.where((r) => r.status == RequestStatus.fulfilled).length;
    final rejected = requests.where((r) => r.status == RequestStatus.rejected).length;
    final expired = requests.where((r) => r.status == RequestStatus.expired).length;
    final fulfilmentRate = requests.isEmpty ? 0 : ((fulfilled / requests.length) * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _SummaryStat(label: 'Total', value: '${requests.length}', color: colors.textPrimary),
                _SummaryStat(label: 'Fulfilled', value: '$fulfilled', color: colors.success),
                _SummaryStat(label: 'Rejected', value: '$rejected', color: colors.critical),
                _SummaryStat(label: 'Expired', value: '$expired', color: colors.warning),
                _SummaryStat(label: 'Fulfilment rate', value: '$fulfilmentRate%', color: colors.primary),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Export CSV (current filters)',
            icon: Icon(Icons.table_chart_outlined, color: colors.primary),
            onPressed: () => exportRequestsAsCsv(context: context, requests: requests),
          ),
          IconButton(
            tooltip: 'Export PDF (current filters)',
            icon: Icon(Icons.picture_as_pdf_outlined, color: colors.primary),
            onPressed: () => generateHistorySummaryReport(context: context, requests: requests),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
      ],
    );
  }
}

class _HistoryRequestCard extends StatelessWidget {
  final BloodRequest request;
  const _HistoryRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = RequestStatus.color(request.status);
    return PressableScale(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: request.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(RequestStatus.icon(request.status), size: 18, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.patientName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${request.bloodGroup} · ${request.unitsNeeded} unit(s) · ${request.hospitalName}',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  Text(RequestStatus.label(request.status), style: TextStyle(fontSize: 11, color: statusColor)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                Text('View', style: TextStyle(fontSize: 9.5, color: colors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: selected ? colors.primary : colors.textSecondary),
      backgroundColor: colors.elevatedSurface,
      side: BorderSide(color: selected ? colors.primary : colors.border),
    );
  }
}
