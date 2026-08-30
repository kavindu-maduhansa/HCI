import 'package:flutter/material.dart';

/// Animates an integer KPI value counting up from 0 on first build -
/// used for the dashboard's stat chips (Pending, Critical, etc). Built
/// on [TweenAnimationBuilder], so it manages its own lifecycle and
/// needs no manual AnimationController/dispose.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$v', style: style),
    );
  }
}
