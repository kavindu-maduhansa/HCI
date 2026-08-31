import 'package:flutter/material.dart';

/// A small "press to shrink" micro-interaction wrapper - used on
/// tappable cards across the Doctor module (pending requests, donor
/// results, history entries) so the whole app feels consistently
/// premium/responsive to touch, not just its buttons. Purely visual;
/// [onTap] fires exactly like a normal `InkWell.onTap` would.
///
/// Respects the reduced-motion accessibility setting - the scale
/// animation is skipped entirely when the OS/user has motion
/// reduction enabled, but the tap and ripple still work.
///
/// #cursor-hover - on desktop/web, a card also needs to *feel*
/// clickable before the user ever taps it: a pointer cursor on hover,
/// a gentle lift (scale + shadow), and a subtle border-color shift.
/// Wrapped in [MouseRegion] so this happens automatically for every
/// card that already uses [PressableScale] (Verify, Donor Search,
/// History) without touching each screen individually.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const PressableScale({super.key, required this.child, this.onTap, this.borderRadius});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    double scale = 1.0;
    if (!reduceMotion) {
      if (_pressed) {
        scale = 0.97;
      } else if (_hovered && widget.onTap != null) {
        scale = 1.012;
      }
    }

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: (!reduceMotion && _hovered && widget.onTap != null)
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
