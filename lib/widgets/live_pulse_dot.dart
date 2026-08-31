import 'package:flutter/material.dart';

/// Small "● LIVE" indicator with a gentle, subtle pulse - used only on
/// critical/active cards. Intentionally slow and low-amplitude so it
/// reads as "live" rather than flashing or distracting.
class LivePulseDot extends StatefulWidget {
  final Color color;
  const LivePulseDot({super.key, required this.color});

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.color, letterSpacing: 0.5)),
        ],
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.45 + (_controller.value * 0.55);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: opacity), shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.color, letterSpacing: 0.5)),
          ],
        );
      },
    );
  }
}
