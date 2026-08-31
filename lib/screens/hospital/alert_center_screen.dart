import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/request_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_states.dart';
import '../../widgets/entrance_fade_slide.dart';
import '../../widgets/live_pulse_dot.dart';
import '../../widgets/skeleton_loader.dart';
import 'request_details_screen.dart';

/// #8/#23 - Smart Alert Center. Firestore-backed in-app notifications
/// (no Firebase Cloud Messaging is configured in this project, so a
/// realtime Firestore listener is used instead, per the module spec).
///
/// Categories shown are only the ones actually produced by
/// [RequestService] (critical requests, new requests awaiting
/// verification, donor responses) - no invented category is shown
/// that nothing in this app ever creates.
class AlertCenterScreen extends StatefulWidget {
  const AlertCenterScreen({super.key});

  @override
  State<AlertCenterScreen> createState() => _AlertCenterScreenState();
}

enum _AlertCategory { all, critical, newRequest, donorResponse }

class _AlertCenterScreenState extends State<AlertCenterScreen> {
  _AlertCategory _category = _AlertCategory.all;

  static _AlertCategory _categoryFor(String type) {
    switch (type) {
      case 'critical_request':
        return _AlertCategory.critical;
      case 'pending_verification':
        return _AlertCategory.newRequest;
      case 'donor_accepted':
      case 'donor_declined':
        return _AlertCategory.donorResponse;
      default:
        return _AlertCategory.all;
    }
  }

  static String _categoryLabel(_AlertCategory c) {
    switch (c) {
      case _AlertCategory.all:
        return 'All';
      case _AlertCategory.critical:
        return 'Critical';
      case _AlertCategory.newRequest:
        return 'New Request';
      case _AlertCategory.donorResponse:
        return 'Donor Response';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Alert Center'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: RequestService.instance.alertsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorStateView(message: 'Unable to load alerts right now.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const ListCardSkeleton();
          }
          var docs = snapshot.data!.docs;

          final unreadIds = docs
              .where((d) => !((d.data()['readBy'] as List?)?.map((e) => e.toString()).toList() ?? []).contains(uid))
              .map((d) => d.id)
              .toList();

          if (_category != _AlertCategory.all) {
            docs = docs.where((d) => _categoryFor(d.data()['type'] as String? ?? '') == _category).toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    if (unreadIds.isNotEmpty) ...[
                      LivePulseDot(color: colors.critical),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        unreadIds.isEmpty ? 'You\'re all caught up' : '${unreadIds.length} unread alert(s)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ),
                    if (unreadIds.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => RequestService.instance.markAllAlertsRead(unreadIds, uid),
                        icon: Icon(Icons.done_all_rounded, size: 16, color: colors.primary),
                        label: Text('Mark all read', style: TextStyle(color: colors.primary, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _AlertCategory.values
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoryChip(label: _categoryLabel(c), selected: _category == c, onTap: () => setState(() => _category = c)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: docs.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No alerts',
                        message: 'You\'re all caught up.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final readBy = (data['readBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
                          final isRead = readBy.contains(uid);
                          final type = data['type'] as String? ?? '';
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                          // #new - swipe-to-mark-read. confirmDismiss
                          // always returns false so the tile springs
                          // back instead of disappearing (alerts are
                          // never deleted, only marked read) - the
                          // swipe gesture itself is the "mark read"
                          // action, revealed via the background icon.
                          return EntranceFadeSlide(
                            delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                            child: Dismissible(
                              key: ValueKey(doc.id),
                              direction: isRead ? DismissDirection.none : DismissDirection.startToEnd,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(color: colors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.done_rounded, color: colors.success, size: 18),
                                    const SizedBox(width: 6),
                                    Text('Mark read', style: TextStyle(color: colors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) async {
                                RequestService.instance.markAlertRead(doc.id, uid);
                                return false;
                              },
                              child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                if (!isRead) RequestService.instance.markAlertRead(doc.id, uid);
                                final requestId = data['requestId'] as String?;
                                if (requestId != null) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: requestId)));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isRead ? colors.surface : _colorFor(colors, type).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isRead ? colors.border : _colorFor(colors, type).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: _colorFor(colors, type).withValues(alpha: 0.12), shape: BoxShape.circle),
                                      child: Icon(_iconFor(type), color: _colorFor(colors, type), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['message'] as String? ?? '',
                                            style: TextStyle(fontSize: 13, fontWeight: isRead ? FontWeight.normal : FontWeight.w600, color: colors.textPrimary),
                                          ),
                                          if (createdAt != null) ...[
                                            const SizedBox(height: 4),
                                            Text(_relativeTime(createdAt), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'critical_request':
        return Icons.priority_high_rounded;
      case 'pending_verification':
        return Icons.fact_check_outlined;
      case 'donor_accepted':
        return Icons.check_circle_outline_rounded;
      case 'donor_declined':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _colorFor(AppColors colors, String type) {
    switch (type) {
      case 'critical_request':
        return colors.critical;
      case 'donor_accepted':
        return colors.success;
      case 'donor_declined':
        return colors.textSecondary;
      default:
        return colors.primary;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

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

/// Bell icon with an unread-count badge, meant for the dashboard AppBar.
///
/// #new - when there is at least one unread alert, the bell gives a
/// gentle periodic "ring" (a small rotation wiggle) so a new
/// notification is noticeable without being distracting. Respects
/// the OS/accessibility reduced-motion setting.
class AlertBellIcon extends StatefulWidget {
  const AlertBellIcon({super.key});

  @override
  State<AlertBellIcon> createState() => _AlertBellIconState();
}

class _AlertBellIconState extends State<AlertBellIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.instance.alertsStream(),
      builder: (context, snapshot) {
        final unread = (snapshot.data?.docs ?? []).where((doc) {
          final readBy = (doc.data()['readBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
          return !readBy.contains(uid);
        }).length;

        Widget bell = Icon(unread > 0 ? Icons.notifications_active_outlined : Icons.notifications_outlined, color: colors.textPrimary);

        if (unread > 0 && !reduceMotion) {
          bell = AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // A short wiggle near the start of each ~2.6s cycle, then
              // stays still - reads as an occasional "ring", not a
              // constant distracting jitter.
              final t = _controller.value;
              double angle = 0;
              if (t < 0.15) {
                angle = 0.28 * (t / 0.15 < 0.5 ? (t / 0.15) * 2 : 2 - (t / 0.15) * 2) - 0.14;
              }
              return Transform.rotate(angle: angle, child: child);
            },
            child: bell,
          );
        }

        final icon = IconButton(
          tooltip: 'Alerts',
          icon: bell,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertCenterScreen())),
        );

        if (unread == 0) return icon;

        return Badge(
          label: Text('$unread'),
          backgroundColor: colors.critical,
          textColor: Colors.white,
          child: icon,
        );
      },
    );
  }
}
