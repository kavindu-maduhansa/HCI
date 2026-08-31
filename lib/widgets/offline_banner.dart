import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';

/// #offline-banner - app-wide, non-dismissible strip that appears the
/// instant device connectivity drops and disappears the instant it's
/// back. Backed by [ConnectivityService] (real `connectivity_plus`
/// events, not a fabricated state) so staff always know whether an
/// action they just took (verify, notify donors, update a response)
/// will reach Firestore immediately or only once the connection
/// returns - Firestore's own offline persistence queues writes
/// locally either way, so nothing is lost, but staff should still see
/// the difference between "done" and "queued".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.isOffline,
      initialData: false,
      builder: (context, snapshot) {
        final offline = snapshot.data ?? false;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: !offline
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: colors.warning.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 15, color: colors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You're offline - changes will save locally and sync automatically once you're back online.",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.warning),
                          overflow: TextOverflow.ellipsis,
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
