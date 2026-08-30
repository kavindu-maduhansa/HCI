import 'package:flutter/material.dart';

import '../models/blood_request.dart';
import '../theme/app_colors.dart';
import '../utils/request_status.dart';

/// #5/#27 - Combined Operational Status chip ("ON TRACK" / "NEEDS
/// ATTENTION" / "IMMEDIATE ATTENTION") + live waiting-time label for a
/// request. Purely derived from `request.createdAt` / unit counters -
/// nothing hard-coded, no medical claim. Status is never communicated
/// by color alone: every chip pairs an icon, a label, and a color.
class RequestHealthBadge extends StatelessWidget {
  final BloodRequest request;
  final bool showWaitingTime;

  const RequestHealthBadge({super.key, required this.request, this.showWaitingTime = true});

  static IconData _iconFor(String level) {
    switch (level) {
      case RequestHealth.needsAttention:
        return Icons.watch_later_outlined;
      case RequestHealth.criticalAttention:
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final level = RequestHealth.computeLevel(
      status: request.status,
      urgency: request.urgency,
      createdAt: request.createdAt,
      unitsNeeded: request.unitsNeeded,
      unitsConfirmed: request.unitsConfirmed,
    );
    final color = RequestHealth.color(level);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // #9 - tappable so the level is never just a color: it always
        // explains itself in plain language ("WHY"), clearly labelled
        // as an operational SLA indicator, never a medical claim.
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showWhy(context, colors, level, color),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor(level), size: 11, color: color),
                const SizedBox(width: 3),
                Text(RequestHealth.label(level), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 2),
                Icon(Icons.info_outline_rounded, size: 10, color: color.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
        if (showWaitingTime && request.createdAt != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: colors.textSecondary),
              const SizedBox(width: 3),
              Text('Waiting: ${WaitingTime.format(request.createdAt)}', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            ],
          ),
      ],
    );
  }

  void _showWhy(BuildContext context, AppColors colors, String level, Color color) {
    final reasons = RequestHealth.reasons(
      status: request.status,
      urgency: request.urgency,
      createdAt: request.createdAt,
      unitsNeeded: request.unitsNeeded,
      unitsConfirmed: request.unitsConfirmed,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Icon(_iconFor(level), color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(RequestHealth.label(level), style: TextStyle(color: colors.textPrimary, fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 5, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r, style: TextStyle(fontSize: 13, color: colors.textPrimary))),
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
                        'Operational indicator only, based on waiting time and unit coverage. Not a medical prediction or diagnosis.',
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
