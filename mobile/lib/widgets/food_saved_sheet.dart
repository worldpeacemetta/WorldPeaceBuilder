import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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
  late final Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    );
    // Delay content reveal slightly so Lottie plays first
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
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
                      const SizedBox(height: 8),

                      // Lottie success animation
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Lottie.asset(
                          'assets/lottie/LogFoodAnimation.json',
                          repeat: false,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 12),

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
                                style: TextStyle(
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
                                        AppColorScheme.of(context).kcalColor),
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
                                child: Text(
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

