import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/app_colors.dart';

/// Polished Light / Dark / System appearance picker, shown as a modal
/// bottom sheet. Reusable from any Doctor screen's profile/settings
/// entry point; changing the selection updates [ThemeController]
/// immediately (and persists it), so every screen in the app - not
/// just the Doctor module - repaints with the new theme.
class AppearanceSelectorSheet extends StatelessWidget {
  const AppearanceSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => const AppearanceSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final current = ThemeController.instance.mode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how the app looks on this device.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _AppearanceOption(
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  selected: current == ThemeMode.light,
                  onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                ),
                const SizedBox(height: 10),
                _AppearanceOption(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  selected: current == ThemeMode.dark,
                  onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                ),
                const SizedBox(height: 10),
                _AppearanceOption(
                  icon: Icons.desktop_windows_rounded,
                  label: 'System',
                  subtitle: 'Follows your device setting',
                  selected: current == ThemeMode.system,
                  onTap: () => ThemeController.instance.setMode(ThemeMode.system),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.12) : colors.elevatedSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? colors.primary : colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
