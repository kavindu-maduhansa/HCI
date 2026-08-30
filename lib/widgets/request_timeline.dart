import 'package:flutter/material.dart';

import '../models/blood_request.dart';
import '../theme/app_colors.dart';
import '../utils/request_status.dart';

class _Step {
  final String label;
  final DateTime? timestamp;
  final bool reached;
  const _Step(this.label, this.timestamp, this.reached);
}

/// #5 - Visual request timeline. Built entirely from real Firestore
/// timestamps already on the request (`createdAt`, `verifiedAt`,
/// `updatedAt`) and its `responses` subcollection
/// (`notifiedAt`/`respondedAt`). A step with no timestamp yet is
/// rendered as "not reached" instead of inventing a time.
///
/// #theme-fix - this widget previously hard-coded a bright red and a
/// set of light-mode-only greys instead of reading `context.colors`,
/// so in Dark mode its step labels rendered near-invisible (dark grey
/// text on a dark background) - the same class of bug as the earlier
/// login-screen issue. Now fully theme-aware, and each step reveals
/// with a small staggered entrance animation.
class RequestTimeline extends StatelessWidget {
  final BloodRequest request;
  final List<DonorResponseRecord> responses;

  const RequestTimeline({super.key, required this.request, required this.responses});

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 280 + i * 70),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(offset: Offset((1 - value) * 12, 0), child: child),
            ),
            child: _StepRow(step: steps[i], isLast: i == steps.length - 1),
          ),
      ],
    );
  }

  List<_Step> _buildSteps() {
    if (request.status == RequestStatus.rejected) {
      return [
        _Step('Request Received', request.createdAt, true),
        _Step('Under Verification', request.createdAt, true),
        _Step('Rejected', request.verifiedAt, true),
      ];
    }

    DateTime? firstNotifiedAt;
    DateTime? firstRespondedAt;
    DateTime? firstConfirmedAt;
    for (final r in responses) {
      if (r.notifiedAt != null && (firstNotifiedAt == null || r.notifiedAt!.isBefore(firstNotifiedAt))) {
        firstNotifiedAt = r.notifiedAt;
      }
      if (r.respondedAt != null && (firstRespondedAt == null || r.respondedAt!.isBefore(firstRespondedAt))) {
        firstRespondedAt = r.respondedAt;
      }
      if ((r.status == 'accepted' || r.status == 'completed') &&
          r.respondedAt != null &&
          (firstConfirmedAt == null || r.respondedAt!.isBefore(firstConfirmedAt))) {
        firstConfirmedAt = r.respondedAt;
      }
    }

    final isVerified = [RequestStatus.verified, RequestStatus.matched, RequestStatus.fulfilled].contains(request.status);
    final isFulfilled = request.status == RequestStatus.fulfilled;

    return [
      _Step('Request Received', request.createdAt, request.createdAt != null),
      _Step('Under Verification', request.createdAt, request.createdAt != null),
      _Step('Verified', request.verifiedAt, isVerified),
      _Step('Donors Matched & Notified', firstNotifiedAt, firstNotifiedAt != null),
      _Step('Responses Received', firstRespondedAt, firstRespondedAt != null),
      _Step('Donor Confirmed', firstConfirmedAt, firstConfirmedAt != null),
      _Step('Fulfilled', isFulfilled ? request.updatedAt : null, isFulfilled),
    ];
  }
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final bool isLast;
  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = step.reached ? colors.primary : colors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.reached ? color : colors.surface,
                  border: Border.all(color: color, width: 2),
                ),
                child: step.reached
                    ? const Icon(Icons.check, size: 9, color: Colors.white)
                    : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: step.reached ? FontWeight.bold : FontWeight.w500,
                      color: step.reached ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                  if (step.reached && step.timestamp != null)
                    Text(_formatTimestamp(step.timestamp!), style: TextStyle(fontSize: 11, color: colors.textSecondary))
                  else if (!step.reached)
                    Text('Not reached yet', style: TextStyle(fontSize: 11, color: colors.textSecondary.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
