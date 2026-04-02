import 'package:flutter/material.dart';

import '../models/food.dart';
import '../theme.dart';

/// Shows a 75% animated confirmation sheet after a food is saved.
/// Returns true if the user tapped "Log Now".
Future<bool> showFoodSavedSheet(BuildContext context, Food food) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FoodSavedSheet(food: food),
  );
  return result == true;
}

class _FoodSavedSheet extends StatefulWidget {
  const _FoodSavedSheet({required this.food});
  final Food food;

  @override
  State<_FoodSavedSheet> createState() => _FoodSavedSheetState();
}

class _FoodSavedSheetState extends State<_FoodSavedSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _circleFade;
  late final Animation<double> _checkProgress;
  late final Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Circle fades in 0–30%
    _circleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    // Checkmark draws itself 25–75%
    _checkProgress = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.75, curve: Curves.easeInOut),
    );

    // Content slides up + fades 60–100%
    _contentFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        final cs = AppColorScheme.of(ctx);
        return Container(
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.close, size: 20, color: cs.textMuted),
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Animated checkmark
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) => SizedBox(
                          width: 100,
                          height: 100,
                          child: CustomPaint(
                            painter: _CheckPainter(
                              circleFade: _circleFade.value,
                              checkProgress: _checkProgress.value,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Food name + details
                      FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(_contentFade),
                          child: Column(
                            children: [
                              Text(
                                'Added to Library',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.food.displayName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: cs.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              // Macro summary row
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cs.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _MacroChip('Kcal',
                                        widget.food.kcal.round().toString(),
                                        AppColors.kcal),
                                    _MacroChip('Protein',
                                        '${widget.food.protein.round()}g',
                                        AppColors.protein),
                                    _MacroChip('Carbs',
                                        '${widget.food.carbs.round()}g',
                                        AppColors.carbs),
                                    _MacroChip('Fat',
                                        '${widget.food.fat.round()}g',
                                        AppColors.fat),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 36),

                              // Log Now CTA
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Log Now'),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Done
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    color: cs.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}

// ── Macro chip ─────────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  const _MacroChip(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: AppColorScheme.of(context).textMuted)),
      ],
    );
  }
}

// ── Checkmark painter ─────────────────────────────────────────────────────────

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.circleFade,
    required this.checkProgress,
  });

  final double circleFade;
  final double checkProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background circle
    final bgPaint = Paint()
      ..color = AppColors.protein.withValues(alpha: 0.12 * circleFade)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * circleFade, bgPaint);

    // Circle stroke
    final circlePaint = Paint()
      ..color = AppColors.protein.withValues(alpha: circleFade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius * circleFade, circlePaint);

    if (checkProgress <= 0) return;

    // Checkmark path: two segments
    // Start → elbow → end (relative to center of 100×100)
    final sw = size.width;
    final sh = size.height;
    final p1 = Offset(sw * 0.25, sh * 0.52);
    final p2 = Offset(sw * 0.44, sh * 0.68);
    final p3 = Offset(sw * 0.75, sh * 0.36);

    // Total path length (approximate) split 40/60
    const seg1Frac = 0.38;
    final checkPaint = Paint()
      ..color = AppColors.protein
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (checkProgress <= seg1Frac) {
      final t = checkProgress / seg1Frac;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      final t = (checkProgress - seg1Frac) / (1.0 - seg1Frac);
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circleFade != circleFade || old.checkProgress != checkProgress;
}
