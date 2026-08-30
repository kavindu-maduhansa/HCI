import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// #36 - Professional skeleton loading. A single rounded block that
/// gently shimmers between the elevated-surface and border tones,
/// used to build up skeleton layouts (dashboard, lists, cards)
/// instead of a blank space or a single spinner filling the screen.
/// Respects reduced-motion: renders as a static block when the
/// platform/user has disabled animations.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  const SkeletonBox({super.key, required this.height, this.width, this.borderRadius = const BorderRadius.all(Radius.circular(8))});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reducedMotion) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: colors.elevatedSurface, borderRadius: widget.borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(colors.elevatedSurface, colors.border, t),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// A skeleton layout shaped like the Dashboard's above-the-fold
/// content, shown while the first Firestore snapshot is still
/// loading - avoids a blank page or a single centred spinner on the
/// most-visited screen.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SkeletonBox(height: 84, borderRadius: BorderRadius.all(Radius.circular(18))),
        const SizedBox(height: 16),
        SizedBox(
          height: 84,
          child: Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 10),
                  child: const SkeletonBox(height: 84, borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SkeletonBox(height: 22, width: 220),
        const SizedBox(height: 10),
        const SkeletonBox(height: 76, borderRadius: BorderRadius.all(Radius.circular(16))),
        const SizedBox(height: 10),
        const SkeletonBox(height: 76, borderRadius: BorderRadius.all(Radius.circular(16))),
        const SizedBox(height: 10),
        const SkeletonBox(height: 76, borderRadius: BorderRadius.all(Radius.circular(16))),
      ],
    );
  }
}

/// A skeleton layout shaped like a list of request/donor cards - used
/// on Verify Requests, History, and Donor Search while their first
/// snapshot is loading.
class ListCardSkeleton extends StatelessWidget {
  final int count;
  const ListCardSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => const SkeletonBox(height: 92, borderRadius: BorderRadius.all(Radius.circular(16))),
    );
  }
}
