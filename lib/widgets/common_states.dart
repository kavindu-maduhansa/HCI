import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable Loading / Empty / Error state widgets (#18/#36/#37) so
/// every Doctor screen behaves consistently, a raw Firebase exception
/// is never shown directly to the user in place of these, and every
/// state responds to the active Light/Dark/System theme.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// #37 - Premium empty state: icon + bold title + a short, specific
/// reassurance line, never just a bare "no data" message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyState({super.key, this.icon = Icons.inbox_rounded, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors.elevatedSurface, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// #35 - A friendly, non-technical-looking error view with a Retry
/// action and connection status framing. Real Firebase error detail
/// can still be appended by the caller (for developer/debugging
/// visibility) but the icon/framing always reads as recoverable, not
/// as a crash.
class ErrorStateView extends StatelessWidget {
  final VoidCallback? onRetry;
  final String message;
  const ErrorStateView({
    super.key,
    this.onRetry,
    this.message = 'Unable to load data.\nCheck your connection or permissions.',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, size: 30, color: colors.warning),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(foregroundColor: colors.primary, side: BorderSide(color: colors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small helper to show a brief, friendly success snackbar consistently.
void showSuccessSnack(BuildContext context, String message) {
  final colors = context.colors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: colors.success, behavior: SnackBarBehavior.floating),
  );
}

void showErrorSnack(BuildContext context, String message) {
  final colors = context.colors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: colors.critical, behavior: SnackBarBehavior.floating),
  );
}
