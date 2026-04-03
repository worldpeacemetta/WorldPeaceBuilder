import 'dart:math' show pi;

import 'package:flutter/material.dart';

import '../models/badge.dart';

// ---------------------------------------------------------------------------
// BadgeWidget — renders a single badge matching the web app design.
// All drawing is done in a 120×115 SVG coordinate space, then scaled.
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BadgePainter — draws shape + icon + lock overlay in one pass.
// ---------------------------------------------------------------------------
class _BadgePainter extends CustomPainter {
  const _BadgePainter({required this.def, required this.locked});

  final BadgeDef def;
  final bool locked;

  static const _lockedA = Color(0xFF5A5A6A);
  static const _lockedB = Color(0xFF6E6E7E);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120.0;
    canvas.save();
    canvas.scale(scale, scale);
    _drawShape(canvas);
    _drawIcon(canvas);
    if (locked) _drawLock(canvas);
    canvas.restore();
  }

  // ── Shape ────────────────────────────────────────────────────────────────

  void _drawShape(Canvas canvas) {
    final c1 = locked ? _lockedA : def.colorStart;
    final c2 = locked ? _lockedB : def.colorEnd;
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c1, c2],
    ).createShader(const Rect.fromLTWH(0, 0, 120, 120));

    final white = Paint()..color = Colors.white;
    final grad  = Paint()..shader = shader;

    switch (def.shape) {
      case BadgeShape.rounded:
      case BadgeShape.star:
        canvas.drawRRect(RRect.fromLTRBR(8, 8, 112, 112, const Radius.circular(22)), white);
        canvas.drawRRect(RRect.fromLTRBR(12, 12, 108, 108, const Radius.circular(18)), grad);
      case BadgeShape.hexagon:
        _poly(canvas, [[60,4],[112,30],[112,82],[60,108],[8,82],[8,30]], white);
        _poly(canvas, [[60,10],[106,33],[106,79],[60,102],[14,79],[14,33]], grad);
      case BadgeShape.circle:
        canvas.drawCircle(const Offset(60, 56), 52, white);
        canvas.drawCircle(const Offset(60, 56), 46, grad);
      case BadgeShape.octagon:
        _poly(canvas, [[38,4],[82,4],[108,30],[108,78],[82,104],[38,104],[12,78],[12,30]], white);
        _poly(canvas, [[40,10],[80,10],[102,32],[102,76],[80,98],[40,98],[18,76],[18,32]], grad);
      case BadgeShape.shield:
        canvas.drawPath(_shieldOuter, white);
        canvas.drawPath(_shieldInner, grad);
    }
  }

  static final _shieldOuter = _makePath((p) {
    p.moveTo(60, 4); p.lineTo(108, 20); p.lineTo(108, 68);
    p.quadraticBezierTo(108, 92, 60, 110);
    p.quadraticBezierTo(12, 92, 12, 68);
    p.lineTo(12, 20); p.close();
  });
  static final _shieldInner = _makePath((p) {
    p.moveTo(60, 10); p.lineTo(102, 24); p.lineTo(102, 66);
    p.quadraticBezierTo(102, 87, 60, 104);
    p.quadraticBezierTo(18, 87, 18, 66);
    p.lineTo(18, 24); p.close();
  });

  // ── Lock overlay (shown when locked, on top of dimmed icon) ──────────────

  void _drawLock(Canvas canvas) {
    canvas.drawCircle(const Offset(60, 60), 16,
        Paint()..color = const Color(0xFF1E1E28).withValues(alpha: 0.60));
    canvas.drawRRect(RRect.fromLTRBR(52, 58, 68, 71, const Radius.circular(2)),
        Paint()..color = const Color(0xFF9E9E9E));
    canvas.drawPath(
      _makePath((p) {
        p.moveTo(56, 58); p.lineTo(56, 53);
        p.quadraticBezierTo(56, 48, 60, 48);
        p.quadraticBezierTo(64, 48, 64, 53);
        p.lineTo(64, 58);
      }),
      Paint()
        ..color = const Color(0xFF9E9E9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(60, 64), 1.5,
        Paint()..color = const Color(0xFF616161));
  }

  // ── Icon dispatcher ───────────────────────────────────────────────────────

  void _drawIcon(Canvas canvas) {
    // Icons are drawn at 30% opacity when locked (dimmed, lock overlay on top)
    final op   = locked ? 0.3 : 1.0;
    final pale = locked ? const Color(0xFFAAAAAA) : def.accent;
    switch (def.icon) {
      case 'calendar7':    _calendar7(canvas, op, pale);
      case 'calendar14':   _calendar14(canvas, op, pale);
      case 'calendar30':   _calendar30(canvas, op, pale);
      case 'calendar90':   _calendar90(canvas, op, pale);
      case 'muscle7':      _muscle7(canvas, op, pale);
      case 'muscle14':     _muscle14(canvas, op, pale);
      case 'muscle30':     _muscle30(canvas, op, pale);
      case 'muscle90':     _muscle90(canvas, op, pale);
      case 'greenweek':    _greenweek(canvas, op, pale);
      case 'footprint':    _footprint(canvas, op, pale);
      case 'num10':        _num10(canvas, op, pale);
      case 'num30':        _num30(canvas, op, pale);
      case 'num100':       _num100(canvas, op, pale);
      case 'proteinFirst': _proteinFirst(canvas, op, pale);
      case 'protein10':    _protein10(canvas, op, pale);
      case 'protein20':    _protein20(canvas, op, pale);
      case 'protein50':    _protein50(canvas, op, pale);
      case 'protein100':   _protein100(canvas, op, pale);
      case 'perfectStar':  _perfectStar(canvas, op);
      case 'hatTrick':     _hatTrick(canvas, op, pale);
      case 'perfectWeek':  _perfectWeek(canvas, op);
      case 'perfectMonth': _perfectMonth(canvas, op, pale);
      case 'rainbow':      _rainbow(canvas, op);
      case 'book10':       _book10(canvas, op, pale);
      case 'book25':       _book25(canvas, op, pale);
      case 'book50':       _book50(canvas, op, pale);
      case 'book100':      _book100(canvas, op, pale);
      case 'book200':      _book200(canvas, op, pale);
      case 'chef':         _chef(canvas, op, pale);
    }
  }

  // ── Drawing helpers ───────────────────────────────────────────────────────

  static Path _makePath(void Function(Path) fn) {
    final p = Path(); fn(p); return p;
  }

  void _poly(Canvas canvas, List<List<num>> pts, Paint paint) {
    final p = Path()..moveTo(pts[0][0].toDouble(), pts[0][1].toDouble());
    for (int i = 1; i < pts.length; i++) p.lineTo(pts[i][0].toDouble(), pts[i][1].toDouble());
    p.close();
    canvas.drawPath(p, paint);
  }

  /// Filled paint — alpha is the final opacity (0–1).
  static Paint _f(Color c, double a) =>
      Paint()..color = c.withValues(alpha: a.clamp(0.0, 1.0));

  /// Stroked paint.
  static Paint _s(Color c, double a, double w,
          {StrokeCap cap = StrokeCap.butt}) =>
      Paint()
        ..color = c.withValues(alpha: a.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = cap;

  static const _W = Colors.white;

  /// Draw text centered at SVG point (x, y-baseline).
  void _txt(Canvas canvas, String s, double x, double y, double fs,
      Color c, double op) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: c.withValues(alpha: op.clamp(0.0, 1.0)),
              fontSize: fs,
              fontWeight: FontWeight.w900,
              leadingDistribution: TextLeadingDistribution.even)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height * 0.80));
  }

  // ── PLACEHOLDER — icon bodies added in next steps ────────────────────────


  // ── Calendar base (shared) ───────────────────────────────────────────────
  void _calBase(Canvas canvas, double op, Color pale,
      {double bx = 38, double bw = 44, double lx = 48, double rx = 72}) {
    // White body
    canvas.drawRRect(RRect.fromLTRBR(bx, 32, bx+bw, 72, const Radius.circular(5)),
        _f(_W, op * 0.9));
    // Coloured header
    canvas.drawRRect(RRect.fromLTRBR(bx, 32, bx+bw, 44, const Radius.circular(5)),
        _f(pale, op));
    // Binding rings
    canvas.drawLine(Offset(lx, 28), Offset(lx, 36), _s(_W, op, 2.5, cap: StrokeCap.round));
    canvas.drawLine(Offset(rx, 28), Offset(rx, 36), _s(_W, op, 2.5, cap: StrokeCap.round));
  }

  void _calendar7(Canvas canvas, double op, Color pale) {
    _calBase(canvas, op, pale);
    _txt(canvas, '7', 60, 64, 16, const Color(0xFFE65100), op);
    canvas.drawPath(_makePath((p) {
      p.moveTo(78, 40); p.quadraticBezierTo(82, 34, 80, 28);
      p.quadraticBezierTo(84, 32, 82, 38);
      p.quadraticBezierTo(86, 32, 84, 26);
      p.quadraticBezierTo(90, 34, 82, 44); p.close();
    }), _f(const Color(0xFFFF6B35), op * 0.8));
  }

  void _calendar14(Canvas canvas, double op, Color pale) {
    _calBase(canvas, op, pale, bx: 36, bw: 48, lx: 46, rx: 74);
    _txt(canvas, '14', 60, 64, 14, const Color(0xFFC62828), op);
    canvas.drawPath(_makePath((p) {
      p.moveTo(80, 38); p.quadraticBezierTo(85, 30, 82, 24);
      p.quadraticBezierTo(88, 30, 84, 38);
      p.quadraticBezierTo(90, 28, 86, 22);
      p.quadraticBezierTo(94, 32, 84, 44); p.close();
    }), _f(const Color(0xFFFF6B35), op * 0.9));
  }

  void _calendar30(Canvas canvas, double op, Color pale) {
    _calBase(canvas, op, pale, bx: 36, bw: 48, lx: 46, rx: 74);
    _txt(canvas, '30', 60, 64, 14, const Color(0xFF880E4F), op);
    canvas.drawPath(_makePath((p) {
      p.moveTo(80, 36); p.quadraticBezierTo(86, 26, 82, 18);
      p.quadraticBezierTo(90, 28, 85, 38);
      p.quadraticBezierTo(92, 24, 88, 16);
      p.quadraticBezierTo(98, 30, 86, 44); p.close();
    }), _f(const Color(0xFFFF5252), op * 0.9));
    canvas.drawPath(_makePath((p) {
      p.moveTo(34, 40); p.quadraticBezierTo(28, 32, 32, 24);
      p.quadraticBezierTo(26, 30, 30, 38); p.close();
    }), _f(const Color(0xFFFF5252), op * 0.6));
  }

  void _calendar90(Canvas canvas, double op, Color pale) {
    _calBase(canvas, op, pale, bx: 36, bw: 48, lx: 46, rx: 74);
    _txt(canvas, '90', 60, 64, 14, const Color(0xFF4A0020), op);
    canvas.drawPath(_makePath((p) {
      p.moveTo(80, 34); p.quadraticBezierTo(88, 22, 84, 14);
      p.quadraticBezierTo(92, 24, 86, 36);
      p.quadraticBezierTo(94, 20, 90, 12);
      p.quadraticBezierTo(100, 28, 88, 44); p.close();
    }), _f(const Color(0xFFFF1744), op * 0.9));
    canvas.drawPath(_makePath((p) {
      p.moveTo(32, 38); p.quadraticBezierTo(26, 28, 30, 20);
      p.quadraticBezierTo(24, 28, 28, 36);
      p.quadraticBezierTo(22, 24, 26, 16);
      p.quadraticBezierTo(18, 30, 28, 42); p.close();
    }), _f(const Color(0xFFFF1744), op * 0.7));
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(Offset(35 + i * 10, 76), 1.5,
          _f(const Color(0xFFC2185B), op * 0.6));
    }
  }





  // ── Muscle/dumbbell base ─────────────────────────────────────────────────
  static final _armOuter7 = _makePath((p) {
    p.moveTo(42,70); p.quadraticBezierTo(42,50,50,42);
    p.quadraticBezierTo(56,36,60,40); p.quadraticBezierTo(66,36,70,44);
    p.quadraticBezierTo(78,54,70,62); p.close();
  });
  static final _armInner7 = _makePath((p) {
    p.moveTo(44,68); p.quadraticBezierTo(44,52,51,44);
    p.quadraticBezierTo(56,39,60,42); p.quadraticBezierTo(65,38,69,46);
    p.quadraticBezierTo(76,54,69,61); p.close();
  });
  static final _armOuter30 = _makePath((p) {
    p.moveTo(40,70); p.quadraticBezierTo(40,48,50,40);
    p.quadraticBezierTo(56,34,60,38); p.quadraticBezierTo(66,34,72,42);
    p.quadraticBezierTo(80,52,72,62); p.close();
  });
  static final _armInner30 = _makePath((p) {
    p.moveTo(42,68); p.quadraticBezierTo(42,50,51,42);
    p.quadraticBezierTo(56,37,60,40); p.quadraticBezierTo(65,36,71,44);
    p.quadraticBezierTo(78,52,71,61); p.close();
  });
  static final _armOuter90 = _makePath((p) {
    p.moveTo(38,70); p.quadraticBezierTo(38,46,48,38);
    p.quadraticBezierTo(56,30,60,36); p.quadraticBezierTo(66,30,74,40);
    p.quadraticBezierTo(84,52,74,64); p.close();
  });
  static final _armInner90 = _makePath((p) {
    p.moveTo(40,68); p.quadraticBezierTo(40,48,49,40);
    p.quadraticBezierTo(56,33,60,38); p.quadraticBezierTo(65,33,73,42);
    p.quadraticBezierTo(82,52,73,63); p.close();
  });

  void _muscle7(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_armOuter7, _f(_W, op * 0.9));
    canvas.drawPath(_armInner7, _f(pale, op));
    _txt(canvas, '7', 58, 58, 14, const Color(0xFF7B1FA2), op);
    canvas.drawCircle(const Offset(48, 38), 3, _f(_W, op * 0.6));
    canvas.drawCircle(const Offset(72, 36), 2, _f(_W, op * 0.4));
    canvas.drawRRect(RRect.fromLTRBR(38,70,82,76, const Radius.circular(3)), _f(_W, op*0.7));
    canvas.drawRRect(RRect.fromLTRBR(34,67,42,79, const Radius.circular(2)), _f(_W, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(78,67,86,79, const Radius.circular(2)), _f(_W, op*0.8));
  }

  void _muscle14(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_armOuter7, _f(_W, op * 0.9));
    canvas.drawPath(_armInner7, _f(pale, op));
    _txt(canvas, '14', 58, 58, 12, const Color(0xFF6A1B9A), op);
    canvas.drawCircle(const Offset(46, 36), 4, _f(_W, op * 0.5));
    canvas.drawCircle(const Offset(74, 34), 3, _f(_W, op * 0.4));
    canvas.drawRRect(RRect.fromLTRBR(38,70,82,76, const Radius.circular(3)), _f(_W, op*0.7));
    canvas.drawRRect(RRect.fromLTRBR(32,67,42,79, const Radius.circular(2)), _f(_W, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(78,67,88,79, const Radius.circular(2)), _f(_W, op*0.8));
  }

  void _muscle30(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_armOuter30, _f(_W, op * 0.9));
    canvas.drawPath(_armInner30, _f(pale, op));
    _txt(canvas, '30', 58, 58, 12, const Color(0xFF4A148C), op);
    canvas.drawRRect(RRect.fromLTRBR(36,70,84,77, const Radius.circular(3.5)), _f(_W, op*0.7));
    canvas.drawRRect(RRect.fromLTRBR(30,66,42,80, const Radius.circular(3)), _f(_W, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(78,66,90,80, const Radius.circular(3)), _f(_W, op*0.8));
    for (final x in [42.0, 50.0, 58.0, 66.0, 74.0]) {
      canvas.drawCircle(Offset(x, 34), 2, _f(_W, op * 0.5));
    }
  }

  void _muscle90(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_armOuter90, _f(_W, op * 0.9));
    canvas.drawPath(_armInner90, _f(pale, op));
    _txt(canvas, '90', 58, 56, 12, const Color(0xFF311B92), op);
    canvas.drawRRect(RRect.fromLTRBR(34,70,86,78, const Radius.circular(4)), _f(_W, op*0.7));
    canvas.drawRRect(RRect.fromLTRBR(28,65,42,81, const Radius.circular(3)), _f(_W, op*0.85));
    canvas.drawRRect(RRect.fromLTRBR(78,65,92,81, const Radius.circular(3)), _f(_W, op*0.85));
    for (final xs in [[44.0,48.0,52.0],[68.0,72.0,76.0]]) {
      canvas.drawPath(_makePath((p) {
        p.moveTo(xs[0], 32); p.lineTo(xs[1], 24); p.lineTo(xs[2], 32);
      }), _s(const Color(0xFFFFD600), op, 2, cap: StrokeCap.round));
    }
    canvas.drawCircle(const Offset(60, 26), 3, _f(const Color(0xFFFFD600), op*0.8));
  }





  void _greenweek(Canvas canvas, double op, Color pale) {
    canvas.drawCircle(const Offset(50, 50), 14, _f(const Color(0xFF81C784), op));
    canvas.drawPath(_makePath((p) {
      p.moveTo(50,36); p.quadraticBezierTo(58,42,50,50);
      p.quadraticBezierTo(42,42,50,36); p.close();
    }), _f(const Color(0xFF43A047), op));
    canvas.drawLine(const Offset(50,50), const Offset(50,64),
        _s(const Color(0xFF388E3C), op, 2));
    canvas.drawCircle(const Offset(72, 54), 10, _f(const Color(0xFFFF7043), op));
    canvas.drawCircle(const Offset(72, 52), 3, _f(const Color(0xFFD84315), op*0.3));
    canvas.drawPath(_makePath((p) {
      p.moveTo(72,44); p.quadraticBezierTo(75,42,74,46); p.close();
    }), _f(const Color(0xFF43A047), op));
    _txt(canvas, '×7', 60, 82, 8, _W, op * 0.8);
    canvas.drawPath(_makePath((p) {
      p.moveTo(30,60); p.quadraticBezierTo(34,52,38,58); p.close();
    }), _f(const Color(0xFFA5D6A7), op*0.7));
  }

  void _footprint(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(34,46,52,24), _f(_W, op*0.15));
    canvas.drawOval(const Rect.fromLTWH(36,38,48,36), _f(_W, op*0.95));
    canvas.drawOval(const Rect.fromLTWH(42,43,36,26), _f(pale, op*0.4));
    canvas.drawOval(const Rect.fromLTWH(53,49,14,10), _f(const Color(0xFFFF8A65), op*0.85));
    canvas.drawOval(const Rect.fromLTWH(55,49,10,6),  _f(const Color(0xFFFFAB91), op*0.6));
    canvas.drawOval(const Rect.fromLTWH(53,48,14,4),  _f(const Color(0xFF66BB6A), op*0.7));
    // fork
    canvas.drawLine(const Offset(36,36), const Offset(42,68), _s(_W, op*0.8, 2.5, cap: StrokeCap.round));
    canvas.drawLine(const Offset(34,36), const Offset(35,44), _s(_W, op*0.7, 1.5, cap: StrokeCap.round));
    canvas.drawLine(const Offset(38,36), const Offset(39,44), _s(_W, op*0.7, 1.5, cap: StrokeCap.round));
    // knife
    canvas.drawLine(const Offset(84,36), const Offset(78,68), _s(_W, op*0.8, 2.5, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) { p.moveTo(84,36); p.quadraticBezierTo(88,40,86,48); }),
        _s(_W, op*0.6, 1.5, cap: StrokeCap.round));
    // sparkle
    canvas.drawPath(_makePath((p) {
      p.moveTo(76,30); p.lineTo(78,24); p.lineTo(80,30);
      p.lineTo(76,27); p.lineTo(80,27); p.close();
    }), _f(const Color(0xFFFFD600), op*0.9));
    canvas.drawCircle(const Offset(44,30), 2, _f(const Color(0xFFFFD600), op*0.6));
  }

  void _num10(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(32,66,56,16), _f(const Color(0xFF8D6E63), op*0.5));
    canvas.drawOval(const Rect.fromLTWH(36,66,48,12), _f(const Color(0xFFA1887F), op*0.35));
    canvas.drawPath(_makePath((p) { p.moveTo(60,72); p.quadraticBezierTo(58,58,60,46); }),
        _s(const Color(0xFF66BB6A), op*0.9, 3, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) {
      p.moveTo(60,56); p.quadraticBezierTo(50,48,46,52);
      p.quadraticBezierTo(50,56,60,56); p.close();
    }), _f(const Color(0xFF66BB6A), op*0.85));
    canvas.drawPath(_makePath((p) {
      p.moveTo(60,50); p.quadraticBezierTo(70,42,74,46);
      p.quadraticBezierTo(70,50,60,50); p.close();
    }), _f(const Color(0xFF81C784), op*0.8));
    canvas.drawCircle(const Offset(60,44), 3, _f(const Color(0xFFA5D6A7), op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(76,48,92,60, const Radius.circular(2)), _f(_W, op*0.9));
    canvas.drawLine(const Offset(84,60), const Offset(84,74),
        _s(_W, op*0.7, 2, cap: StrokeCap.round));
    _txt(canvas, '10', 84, 57, 8, const Color(0xFF00897B), op);
  }

  void _num30(Canvas canvas, double op, Color pale) {
    canvas.drawRRect(RRect.fromLTRBR(56,56,64,80, const Radius.circular(2)),
        _f(const Color(0xFF8D6E63), op*0.65));
    canvas.drawOval(const Rect.fromLTWH(38,75,44,10),
        _f(const Color(0xFF8D6E63), op*0.35));
    for (final d in [
      [36.0, 34.0, 24.0, const Color(0xFF66BB6A), 0.75],
      [60.0, 34.0, 24.0, const Color(0xFF81C784), 0.70],
      [46.0, 26.0, 28.0, const Color(0xFF4CAF50), 0.80],
      [44.0, 26.0, 20.0, const Color(0xFF66BB6A), 0.65],
      [58.0, 28.0, 20.0, const Color(0xFF43A047), 0.60],
    ]) {
      canvas.drawCircle(Offset(d[0] as double, d[1] as double),
          (d[2] as double)/2, _f(d[3] as Color, op*(d[4] as double)));
    }
    canvas.drawCircle(const Offset(46,50), 3, _f(const Color(0xFFFF7043), op*0.7));
    canvas.drawCircle(const Offset(70,42), 2.5, _f(const Color(0xFFFFCA28), op*0.65));
    canvas.drawCircle(const Offset(84,28), 9, _f(_W, op*0.85));
    _txt(canvas, '30', 84, 32, 10, const Color(0xFF00796B), op);
  }

  void _num100(Canvas canvas, double op, Color pale) {
    _poly(canvas, [[20,82],[50,32],[80,82]], _f(_W, op*0.2));
    _poly(canvas, [[30,82],[64,26],[98,82]], _f(_W, op*0.9));
    _poly(canvas, [[38,82],[64,32],[90,82]], _f(pale, op*0.4));
    _poly(canvas, [[64,26],[56,42],[72,42]], _f(_W, op*0.95));
    canvas.drawPath(_makePath((p) {
      p.moveTo(56,42); p.quadraticBezierTo(60,46,64,42);
      p.quadraticBezierTo(68,46,72,42);
    }), _f(_W, op*0.8));
    canvas.drawLine(const Offset(64,26), const Offset(64,14),
        _s(_W, op, 2, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) {
      p.moveTo(64,14); p.lineTo(80,18); p.lineTo(64,22); p.close();
    }), _f(const Color(0xFFFF5252), op*0.9));
    _txt(canvas, '100', 72, 20, 5, _W, op);
    canvas.drawCircle(const Offset(56,18), 2, _f(const Color(0xFFFFD600), op*0.8));
    canvas.drawCircle(const Offset(78,12), 1.5, _f(const Color(0xFFFFD600), op*0.6));
  }






  void _proteinFirst(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(63,62,10,8),  _f(_W, op*0.9));
    canvas.drawOval(const Rect.fromLTWH(69,66,10,8),  _f(_W, op*0.9));
    canvas.save();
    canvas.translate(66, 68); canvas.rotate(20 * pi / 180); canvas.translate(-66, -68);
    canvas.drawRRect(RRect.fromLTRBR(62,62,70,76, const Radius.circular(3)), _f(_W, op*0.9));
    canvas.restore();
    canvas.save();
    canvas.translate(52, 50); canvas.rotate(-15 * pi / 180); canvas.translate(-52, -50);
    canvas.drawOval(const Rect.fromLTWH(34,35,36,30), _f(_W, op*0.95));
    canvas.drawOval(const Rect.fromLTWH(38,38,28,24), _f(pale, op));
    canvas.restore();
    canvas.drawCircle(const Offset(76,32), 10, _f(const Color(0xFF4CAF50), op*0.9));
    canvas.drawPath(_makePath((p) {
      p.moveTo(71,32); p.lineTo(75,36); p.lineTo(82,28);
    }), _s(_W, op, 2.5, cap: StrokeCap.round));
  }

  void _protein10(Canvas canvas, double op, Color pale) {
    canvas.drawRRect(RRect.fromLTRBR(44,42,76,80, const Radius.circular(6)), _f(_W, op*0.95));
    canvas.drawRRect(RRect.fromLTRBR(47,50,73,76, const Radius.circular(3)), _f(pale, op));
    canvas.drawRRect(RRect.fromLTRBR(46,34,74,44, const Radius.circular(4)), _f(_W, op));
    canvas.drawRRect(RRect.fromLTRBR(52,28,68,36, const Radius.circular(3)), _f(pale, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(56,24,64,30, const Radius.circular(2)), _f(_W, op*0.9));
    canvas.drawPath(_makePath((p) { p.moveTo(36,38); p.quadraticBezierTo(32,44,36,50); }),
        _s(_W, op*0.6, 2, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) { p.moveTo(84,38); p.quadraticBezierTo(88,44,84,50); }),
        _s(_W, op*0.6, 2, cap: StrokeCap.round));
    canvas.drawRRect(RRect.fromLTRBR(47,62,73,76, const Radius.circular(3)), _f(_W, op*0.3));
    _txt(canvas, '10', 60, 61, 14, const Color(0xFF0D47A1), op);
  }

  void _protein20(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(42,34,36,44), _f(_W, op*0.95));
    canvas.drawOval(const Rect.fromLTWH(46,36,28,36), _f(pale, op*0.4));
    canvas.drawCircle(const Offset(54,54), 2, _f(const Color(0xFF0D47A1), op*0.7));
    canvas.drawCircle(const Offset(66,54), 2, _f(const Color(0xFF0D47A1), op*0.7));
    canvas.drawPath(_makePath((p) { p.moveTo(56,60); p.quadraticBezierTo(60,63,64,60); }),
        _s(const Color(0xFF0D47A1), op*0.5, 1.5, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) {
      p.moveTo(42,52); p.quadraticBezierTo(34,48,32,40);
      p.quadraticBezierTo(30,36,34,36); p.quadraticBezierTo(38,36,36,42);
      p.quadraticBezierTo(38,46,42,48); p.close();
    }), _f(_W, op*0.9));
    canvas.drawCircle(const Offset(33,37), 4, _f(pale, op*0.7));
    canvas.drawPath(_makePath((p) {
      p.moveTo(78,52); p.quadraticBezierTo(86,48,88,40);
      p.quadraticBezierTo(90,36,86,36); p.quadraticBezierTo(82,36,84,42);
      p.quadraticBezierTo(82,46,78,48); p.close();
    }), _f(_W, op*0.9));
    canvas.drawCircle(const Offset(87,37), 4, _f(pale, op*0.7));
    _txt(canvas, '×20', 60, 80, 11, _W, op);
  }

  void _protein50(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(34,36,48,36), _f(_W, op*0.95));
    canvas.drawOval(const Rect.fromLTWH(38,40,40,28), _f(const Color(0xFFE57373), op*0.6));
    canvas.drawPath(_makePath((p) { p.moveTo(44,50); p.quadraticBezierTo(50,46,56,50); p.quadraticBezierTo(62,54,68,50); }),
        _s(_W, op*0.5, 2));
    canvas.drawOval(const Rect.fromLTWH(72,44,12,8), _f(_W, op*0.9));
    canvas.drawRRect(RRect.fromLTRBR(72,46,78,56, const Radius.circular(3)), _f(_W, op*0.8));
    canvas.drawPath(_makePath((p) {
      p.moveTo(34,28); p.lineTo(40,40); p.lineTo(46,28); p.close();
    }), _f(const Color(0xFFFFD600), op*0.8));
    canvas.drawCircle(const Offset(40,40), 8, _f(const Color(0xFFFFD600), op));
    _txt(canvas, '50', 40, 44, 9, const Color(0xFF1A237E), op);
  }

  void _protein100(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_makePath((p) {
      p.moveTo(44,38); p.lineTo(46,68); p.quadraticBezierTo(46,76,60,76);
      p.quadraticBezierTo(74,76,74,68); p.lineTo(76,38); p.close();
    }), _f(_W, op*0.95));
    canvas.drawPath(_makePath((p) {
      p.moveTo(48,42); p.lineTo(50,66); p.quadraticBezierTo(50,72,60,72);
      p.quadraticBezierTo(70,72,70,66); p.lineTo(72,42); p.close();
    }), _f(const Color(0xFFFFD600), op*0.6));
    canvas.drawPath(_makePath((p) { p.moveTo(44,42); p.quadraticBezierTo(32,42,32,52); p.quadraticBezierTo(32,60,44,58); }),
        _s(_W, op*0.8, 3, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) { p.moveTo(76,42); p.quadraticBezierTo(88,42,88,52); p.quadraticBezierTo(88,60,76,58); }),
        _s(_W, op*0.8, 3, cap: StrokeCap.round));
    canvas.drawRRect(RRect.fromLTRBR(54,76,66,80, const Radius.circular(1)), _f(_W, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(48,80,72,84, const Radius.circular(2)), _f(_W, op*0.9));
    canvas.drawCircle(const Offset(54,36), 5, _f(const Color(0xFFFF7043), op*0.8));
    canvas.drawOval(const Rect.fromLTWH(61,30,10,8), _f(_W, op*0.8));
    canvas.drawCircle(const Offset(60,30), 4, _f(const Color(0xFFEF5350), op*0.7));
    _txt(canvas, '100', 60, 60, 14, const Color(0xFF0D1B5E), op);
  }






  void _perfectStar(Canvas canvas, double op) {
    _poly(canvas, [[60,24],[66,44],[88,44],[70,56],[78,76],[60,64],[42,76],[50,56],[32,44],[54,44]],
        _f(_W, op*0.95));
    _poly(canvas, [[60,30],[64,44],[80,44],[68,53],[74,68],[60,60],[46,68],[52,53],[40,44],[56,44]],
        _f(const Color(0xFFFFD600), op));
    canvas.drawCircle(const Offset(60,48), 5, _f(const Color(0xFFFF6F00), op*0.7));
    _txt(canvas, '✓', 60, 51, 6, _W, op);
  }

  void _hatTrick(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(32,58,56,12), _f(_W, op*0.95));
    canvas.drawRRect(RRect.fromLTRBR(42,40,78,66, const Radius.circular(4)), _f(_W, op*0.9));
    canvas.drawRRect(RRect.fromLTRBR(44,42,76,64, const Radius.circular(3)), _f(pale, op*0.3));
    canvas.drawRRect(RRect.fromLTRBR(42,58,78,63, const Radius.circular(1)),
        _f(const Color(0xFFFFD600), op*0.7));
    _poly(canvas, [[46,34],[48,28],[50,34],[44,30],[52,30]], _f(const Color(0xFFFFD600), op*0.9));
    _poly(canvas, [[60,26],[63,18],[66,26],[58,22],[68,22]], _f(const Color(0xFFFFD600), op*0.95));
    _poly(canvas, [[74,34],[76,28],[78,34],[72,30],[80,30]], _f(const Color(0xFFFFD600), op*0.9));
    canvas.drawCircle(const Offset(42,26), 2,   _f(const Color(0xFFFFF176), op*0.6));
    canvas.drawCircle(const Offset(60,14), 2.5, _f(const Color(0xFFFFF176), op*0.7));
    canvas.drawCircle(const Offset(80,24), 1.5, _f(const Color(0xFFFFF176), op*0.5));
    _txt(canvas, '×3 PERFECT', 60, 78, 9, _W, op);
  }

  void _perfectWeek(Canvas canvas, double op) {
    canvas.drawCircle(const Offset(58,52), 26, _f(_W, op*0.9));
    canvas.drawCircle(const Offset(58,52), 22, _f(const Color(0xFFFF8A65), op*0.5));
    canvas.drawCircle(const Offset(58,52), 16, _f(_W, op*0.85));
    canvas.drawCircle(const Offset(58,52), 12, _f(const Color(0xFFFF5252), op*0.5));
    canvas.drawCircle(const Offset(58,52), 6,  _f(_W, op*0.9));
    canvas.drawCircle(const Offset(58,52), 3,  _f(const Color(0xFFFFD600), op*0.9));
    canvas.drawLine(const Offset(58,52), const Offset(86,28),
        _s(_W, op*0.9, 2.5, cap: StrokeCap.round));
    _poly(canvas, [[86,28],[80,30],[84,34]], _f(_W, op*0.9));
    canvas.drawCircle(const Offset(86,72), 9, _f(_W, op*0.85));
    _txt(canvas, '7', 86, 76, 12, const Color(0xFFE65100), op);
  }

  void _perfectMonth(Canvas canvas, double op, Color pale) {
    _poly(canvas, [[60,22],[40,42],[80,42]], _f(_W, op*0.95));
    _poly(canvas, [[60,22],[40,42],[50,42]], _f(const Color(0xFFFFF176), op*0.4));
    _poly(canvas, [[60,22],[70,42],[80,42]], _f(const Color(0xFFFFE082), op*0.3));
    _poly(canvas, [[40,42],[80,42],[60,78]], _f(_W, op*0.9));
    _poly(canvas, [[40,42],[60,42],[50,78]], _f(const Color(0xFFFFF9C4), op*0.25));
    _poly(canvas, [[60,42],[80,42],[70,78]], _f(const Color(0xFFFFE082), op*0.2));
    canvas.drawLine(const Offset(40,42), const Offset(80,42), _s(_W, op*0.4, 1.5));
    for (final pts in [
      [60.0,14,60.0,8], [36.0,28,30.0,24], [84.0,28,90.0,24],
      [28.0,48,22.0,48], [92.0,48,98.0,48],
    ]) {
      canvas.drawLine(Offset(pts[0],pts[1]), Offset(pts[2],pts[3]),
          _s(const Color(0xFFFFD600), op*0.6, 2, cap: StrokeCap.round));
    }
    canvas.drawCircle(const Offset(34,18), 2,   _f(const Color(0xFFFFD600), op*0.5));
    canvas.drawCircle(const Offset(88,16), 2.5, _f(const Color(0xFFFFD600), op*0.6));
    _txt(canvas, '30', 60, 56, 14, const Color(0xFFBF360C), op*0.7);
  }





  void _rainbow(Canvas canvas, double op) {
    // Six concentric rainbow arcs: M startX,68 Q startX,topY midX,topY Q endX,topY endX,68
    final arcs = [
      [30.0, 32.0, 90.0, const Color(0xFFFF1744), 5.0, 0.90],
      [34.0, 38.0, 86.0, const Color(0xFFFF9100), 4.0, 0.85],
      [38.0, 42.0, 82.0, const Color(0xFFFFEA00), 4.0, 0.85],
      [42.0, 46.0, 78.0, const Color(0xFF00E676), 4.0, 0.85],
      [46.0, 50.0, 74.0, const Color(0xFF2979FF), 4.0, 0.85],
      [50.0, 54.0, 70.0, const Color(0xFFD500F9), 4.0, 0.85],
    ];
    for (final a in arcs) {
      final sx = a[0] as double; final ty = a[1] as double;
      final ex = a[2] as double; final mx = (sx + ex) / 2;
      canvas.drawPath(_makePath((p) {
        p.moveTo(sx, 68); p.quadraticBezierTo(sx, ty, mx, ty);
        p.quadraticBezierTo(ex, ty, ex, 68);
      }), _s(a[3] as Color, op * (a[5] as double), a[4] as double));
    }
    canvas.drawCircle(const Offset(42,76), 5, _f(const Color(0xFFFF7043), op));
    canvas.drawPath(_makePath((p) { p.moveTo(42,70); p.quadraticBezierTo(44,68,43,72); p.close(); }),
        _f(const Color(0xFF43A047), op));
    canvas.drawPath(_makePath((p) { p.moveTo(72,72); p.quadraticBezierTo(76,68,72,76); p.quadraticBezierTo(68,68,72,72); p.close(); }),
        _f(const Color(0xFF66BB6A), op));
    canvas.drawLine(const Offset(72,76), const Offset(72,82),
        _s(const Color(0xFF388E3C), op, 1.5));
  }

  void _book10(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_makePath((p) {
      p.moveTo(34,52); p.lineTo(40,78); p.quadraticBezierTo(42,82,60,82);
      p.quadraticBezierTo(78,82,80,78); p.lineTo(86,52); p.close();
    }), _f(_W, op*0.95));
    canvas.drawPath(_makePath((p) {
      p.moveTo(38,56); p.lineTo(42,76); p.quadraticBezierTo(44,78,60,78);
      p.quadraticBezierTo(76,78,78,76); p.lineTo(82,56); p.close();
    }), _f(pale, op*0.5));
    canvas.drawPath(_makePath((p) { p.moveTo(42,52); p.quadraticBezierTo(42,34,60,34); p.quadraticBezierTo(78,34,78,52); }),
        _s(_W, op, 3.5, cap: StrokeCap.round));
    canvas.drawLine(const Offset(50,52), const Offset(48,78), _s(_W, op*0.3, 1.5));
    canvas.drawLine(const Offset(70,52), const Offset(72,78), _s(_W, op*0.3, 1.5));
    canvas.drawLine(const Offset(36,64), const Offset(84,64), _s(_W, op*0.3, 1.5));
    canvas.drawCircle(const Offset(52,48), 7, _f(const Color(0xFFFF5252), op*0.85));
    canvas.drawPath(_makePath((p) { p.moveTo(52,42); p.quadraticBezierTo(54,38,56,40); }),
        _s(const Color(0xFF4CAF50), op, 1.5, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) { p.moveTo(68,50); p.lineTo(72,38); p.lineTo(74,50); p.close(); }),
        _f(const Color(0xFFFF9800), op*0.85));
    canvas.drawCircle(const Offset(82,40), 8, _f(const Color(0xFFFFD600), op*0.85));
    _txt(canvas, '10', 82, 44, 9, const Color(0xFF0277BD), op);
  }

  void _book25(Canvas canvas, double op, Color pale) {
    canvas.drawRRect(RRect.fromLTRBR(38,26,82,86, const Radius.circular(5)), _f(_W, op*0.95));
    canvas.drawRRect(RRect.fromLTRBR(42,30,78,54, const Radius.circular(3)), _f(pale, op*0.5));
    canvas.drawRRect(RRect.fromLTRBR(42,58,78,82, const Radius.circular(3)), _f(pale, op*0.4));
    canvas.drawLine(const Offset(42,56), const Offset(78,56), _s(_W, op*0.5, 2));
    canvas.drawRRect(RRect.fromLTRBR(74,40,77,50, const Radius.circular(1.5)), _f(_W, op*0.6));
    canvas.drawRRect(RRect.fromLTRBR(74,62,77,72, const Radius.circular(1.5)), _f(_W, op*0.6));
    canvas.drawRRect(RRect.fromLTRBR(46,34,54,48, const Radius.circular(1)), _f(_W, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(46,34,54,40, const Radius.circular(1)), _f(const Color(0xFF42A5F5), op*0.5));
    canvas.drawRRect(RRect.fromLTRBR(58,38,64,50, const Radius.circular(2)), _f(const Color(0xFF66BB6A), op*0.6));
    canvas.drawCircle(const Offset(70,44), 5, _f(const Color(0xFFFF7043), op*0.7));
    canvas.drawOval(const Rect.fromLTWH(48,64,12,8), _f(const Color(0xFFFFCA28), op*0.5));
    canvas.drawCircle(const Offset(66,70), 5, _f(const Color(0xFFEF5350), op*0.5));
  }

  void _book50(Canvas canvas, double op, Color pale) {
    canvas.drawCircle(const Offset(52,48), 6, _f(const Color(0xFFFF7043), op*0.6));
    canvas.drawCircle(const Offset(66,44), 5, _f(const Color(0xFF66BB6A), op*0.5));
    canvas.drawOval(const Rect.fromLTWH(39,54,14,8), _f(const Color(0xFFFFCA28), op*0.5));
    canvas.drawCircle(const Offset(70,58), 4, _f(const Color(0xFFAB47BC), op*0.4));
    canvas.drawCircle(const Offset(58,50), 18, _s(_W, op*0.95, 4));
    canvas.drawCircle(const Offset(58,50), 15, _f(_W, op*0.15));
    canvas.drawLine(const Offset(72,62), const Offset(86,78),
        _s(_W, op*0.9, 5, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) { p.moveTo(48,40); p.quadraticBezierTo(52,36,54,40); }),
        _s(_W, op*0.4, 2, cap: StrokeCap.round));
    canvas.drawCircle(const Offset(36,74), 9, _f(const Color(0xFFFFD600), op*0.85));
    _txt(canvas, '50', 36, 78, 10, const Color(0xFF01579B), op);
  }

  void _book100(Canvas canvas, double op, Color pale) {
    canvas.drawCircle(const Offset(56,48), 16, _f(_W, op*0.95));
    canvas.drawCircle(const Offset(50,46), 6, _s(pale, op*0.9, 2));
    canvas.drawCircle(const Offset(62,46), 6, _s(pale, op*0.9, 2));
    canvas.drawLine(const Offset(44,46), const Offset(40,44), _s(pale, op*0.7, 1.5));
    canvas.drawLine(const Offset(68,46), const Offset(72,44), _s(pale, op*0.7, 1.5));
    canvas.drawCircle(const Offset(50,46), 2, _f(const Color(0xFF004C8C), op*0.7));
    canvas.drawCircle(const Offset(62,46), 2, _f(const Color(0xFF004C8C), op*0.7));
    canvas.drawPath(_makePath((p) { p.moveTo(50,54); p.quadraticBezierTo(56,58,62,54); }),
        _s(const Color(0xFF004C8C), op*0.5, 1.5, cap: StrokeCap.round));
    canvas.drawPath(_makePath((p) { p.moveTo(50,32); p.quadraticBezierTo(52,26,56,32); p.quadraticBezierTo(58,26,62,32); p.close(); }),
        _f(_W, op*0.8));
    canvas.drawRRect(RRect.fromLTRBR(72,50,90,74, const Radius.circular(2)), _f(_W, op*0.9));
    canvas.drawRRect(RRect.fromLTRBR(74,50,77,74, const Radius.circular(0)), _f(pale, op*0.5));
    for (final y in [56.0, 60.0, 64.0]) {
      canvas.drawLine(Offset(79, y), Offset(87, y), _s(pale, op*0.4, 1));
    }
    canvas.drawCircle(const Offset(84,69), 3, _f(const Color(0xFFFF7043), op*0.5));
    canvas.drawCircle(const Offset(36,70), 9, _f(const Color(0xFFFFD600), op*0.85));
    _txt(canvas, '100', 36, 74, 9, const Color(0xFF004C8C), op);
  }

  void _book200(Canvas canvas, double op, Color pale) {
    canvas.drawPath(_makePath((p) { p.moveTo(60,42); p.quadraticBezierTo(40,38,28,42); p.lineTo(28,80); p.quadraticBezierTo(40,76,60,80); p.close(); }), _f(_W, op*0.95));
    canvas.drawPath(_makePath((p) { p.moveTo(60,42); p.quadraticBezierTo(80,38,92,42); p.lineTo(92,80); p.quadraticBezierTo(80,76,60,80); p.close(); }), _f(_W, op*0.9));
    canvas.drawLine(const Offset(60,42), const Offset(60,80), _s(pale, op*0.6, 2));
    for (final y in [52.0, 56.0, 60.0]) {
      canvas.drawLine(Offset(34, y), Offset(53, y), _s(pale, op*0.3, 1));
      canvas.drawLine(Offset(66, y), Offset(85, y), _s(pale, op*0.3, 1));
    }
    canvas.drawCircle(const Offset(42,34), 7, _f(const Color(0xFFFF5252), op*0.85));
    canvas.drawPath(_makePath((p) { p.moveTo(42,28); p.quadraticBezierTo(44,24,46,26); }),
        _s(const Color(0xFF4CAF50), op, 1.5, cap: StrokeCap.round));
    canvas.drawCircle(const Offset(74,30), 4,   _f(const Color(0xFF66BB6A), op*0.8));
    canvas.drawCircle(const Offset(70,32), 3.5, _f(const Color(0xFF4CAF50), op*0.7));
    canvas.drawCircle(const Offset(78,32), 3.5, _f(const Color(0xFF4CAF50), op*0.7));
    canvas.drawRRect(RRect.fromLTRBR(73,36,76,41, const Radius.circular(1)), _f(const Color(0xFF8D6E63), op*0.5));
    canvas.drawPath(_makePath((p) { p.moveTo(56,28); p.lineTo(64,28); p.lineTo(60,20); p.close(); }), _f(const Color(0xFFFFCA28), op*0.8));
    canvas.drawPath(_makePath((p) { p.moveTo(84,36); p.lineTo(88,26); p.lineTo(90,36); p.close(); }), _f(const Color(0xFFFF9800), op*0.7));
    canvas.drawCircle(const Offset(60,70), 9, _f(const Color(0xFFFFD600), op*0.9));
    _txt(canvas, '200', 60, 74, 9, const Color(0xFF002F6C), op);
  }

  void _chef(Canvas canvas, double op, Color pale) {
    canvas.drawOval(const Rect.fromLTWH(46,60,28,20), _f(_W, op*0.9));
    canvas.drawCircle(const Offset(60,56), 12, _f(_W, op*0.9));
    canvas.drawCircle(const Offset(54,58), 2, _f(const Color(0xFF333333), op*0.7));
    canvas.drawCircle(const Offset(66,58), 2, _f(const Color(0xFF333333), op*0.7));
    canvas.drawPath(_makePath((p) { p.moveTo(56,64); p.quadraticBezierTo(60,67,64,64); }),
        _s(const Color(0xFF333333), op*0.6, 1.5));
    canvas.drawPath(_makePath((p) { p.moveTo(48,52); p.quadraticBezierTo(48,28,60,28); p.quadraticBezierTo(72,28,72,52); p.close(); }),
        _f(_W, op*0.95));
    canvas.drawCircle(const Offset(52,34), 8, _f(_W, op));
    canvas.drawCircle(const Offset(68,34), 8, _f(_W, op));
    canvas.drawCircle(const Offset(60,30), 9, _f(_W, op));
    canvas.drawRect(const Rect.fromLTWH(48,42,24,10), _f(_W, op));
    canvas.drawPath(_makePath((p) { p.moveTo(54,78); p.quadraticBezierTo(56,82,60,82); p.quadraticBezierTo(64,82,66,78); }),
        _s(_W, op*0.5, 2));
  }








  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.def != def || old.locked != locked;
}
