import 'package:flutter/material.dart';

/// Lightweight, dependency-free entrance animation: fades in while
/// sliding up a few pixels. Used to stagger the Doctor dashboard's
/// sections/cards on first appearance without a gaming-UI feel.
///
/// Built on [TweenAnimationBuilder] rather than a manual
/// [AnimationController], so there is nothing to dispose and no risk
/// of leaking a controller.
class EntranceFadeSlide extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const EntranceFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  Widget build(BuildContext context) {
    // Respect the platform's reduced-motion accessibility setting -
    // show content immediately instead of animating it in.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }

    final totalMs = duration.inMilliseconds + delay.inMilliseconds;
    final delayFraction = totalMs == 0 ? 0.0 : delay.inMilliseconds / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, childWidget) {
        final adjusted = t <= delayFraction ? 0.0 : ((t - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        return Opacity(
          opacity: adjusted,
          child: Transform.translate(offset: Offset(0, (1 - adjusted) * 14), child: childWidget),
        );
      },
      child: child,
    );
  }
}
