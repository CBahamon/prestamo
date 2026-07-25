import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hundido de arcilla + onda que se expande desde donde tocaste.
///
/// Las animaciones son finitas a propósito: nada queda repitiéndose en
/// segundo plano (gasta batería y deja los tests sin poder asentarse).
class ClayPressable extends StatefulWidget {
  const ClayPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 28,
    this.pressedScale = 0.97,
    this.waveColor,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double pressedScale;
  final Color? waveColor;
  final bool enabled;

  @override
  State<ClayPressable> createState() => _ClayPressableState();
}

class _ClayPressableState extends State<ClayPressable>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    reverseDuration: const Duration(milliseconds: 220),
  );

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  Offset? _waveOrigin;

  @override
  void dispose() {
    _press.dispose();
    _wave.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && widget.onTap != null;

  void _onTapDown(TapDownDetails d) {
    if (!_active) return;
    setState(() => _waveOrigin = d.localPosition);
    _press.forward();
    _wave.forward(from: 0);
  }

  void _release() {
    if (!_active) return;
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: _active ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, _wave]),
        builder: (context, child) {
          final t = Curves.easeOut.transform(_press.value);
          return Transform.scale(
            scale: 1 - (1 - widget.pressedScale) * t,
            child: ClipRRect(
              borderRadius: radius,
              child: CustomPaint(
                foregroundPainter: _waveOrigin == null || _wave.isDismissed
                    ? null
                    : _WavePainter(
                        origin: _waveOrigin!,
                        progress: _wave.value,
                        color: widget.waveColor ?? Colors.white,
                      ),
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Dos anillos concéntricos que se abren y se desvanecen: la "onda".
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.origin,
    required this.progress,
    required this.color,
  });

  final Offset origin;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = size.longestSide * 1.1;

    for (var i = 0; i < 2; i++) {
      // El segundo anillo va retrasado para que se vea el oleaje.
      final t = (progress - i * 0.22).clamp(0.0, 1.0);
      if (t == 0 || t == 1) continue;

      final eased = Curves.easeOutCubic.transform(t);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * (1 - eased) + 2
        ..color = color.withValues(alpha: 0.30 * (1 - eased));

      canvas.drawCircle(origin, maxRadius * eased, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.origin != origin;
}

/// Entrada de las tarjetas: aparecen subiendo, una detrás de otra.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 24,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Borde inferior en forma de ola para el encabezado morado.
class WaveBottomClipper extends CustomClipper<Path> {
  const WaveBottomClipper({this.amplitude = 14, this.phase = 0});

  final double amplitude;
  final double phase;

  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - amplitude * 2);

    // Dos crestas de seno recorriendo el ancho.
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y =
          size.height -
          amplitude * 2 +
          amplitude * math.sin((i / steps) * 2 * math.pi + phase);
      path.lineTo(x, y);
    }

    path
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(WaveBottomClipper old) =>
      old.amplitude != amplitude || old.phase != phase;
}

/// La ola del encabezado se "acomoda" al entrar y se queda quieta.
class WaveEdge extends StatelessWidget {
  const WaveEdge({super.key, required this.child, this.amplitude = 14});

  final Widget child;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => ClipPath(
        clipper: WaveBottomClipper(
          amplitude: amplitude * t,
          phase: (1 - t) * math.pi,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
