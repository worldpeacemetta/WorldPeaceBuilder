import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/entry.dart';
import '../models/food.dart';
import '../providers/date_provider.dart';
import '../providers/entries_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/smart_insight_provider.dart';
import '../theme.dart';
import 'smart_insight/macro_donut.dart';
import 'smart_insight/meal_detail_sheet.dart';
import 'smart_insight/sparkle.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void showSmartInsightSheet(BuildContext context, WidgetRef ref) {
  final container = ProviderScope.containerOf(context);
  final cardColor  = Theme.of(context).extension<AppColorScheme>()!.card;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: container,
      child: const _SmartInsightSheet(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Meal meta helpers
// ---------------------------------------------------------------------------

Color _mealColor(String meal) => switch (meal) {
  'breakfast' => AppColors.kcal,
  'lunch'     => AppColors.carbs,
  'dinner'    => AppColors.protein,
  'snack'     => AppColors.fat,
  _           => AppColors.textMuted,
};

IconData _mealIcon(String meal) => switch (meal) {
  'breakfast' => Icons.wb_sunny_rounded,
  'lunch'     => Icons.lunch_dining,
  'dinner'    => Icons.dinner_dining,
  'snack'     => Icons.local_cafe_rounded,
  _           => Icons.restaurant_rounded,
};

String _mealTagline(String meal) => switch (meal) {
  'breakfast' => 'Start your day right',
  'lunch'     => 'Fuel your afternoon',
  'dinner'    => 'Nourish your evening',
  'snack'     => 'Smart bites anytime',
  _           => '',
};

String _qtyLabel(String unit, double qty) {
  if (unit == 'perServing') {
    final n = qty.round();
    return '$n serving${n == 1 ? '' : 's'}';
  }
  return '${qty.round()}g';
}

// ---------------------------------------------------------------------------
// Main sheet
// ---------------------------------------------------------------------------

class _SmartInsightSheet extends ConsumerWidget {
  const _SmartInsightSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs           = AppColorScheme.of(context);
    final insightAsync = ref.watch(smartInsightProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SpinningSparkle(size: 18, color: cs.smartInsightColor),
                        const SizedBox(width: 6),
                        Text('Smart Insight',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (insightAsync.valueOrNull?.loggedDays != null &&
                        insightAsync.value!.loggedDays > 0)
                      Text(
                        'Based on ${insightAsync.value!.loggedDays} days of history',
                        style: TextStyle(fontSize: 12, color: cs.textMuted),
                      ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.border),
          // Content
          Expanded(
            child: insightAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => Center(
                child: Text('Unable to load insights',
                    style: TextStyle(color: cs.textMuted)),
              ),
              data: (result) {
                final slots = kSmartInsightMealSlots
                    .where((m) => result.suggestions[m]?.isNotEmpty == true)
                    .toList();
                if (!result.available || slots.isEmpty) {
                  return _EmptyState(loggedDays: result.loggedDays);
                }
                return _CardDeck(
                  slots: slots,
                  suggestions: result.suggestions,
                  parentContext: context,
                  ref: ref,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carousel constants
// ---------------------------------------------------------------------------

/// How much the previous card's bottom strip peeks above the active card.
const _kPeekAbove  = 91.0;
/// How much the first behind-below card peeks below the active card.
const _kPeekBelow1 = 103.0;
/// How much the second behind-below card peeks below the first behind card.
const _kPeekBelow2 = 91.0;
/// Horizontal scale for non-active cards — subtle inward shrink signals depth.
const _kBackScale  = 0.95;

// ---------------------------------------------------------------------------
// Card deck — slot selector + option carousel
// ---------------------------------------------------------------------------

class _CardDeck extends StatefulWidget {
  const _CardDeck({
    required this.slots,
    required this.suggestions,
    required this.parentContext,
    required this.ref,
  });

  final List<String> slots;
  final Map<String, List<MealInsight>> suggestions;
  final BuildContext parentContext;
  final WidgetRef ref;

  @override
  State<_CardDeck> createState() => _CardDeckState();
}

class _CardDeckState extends State<_CardDeck> {
  int _slotIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentSlot = widget.slots[_slotIndex];
    final options     = widget.suggestions[currentSlot]!;

    return Column(
      children: [
        const SizedBox(height: 8),
        if (widget.slots.length > 1) ...[
          _SlotSelector(
            slots:          widget.slots,
            selectedIndex:  _slotIndex,
            onSlotSelected: (i) => setState(() => _slotIndex = i),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 4),
        Expanded(
          child: _OptionCarousel(
            key:           ValueKey('slot_${_slotIndex}_${options.length}'),
            options:       options,
            slot:          currentSlot,
            parentContext: widget.parentContext,
            ref:           widget.ref,
          ),
        ),
        const _InfoRow(),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Slot selector — horizontal pill tabs
// ---------------------------------------------------------------------------

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({
    required this.slots,
    required this.selectedIndex,
    required this.onSlotSelected,
  });

  final List<String>      slots;
  final int               selectedIndex;
  final ValueChanged<int> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.symmetric(horizontal: 16),
        itemCount:        slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final slot       = slots[i];
          final isSelected = i == selectedIndex;
          final color      = _mealColor(slot);
          return GestureDetector(
            onTap: () => onSlotSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve:    Curves.easeOut,
              padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.60)
                      : cs.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _mealIcon(slot),
                    size:  13,
                    color: isSelected ? color : cs.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mealLabels[slot] ?? slot,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:      isSelected ? color : cs.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Option carousel — spring-driven vertical stacked-card carousel
//
// Three cards remain in a compact stacked deck at all times.  The active card
// is fully visible in front; the others peek above/below it.
// Swipe DOWN → next option rises to front.  Swipe UP → previous returns.
// ---------------------------------------------------------------------------

class _OptionCarousel extends StatefulWidget {
  const _OptionCarousel({
    super.key,
    required this.options,
    required this.slot,
    required this.parentContext,
    required this.ref,
  });

  final List<MealInsight> options;
  final String            slot;
  final BuildContext      parentContext;
  final WidgetRef         ref;

  @override
  State<_OptionCarousel> createState() => _OptionCarouselState();
}

class _OptionCarouselState extends State<_OptionCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  double _cardHeight = 300.0;
  double _dragRaw    = 0.0;

  int get _n => widget.options.length;

  // ── Geometry ──────────────────────────────────────────────────────────────

  /// Y-position for card [i] in the stacked deck at the current fractional page.
  ///
  /// Three regions:
  ///   rel ≤ 0  — active / previous: bottom edge sits at activeTop, so only
  ///              kPeekAbove strip is visible at the container's top edge.
  ///   0 < rel ≤ 1 — first below: top offset = rel * kPeekBelow1, so the card
  ///              is mostly hidden under the active card with exactly kPeekBelow1
  ///              sticking out below.
  ///   rel > 1  — each deeper card adds kPeekBelow2 of its own visible strip.
  ///
  /// kPeekAbove == kPeekBelow2 keeps total deck height == availH for every
  /// active page, so the ClipRect never cuts off a visible peek strip.
  double _topFor(int i) {
    final p         = _ctrl.value;
    final rel       = i.toDouble() - p;
    // Shift active card down by kPeekAbove once a previous card exists (p ≥ 1).
    final activeTop = p.clamp(0.0, 1.0) * _kPeekAbove;

    if (rel <= 0) {
      return activeTop + rel * _cardHeight;
    } else if (rel <= 1) {
      // Card sits so its top is kPeekBelow1 before the active card's bottom edge,
      // leaving exactly kPeekBelow1 of it visible below the active card.
      return activeTop + rel * _kPeekBelow1;
    } else {
      // Each deeper card stacks kPeekBelow2 below the one above it.
      return activeTop + _kPeekBelow1 + (rel - 1) * _kPeekBelow2;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails _) {
    if (_ctrl.isAnimating) _ctrl.stop();
    _dragRaw = _ctrl.value;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_cardHeight <= 0) return;
    // Swipe UP (dy < 0) → page increases → next card rises to front.
    _dragRaw += -d.delta.dy / _cardHeight;
    final maxPage = (_n - 1).toDouble();
    if (_dragRaw < 0) {
      _ctrl.value = _dragRaw * 0.2;
    } else if (_dragRaw > maxPage) {
      _ctrl.value = maxPage + (_dragRaw - maxPage) * 0.2;
    } else {
      _ctrl.value = _dragRaw;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_cardHeight <= 0) return;
    final velocity = -d.velocity.pixelsPerSecond.dy / _cardHeight;
    final maxPage  = _n - 1;
    final int target;
    if (velocity > 1.2) {
      target = (_ctrl.value.floor() + 1).clamp(0, maxPage);
    } else if (velocity < -1.2) {
      target = (_ctrl.value.ceil() - 1).clamp(0, maxPage);
    } else {
      target = _ctrl.value.round().clamp(0, maxPage);
    }
    _ctrl.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 600, damping: 60),
      _ctrl.value,
      target.toDouble(),
      velocity,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs            = AppColorScheme.of(context);
    final color         = _mealColor(widget.slot);
    final today         = todayISO();
    final currentMacros = widget.ref.read(macroTotalsProvider(today));
    final goals         = widget.ref.read(settingsProvider).goalsForDate(today);
    final n             = widget.options.length;
    final p             = _ctrl.value;
    final activeDot     = p.round().clamp(0, n - 1);

    // Render back-to-front: furthest from active page drawn first (behind).
    // Equal-distance tie: more-negative rel card drawn first, so the incoming
    // card (positive rel approaching 0) always lands visually on top.
    final ordered = List.generate(n, (i) => i)
      ..sort((a, b) {
        final ra = a.toDouble() - p;
        final rb = b.toDouble() - p;
        final da = ra.abs(), db = rb.abs();
        if ((da - db).abs() > 1e-9) return db.compareTo(da);
        return rb.compareTo(ra);
      });

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (_, box) {
            // cardH fills availH minus the two peek strips so the deck sits
            // flush at page=0.  Floor at 80 dp for tiny screens.
            _cardHeight = max(80.0, box.maxHeight - _kPeekBelow1 - _kPeekBelow2);
            return GestureDetector(
              behavior:    HitTestBehavior.opaque,
              onPanStart:  _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd:    _onPanEnd,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final i in ordered)
                      _buildCard(i, box.maxHeight, currentMacros, goals),
                  ],
                ),
              ),
            );
          }),
        ),
        if (n > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(n, (i) {
              final active = i == activeDot;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve:    Curves.easeOut,
                margin:   const EdgeInsets.symmetric(horizontal: 3),
                width:    active ? 20 : 6,
                height:   6,
                decoration: BoxDecoration(
                  color:        active ? color : cs.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCard(
    int i,
    double availH,
    MacroValues currentMacros,
    MacroGoals goals,
  ) {
    final top = _topFor(i);
    if (top > availH + 4 || top + _cardHeight < -4) return const SizedBox.shrink();

    final absRel      = (i.toDouble() - _ctrl.value).abs().clamp(0.0, 1.0);
    final scale       = 1.0 - absRel * (1.0 - _kBackScale);
    final shadowBlur  = lerpDouble(20.0, 4.0,  absRel)!;
    final shadowAlpha = lerpDouble(0.12, 0.03, absRel)!;

    return Positioned(
      top:    top,
      left:   0,
      right:  0,
      height: _cardHeight,
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:        Colors.black.withValues(alpha: shadowAlpha),
                blurRadius:   shadowBlur,
                offset:       const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
          ),
          child: _MealSlotCard(
            meal:          widget.slot,
            insight:       widget.options[i],
            optionIdx:     i,
            optionCount:   widget.options.length,
            onViewDetail:  () => showMealDetailSheet(
                widget.parentContext, widget.ref, widget.options[i], i + 1),
            currentMacros: currentMacros,
            goals:         goals,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual meal option card — stateless, all navigation in _CardDeck
// ---------------------------------------------------------------------------

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.meal,
    required this.insight,
    required this.optionIdx,
    required this.optionCount,
    required this.onViewDetail,
    required this.currentMacros,
    required this.goals,
  });

  final String meal;
  final MealInsight insight;
  final int optionIdx;
  final int optionCount;
  final VoidCallback onViewDetail;
  final MacroValues currentMacros;
  final MacroGoals goals;

  @override
  Widget build(BuildContext context) {
    final cs    = AppColorScheme.of(context);
    final color = _mealColor(meal);
    final m     = insight.totalMacros;
    final names = insight.items.take(3).map((i) => i.food.name).join(', ');
    final extra = insight.items.length > 3
        ? ' +${insight.items.length - 3} more' : '';

    return GestureDetector(
      onTap: onViewDetail,
      child: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_mealIcon(meal), color: color, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  mealLabels[meal] ?? meal,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: cs.textPrimary,
                                  ),
                                ),
                              ),
                              if (optionCount > 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Option ${optionIdx + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _mealTagline(meal),
                            style: TextStyle(fontSize: 12, color: cs.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            names + extra,
                            style: TextStyle(fontSize: 12, color: cs.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(19)),
                ),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MacroDonut(
                      label: 'Protein',
                      addition: m.protein,
                      current: currentMacros.protein,
                      goal: goals.protein,
                      color: AppColors.protein,
                      unit: 'g',
                    ),
                    MacroDonut(
                      label: 'Carbs',
                      addition: m.carbs,
                      current: currentMacros.carbs,
                      goal: goals.carbs,
                      color: AppColors.carbs,
                      unit: 'g',
                    ),
                    MacroDonut(
                      label: 'Fat',
                      addition: m.fat,
                      current: currentMacros.fat,
                      goal: goals.fat,
                      color: AppColors.fat,
                      unit: 'g',
                    ),
                    MacroDonut(
                      label: 'Kcal',
                      addition: m.kcal,
                      current: currentMacros.kcal,
                      goal: goals.kcal,
                      color: cs.kcalColor,
                      unit: '',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColorScheme.of(context).textPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loggedDays});
  final int loggedDays;

  @override
  Widget build(BuildContext context) {
    final cs        = AppColorScheme.of(context);
    final remaining = (14 - loggedDays).clamp(0, 14);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 48, color: AppColors.kcal.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              loggedDays < 14 ? 'Almost there' : 'All meals logged today',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              loggedDays < 14
                  ? 'Log $remaining more day${remaining == 1 ? '' : 's'} to unlock Smart Insight'
                  : 'Come back tomorrow for your next suggestions',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: cs.textMuted, height: 1.4),
            ),
            if (loggedDays < 14) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loggedDays / 14,
                  minHeight: 6,
                  backgroundColor: cs.border,
                  color: AppColors.kcal,
                ),
              ),
              const SizedBox(height: 6),
              Text('$loggedDays / 14 days',
                  style: TextStyle(fontSize: 11, color: cs.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow();

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SequentialStarsSparkle(color: cs.smartInsightColor),
              const SizedBox(height: 10),
              const Text('What is Smart Insight?'),
            ],
          ),
          content: const Text(
            'Smart Insight analyses your past meals and suggests the best '
            'food combinations to close your remaining macro targets for today. '
            'It learns from your actual eating habits — the more you log, '
            'the smarter it gets.',
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: cs.textMuted),
            const SizedBox(width: 6),
            Text('What is Smart Insight?',
                style: TextStyle(fontSize: 12, color: cs.textMuted)),
          ],
        ),
      ),
    );
  }
}

// Meal detail sheet lives in smart_insight/meal_detail_sheet.dart
// Donut chart lives in smart_insight/macro_donut.dart
// Sparkle animations live in smart_insight/sparkle.dart
