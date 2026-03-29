import 'dart:math';

import 'package:flutter/material.dart';

import '../models/badge.dart';

// ---------------------------------------------------------------------------
// BadgeWidget — renders a single badge with shape, gradient, and emoji.
// ---------------------------------------------------------------------------
class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    super.key,
    required this.def,
    this.size = 56,
    this.locked = false,
  });

  final BadgeDef def;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BadgePainter(def: def, locked: locked),
        child: Center(
          child: Text(
            locked ? '🔒' : def.emoji,
            style: TextStyle(fontSize: size * 0.38),
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter — draws the badge background shape with gradient.
// ---------------------------------------------------------------------------
class _BadgePainter extends CustomPainter {
  const _BadgePainter({required this.def, required this.locked});

  final BadgeDef def;
  final bool locked;

  static const _lockedA = Color(0xFF5A5A6A);
  static const _lockedB = Color(0xFF6E6E7E);

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = locked ? _lockedA : def.colorStart;
    final c2 = locked ? _lockedB : def.colorEnd;

    final rect  = Offset.zero & size;
    final inner = Rect.fromLTWH(size.width * 0.05, size.height * 0.05,
        size.width * 0.9, size.height * 0.9);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c1, c2],
    );
    final fill = Paint()..shader = gradient.createShader(rect);
    // White outer border
    final border = Paint()..color = Colors.white.withValues(alpha: 0.35);

    switch (def.shape) {
      case BadgeShape.rounded:
      case BadgeShape.star:
        final r = Radius.circular(size.width * 0.18);
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(1), r), border);
        canvas.drawRRect(RRect.fromRectAndRadius(inner, r), fill);
      case BadgeShape.circle:
        canvas.drawCircle(rect.center, size.width / 2 - 1, border);
        canvas.drawCircle(rect.center, size.width * 0.44, fill);
      case BadgeShape.hexagon:
        _drawPoly(canvas, rect.center, size.width / 2 - 1, 6, -pi / 2, border);
        _drawPoly(canvas, rect.center, size.width * 0.43, 6, -pi / 2, fill);
      case BadgeShape.octagon:
        _drawPoly(canvas, rect.center, size.width / 2 - 1, 8, -pi / 8, border);
        _drawPoly(canvas, rect.center, size.width * 0.43, 8, -pi / 8, fill);
      case BadgeShape.shield:
        _drawShield(canvas, size, border, fill);
    }
  }

  void _drawPoly(Canvas canvas, Offset center, double r, int sides,
      double startAngle, Paint paint) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = startAngle + i * 2 * pi / sides;
      final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      if (i == 0) path.moveTo(pt.dx, pt.dy);
      else path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawShield(Canvas canvas, Size s, Paint border, Paint fill) {
    // Shield: wide top, narrows to a point at the bottom.
    Path shieldPath(double pad) {
      final w = s.width - pad * 2;
      final h = s.height - pad * 2;
      final l = pad, t = pad, r = pad + w, b = pad + h;
      return Path()
        ..moveTo(l + w * 0.5, t)
        ..lineTo(r, t + h * 0.18)
        ..lineTo(r, t + h * 0.58)
        ..quadraticBezierTo(r, t + h * 0.82, l + w * 0.5, b)
        ..quadraticBezierTo(l, t + h * 0.82, l, t + h * 0.58)
        ..lineTo(l, t + h * 0.18)
        ..close();
    }
    canvas.drawPath(shieldPath(1), border);
    canvas.drawPath(shieldPath(s.width * 0.06), fill);
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.def != def || old.locked != locked;
}
