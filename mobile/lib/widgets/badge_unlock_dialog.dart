import 'dart:math' show pi, cos, sin, Random;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/badge.dart';
import '../providers/badges_provider.dart';
import 'badge_widget.dart';

// ---------------------------------------------------------------------------
// Public helper — call this from a ref.listen to show the popup.
// ---------------------------------------------------------------------------
void showBadgeUnlockDialog(BuildContext context, BadgeDef def) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    pageBuilder: (ctx, _, __) => _BadgeUnlockDialog(def: def),
    transitionBuilder: (ctx, anim, _, child) {
      final curve = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
      return ScaleTransition(scale: curve, child: child);
    },
    transitionDuration: const Duration(milliseconds: 500),
  );
}

// ---------------------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------------------
class _BadgeUnlockDialog extends ConsumerStatefulWidget {
  const _BadgeUnlockDialog({required this.def});
  final BadgeDef def;

  @override
  ConsumerState<_BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends ConsumerState<_BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(badgesProvider.notifier).popQueue();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final username = Supabase.instance.client.auth.currentUser
            ?.userMetadata?['display_username'] as String? ??
        'there';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Confetti layer
            AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (_, __) =>
                  _ConfettiPainterWidget(progress: _confettiCtrl.value),
            ),
            // Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'New badge unlocked',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Congrats, $username! ${widget.def.desc}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF555577),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Glow + badge
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.def.colorStart.withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: BadgeWidget(def: widget.def, size: 100),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.def.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.def.category,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF888899),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _dismiss,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D5E),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple confetti painter — coloured rectangles flying outward from centre.
// ---------------------------------------------------------------------------
class _ConfettiPainterWidget extends StatelessWidget {
  const _ConfettiPainterWidget({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      height: 520,
      child: CustomPaint(painter: _ConfettiPainter(progress)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);
  final double progress;

  static final _pieces = List.generate(36, (i) {
    final rng = Random(i * 1337);
    return _Piece(
      angle: (i / 36) * 2 * pi + rng.nextDouble() * 0.4,
      speed: 120 + rng.nextDouble() * 140,
      color: _colors[i % _colors.length],
      size: Size(6 + rng.nextDouble() * 8, 4 + rng.nextDouble() * 6),
      rotSpeed: (rng.nextDouble() - 0.5) * 6,
    );
  });

  static const _colors = [
    Color(0xFFE91E63), Color(0xFF2196F3), Color(0xFF4CAF50),
    Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFF00BCD4),
    Color(0xFFFFEB3B), Color(0xFFFF5722),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

    for (final p in _pieces) {
      final dist = p.speed * t;
      final x = cx + cos(p.angle) * dist;
      final y = cy + sin(p.angle) * dist - 80 * t * t; // slight arc up
      final rot = p.rotSpeed * t;
      final alpha = (1.0 - t * 0.8).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size.width, height: p.size.height),
        Paint()..color = p.color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotSpeed,
  });
  final double angle;
  final double speed;
  final Color color;
  final Size size;
  final double rotSpeed;
}
