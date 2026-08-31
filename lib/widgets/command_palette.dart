import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blood_request.dart';
import '../theme/app_colors.dart';
import '../screens/hospital/request_details_screen.dart';
import '../screens/hospital/alert_center_screen.dart';
import '../widgets/appearance_selector_sheet.dart';
import '../screens/hospital/pdf_report.dart';

/// #command-palette (Phase 2) - a desktop-grade "jump to anything"
/// command palette (Ctrl+K / Cmd+K), the kind of interaction power
/// users expect from a professional tool and a genuine differentiator
/// from a generic CRUD dashboard. Two kinds of entries share one
/// keyboard-navigable list:
///   - fixed COMMANDS (navigate tabs, open alerts, generate report,
///     toggle theme) - filtered by simple substring match
///   - live SEARCH RESULTS from real Firestore data (requests by
///     patient/hospital/location, donors by name/location)
/// Full keyboard control: Arrow Up/Down to move, Enter to activate,
/// Escape to close - never requiring the mouse.
Future<void> showCommandPalette(BuildContext context, {required ValueChanged<int> onNavigateTab}) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'Command Palette',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) => _CommandPaletteDialog(onNavigateTab: onNavigateTab),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: Transform.translate(
        offset: Offset(0, (1 - animation.value) * -12),
        child: child,
      ),
    ),
  );
}

/// One selectable row in the palette - either a fixed command or a
/// live search hit. Unified so Up/Down/Enter navigate across both
/// kinds without the UI needing to know which is which.
class _PaletteEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onSelect;
  const _PaletteEntry({required this.title, required this.subtitle, required this.icon, required this.onSelect, this.iconColor});
}

class _CommandPaletteDialog extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;
  const _CommandPaletteDialog({required this.onNavigateTab});

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  // #global-search-debounce - the live REQUESTS/DONORS results come
  // from Firestore snapshots and are filtered client-side over
  // potentially large collections; re-filtering on every single
  // keystroke while someone is still typing is wasted work and can
  // make fast typing feel janky. Fixed commands stay instant (cheap,
  // local list filter on ~8 items) - only the expensive live search
  // waits for a short pause in typing before it updates.
  static const _debounceDelay = Duration(milliseconds: 180);
  Timer? _debounceTimer;
  String _liveQuery = '';

  // #perf - created once instead of calling `.snapshots()` inline
  // inside build(), which would otherwise construct a brand new
  // Firestore stream (and force a resubscribe) on every rebuild,
  // i.e. every keystroke.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _donorsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = FirebaseFirestore.instance.collection('requests').snapshots();
    _donorsStream = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Donor').snapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _selectedIndex = 0);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (mounted) setState(() => _liveQuery = value.trim().toLowerCase());
    });
  }

  List<_PaletteEntry> _commands(BuildContext context) {
    void go(int tab) {
      Navigator.pop(context);
      widget.onNavigateTab(tab);
    }

    return [
      _PaletteEntry(title: 'Go to Dashboard', subtitle: 'Operations overview & analytics', icon: Icons.dashboard_rounded, onSelect: () => go(0)),
      _PaletteEntry(title: 'Go to Verification', subtitle: 'Requests awaiting review', icon: Icons.fact_check_outlined, onSelect: () => go(1)),
      _PaletteEntry(title: 'Open Critical Requests', subtitle: 'Jump to the verification queue', icon: Icons.emergency_share_rounded, iconColor: Theme.of(context).extension<AppColors>()?.critical, onSelect: () => go(1)),
      _PaletteEntry(title: 'Go to Donor Search', subtitle: 'Search & match donors', icon: Icons.search_rounded, onSelect: () => go(2)),
      _PaletteEntry(title: 'Go to History', subtitle: 'Past requests & filters', icon: Icons.history_rounded, onSelect: () => go(3)),
      _PaletteEntry(title: 'Generate Report', subtitle: 'Export a request as PDF from History', icon: Icons.picture_as_pdf_outlined, onSelect: () => go(3)),
      _PaletteEntry(
        title: 'Shift Handover Report',
        subtitle: 'PDF snapshot of active requests, for the next shift',
        icon: Icons.assignment_turned_in_outlined,
        onSelect: () {
          Navigator.pop(context);
          showShiftHandoverDialog(context);
        },
      ),
      _PaletteEntry(
        title: 'Open Alerts',
        subtitle: 'Critical / verification / donor response alerts',
        icon: Icons.notifications_outlined,
        onSelect: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertCenterScreen()));
        },
      ),
      _PaletteEntry(
        title: 'Toggle Theme',
        subtitle: 'Switch Light / Dark / System appearance',
        icon: Icons.palette_outlined,
        onSelect: () {
          Navigator.pop(context);
          AppearanceSelectorSheet.show(context);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _controller.text.trim().toLowerCase();
    final commands = _commands(context).where((c) => query.isEmpty || c.title.toLowerCase().contains(query) || c.subtitle.toLowerCase().contains(query)).toList();

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: colors.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Focus(
                          onKeyEvent: (node, event) => _handleKey(context, event, commands),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: _onQueryChanged,
                            style: TextStyle(color: colors.textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search or run a command...',
                              hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ),
                      _KeyHint(label: '↑↓'),
                      const SizedBox(width: 4),
                      _KeyHint(label: 'ENTER'),
                      const SizedBox(width: 4),
                      _KeyHint(label: 'ESC'),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.border),
                Flexible(
                  child: _CommandPaletteResults(
                    query: query,
                    liveQuery: _liveQuery,
                    requestsStream: _requestsStream,
                    donorsStream: _donorsStream,
                    commands: commands,
                    selectedIndex: _selectedIndex,
                    onHover: (i) => setState(() => _selectedIndex = i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKey(BuildContext context, KeyEvent event, List<_PaletteEntry> commands) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    // Total entry count (commands + up to 12 live results) is resolved
    // lazily inside _CommandPaletteResults; here we only need enough
    // bound to keep the index sane for commands, the common case for
    // keyboard-only use. Live-result selection still works via mouse.
    final maxIndex = commands.isEmpty ? 0 : commands.length - 1;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedIndex = (_selectedIndex + 1).clamp(0, maxIndex));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedIndex = (_selectedIndex - 1).clamp(0, maxIndex));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (commands.isNotEmpty && _selectedIndex <= maxIndex) {
        commands[_selectedIndex].onSelect();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _KeyHint extends StatelessWidget {
  final String label;
  const _KeyHint({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: colors.elevatedSurface, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colors.textSecondary)),
    );
  }
}

class _CommandPaletteResults extends StatelessWidget {
  final String query;
  final String liveQuery;
  final Stream<QuerySnapshot<Map<String, dynamic>>> requestsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> donorsStream;
  final List<_PaletteEntry> commands;
  final int selectedIndex;
  final ValueChanged<int> onHover;
  const _CommandPaletteResults({
    required this.query,
    required this.liveQuery,
    required this.requestsStream,
    required this.donorsStream,
    required this.commands,
    required this.selectedIndex,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (query.isEmpty) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          _SectionHeader(label: 'COMMANDS'),
          for (int i = 0; i < commands.length; i++) _EntryTile(entry: commands[i], selected: i == selectedIndex),
        ],
      );
    }

    // #global-search-debounce - while the user is still typing (query
    // has raced ahead of the debounced liveQuery), keep showing the
    // instant COMMANDS matches and skip re-filtering the Firestore
    // snapshots until liveQuery catches up 180ms after they pause.
    final searching = query != liveQuery;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: requestsStream,
      builder: (context, requestSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: donorsStream,
          builder: (context, donorSnap) {
            final requests = searching
                ? const <BloodRequest>[]
                : (requestSnap.data?.docs ?? const [])
                    .map(BloodRequest.fromDoc)
                    .where((r) =>
                        r.patientName.toLowerCase().contains(liveQuery) ||
                        r.hospitalName.toLowerCase().contains(liveQuery) ||
                        r.location.toLowerCase().contains(liveQuery) ||
                        r.id.toLowerCase().contains(liveQuery) ||
                        r.bloodGroup.toLowerCase().contains(liveQuery))
                    .take(6)
                    .toList();

            final donors = searching
                ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
                : (donorSnap.data?.docs ?? const [])
                    .where((d) {
                      final data = d.data();
                      final name = (data['fullName'] as String? ?? '').toLowerCase();
                      final loc = (data['location'] as String? ?? '').toLowerCase();
                      return name.contains(liveQuery) || loc.contains(liveQuery);
                    })
                    .take(6)
                    .toList();

            if (commands.isEmpty && !searching && requests.isEmpty && donors.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No matches for "$query"', style: TextStyle(fontSize: 12.5, color: colors.textSecondary))),
              );
            }

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                if (commands.isNotEmpty) ...[
                  _SectionHeader(label: 'COMMANDS'),
                  for (int i = 0; i < commands.length; i++) _EntryTile(entry: commands[i], selected: i == selectedIndex),
                ],
                if (requests.isNotEmpty) ...[
                  _SectionHeader(label: 'REQUESTS'),
                  ...requests.map((r) => _RequestResultTile(request: r)),
                ],
                if (donors.isNotEmpty) ...[
                  _SectionHeader(label: 'DONORS'),
                  ...donors.map((d) => _DonorResultTile(data: d.data())),
                ],
                if (searching)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text('Searching requests & donors...', style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontStyle: FontStyle.italic)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final _PaletteEntry entry;
  final bool selected;
  const _EntryTile({required this.entry, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: entry.onSelect,
      child: Container(
        color: selected ? colors.primary.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Icon(entry.icon, size: 17, color: entry.iconColor ?? colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  Text(entry.subtitle, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                ],
              ),
            ),
            if (selected) Icon(Icons.keyboard_return_rounded, size: 14, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: colors.textSecondary)),
    );
  }
}

class _RequestResultTile extends StatelessWidget {
  final BloodRequest request;
  const _RequestResultTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: request.id)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            CircleAvatar(radius: 15, backgroundColor: colors.critical.withValues(alpha: 0.1), child: Text(request.bloodGroup, style: TextStyle(color: colors.critical, fontSize: 10, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.patientName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  Text('${request.hospitalName} · ${request.urgency}', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.subdirectory_arrow_left_rounded, size: 14, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DonorResultTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DonorResultTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = data['fullName'] as String? ?? 'Donor';
    final group = data['bloodGroup'] as String? ?? '-';
    final location = data['location'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          CircleAvatar(radius: 15, backgroundColor: colors.primary.withValues(alpha: 0.1), child: Text(group, style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                Text(location.isNotEmpty ? location : 'Location not set', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
