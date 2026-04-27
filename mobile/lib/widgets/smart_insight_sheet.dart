import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils.dart';
import '../models/entry.dart';
import '../models/food.dart';
import '../providers/date_provider.dart';
import '../providers/entries_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/smart_insight_provider.dart';
import '../theme.dart';

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
                    Text('Smart Insight',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
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
const _kPeekAbove  = 20.0;
/// How much the first behind-below card peeks below the active card.
const _kPeekBelow1 = 32.0;
/// How much the second behind-below card peeks below the first behind card.
const _kPeekBelow2 = 20.0;
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
            key:           ValueKey('slot_$_slotIndex'),
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
  ///   rel ≤ 0  — active / previous: bottom edge sits at activeTop, peek strip
  ///              visible at the top edge of the container.
  ///   0 < rel ≤ 1 — first below: smooth lerp from active pos to first-peek pos.
  ///   rel > 1  — deeper below: each card adds kPeekBelow2 of visible strip.
  ///
  /// Setting kPeekAbove == kPeekBelow2 keeps total deck height == availH for
  /// every active page, so the ClipRect never cuts off a visible peek strip.
  double _topFor(int i) {
    final p         = _ctrl.value;
    final rel       = i.toDouble() - p;
    // Shift active card down by kPeekAbove once a previous card exists (p ≥ 1).
    final activeTop = p.clamp(0.0, 1.0) * _kPeekAbove;

    if (rel <= 0) {
      return activeTop + rel * _cardHeight;
    } else if (rel <= 1) {
      return activeTop + rel * (_cardHeight - _kPeekBelow1);
    } else {
      return activeTop + (_cardHeight - _kPeekBelow1) + (rel - 1) * _kPeekBelow2;
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
    // Swipe DOWN (dy > 0) → page increases → next card rises to front.
    _dragRaw += d.delta.dy / _cardHeight;
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
    final velocity = d.velocity.pixelsPerSecond.dy / _cardHeight;
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
            onViewDetail:  () => _showMealDetailSheet(
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
                    _MacroDonut(
                      label: 'Protein',
                      addition: m.protein,
                      current: currentMacros.protein,
                      goal: goals.protein,
                      color: AppColors.protein,
                      unit: 'g',
                    ),
                    _MacroDonut(
                      label: 'Carbs',
                      addition: m.carbs,
                      current: currentMacros.carbs,
                      goal: goals.carbs,
                      color: AppColors.carbs,
                      unit: 'g',
                    ),
                    _MacroDonut(
                      label: 'Fat',
                      addition: m.fat,
                      current: currentMacros.fat,
                      goal: goals.fat,
                      color: AppColors.fat,
                      unit: 'g',
                    ),
                    _MacroDonut(
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
          title: const Text('What is Smart Insight?'),
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

// ---------------------------------------------------------------------------
// Meal detail sheet
// ---------------------------------------------------------------------------

void _showMealDetailSheet(
  BuildContext context,
  WidgetRef ref,
  MealInsight insight,
  int optionNumber,
) {
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
      child: _MealDetailSheet(
          insight: insight,
          parentContext: context,
          optionNumber: optionNumber),
    ),
  );
}

class _MealDetailSheet extends ConsumerStatefulWidget {
  const _MealDetailSheet({
    required this.insight,
    required this.parentContext,
    required this.optionNumber,
  });
  final MealInsight insight;
  final BuildContext parentContext;
  final int optionNumber;

  @override
  ConsumerState<_MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<_MealDetailSheet> {
  bool _logging = false;
  late Set<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    _selectedIndices = Set<int>.from(
        Iterable.generate(widget.insight.items.length));
  }

  MacroValues get _selectedMacros => MacroValues.sum(
      _selectedIndices.map((i) => widget.insight.items[i].macros));

  Future<void> _logAll() async {
    setState(() => _logging = true);
    final today    = todayISO();
    final notifier = ref.read(entriesProvider(today).notifier);
    bool allOk = true;
    final indices  = _selectedIndices.toList()..sort();
    for (final i in indices) {
      final item = widget.insight.items[i];
      final ok   = await notifier.addEntry(
        foodId: item.food.id,
        qty: item.qty,
        meal: widget.insight.meal,
      );
      if (!ok) allOk = false;
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(widget.parentContext);
      setAllDates(ref, today);
      Navigator.pop(context);
      if (!allOk) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Some items failed to log')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs    = AppColorScheme.of(context);
    final color = _mealColor(widget.insight.meal);
    final n     = widget.insight.items.length;
    final sel   = _selectedIndices.length;

    final String buttonLabel;
    if (_logging) {
      buttonLabel = '';
    } else if (sel == 0) {
      buttonLabel = 'Select items to log';
    } else if (sel == n) {
      buttonLabel = 'Log ${mealLabels[widget.insight.meal] ?? widget.insight.meal}';
    } else {
      buttonLabel = 'Log $sel item${sel == 1 ? '' : 's'}';
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_mealIcon(widget.insight.meal),
                      color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        mealLabels[widget.insight.meal] ?? widget.insight.meal,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Option ${widget.optionNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.border),
          // Food list
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: n,
              separatorBuilder: (_, i) =>
                  Divider(height: 24, color: cs.border),
              itemBuilder: (ctx, i) {
                final item     = widget.insight.items[i];
                final im       = item.macros;
                final selected = _selectedIndices.contains(i);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedIndices.remove(i);
                    } else {
                      _selectedIndices.add(i);
                    }
                  }),
                  child: AnimatedOpacity(
                    opacity: selected ? 1.0 : 0.38,
                    duration: const Duration(milliseconds: 180),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Selection indicator
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              key: ValueKey(selected),
                              size: 20,
                              color: selected ? color : cs.border,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.food.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.textPrimary)),
                              if (item.food.brand != null)
                                Text(item.food.brand!,
                                    style: TextStyle(
                                        fontSize: 12, color: cs.textMuted)),
                              const SizedBox(height: 4),
                              Row(children: [
                                _SmallPill('P ${im.protein.round()}g',
                                    AppColors.protein),
                                const SizedBox(width: 6),
                                _SmallPill('C ${im.carbs.round()}g',
                                    AppColors.carbs),
                                const SizedBox(width: 6),
                                _SmallPill(
                                    'F ${im.fat.round()}g', AppColors.fat),
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _qtyLabel(item.food.unit, item.qty),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.textPrimary),
                            ),
                            Text('${im.kcal.round()} kcal',
                                style:
                                    TextStyle(fontSize: 12, color: cs.kcalColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Macro impact — driven by selected items only
          _DonutImpactSection(suggestion: _selectedMacros),
          // Log button
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: (_logging || sel == 0) ? null : _logAll,
              child: _logging
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro impact section — donut view, matches carousel card style
// ---------------------------------------------------------------------------

class _DonutImpactSection extends ConsumerWidget {
  const _DonutImpactSection({required this.suggestion});
  final MacroValues suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs      = AppColorScheme.of(context);
    final today   = todayISO();
    final current = ref.watch(macroTotalsProvider(today));
    final goals   = ref.read(settingsProvider).goalsForDate(today);
    final m       = suggestion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 24, color: cs.border),
          Text(
            'Macro impact',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MacroDonut(
                label: 'Protein',
                addition: m.protein,
                current: current.protein,
                goal: goals.protein,
                color: AppColors.protein,
                unit: 'g',
                size: 76.0,
              ),
              _MacroDonut(
                label: 'Carbs',
                addition: m.carbs,
                current: current.carbs,
                goal: goals.carbs,
                color: AppColors.carbs,
                unit: 'g',
                size: 76.0,
              ),
              _MacroDonut(
                label: 'Fat',
                addition: m.fat,
                current: current.fat,
                goal: goals.fat,
                color: AppColors.fat,
                unit: 'g',
                size: 76.0,
              ),
              _MacroDonut(
                label: 'Kcal',
                addition: m.kcal,
                current: current.kcal,
                goal: goals.kcal,
                color: AppColorScheme.of(context).kcalColor,
                unit: '',
                size: 76.0,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro summary row (detail sheet footer)
// ---------------------------------------------------------------------------

class _MacroSummaryRow extends StatelessWidget {
  const _MacroSummaryRow({required this.macros, required this.color});
  final MacroValues macros;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryMacro('Protein', '${macros.protein.round()}g',
              AppColors.protein),
          _SummaryMacro('Carbs', '${macros.carbs.round()}g', AppColors.carbs),
          _SummaryMacro('Fat', '${macros.fat.round()}g', AppColors.fat),
          _SummaryMacro(
              'Calories', '${macros.kcal.round()}', cs.kcalColor),
        ],
      ),
    );
  }
}

class _SummaryMacro extends StatelessWidget {
  const _SummaryMacro(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColorScheme.of(context).textMuted)),
        ],
      );
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w500));
}

// ---------------------------------------------------------------------------
// Donut chart — shows current macro fill + projected addition
// ---------------------------------------------------------------------------

class _MacroDonut extends StatelessWidget {
  const _MacroDonut({
    required this.label,
    required this.addition,
    required this.current,
    required this.goal,
    required this.color,
    required this.unit,
    this.size = 58.0,
  });

  final String label;
  final double addition;
  final double current;
  final double goal;
  final Color color;
  final String unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs        = AppColorScheme.of(context);
    final projected = current + addition;
    final overGoal  = goal > 0 && projected > goal;
    final addStr    = '+${addition.round()}$unit';
    final totalStr  = goal > 0
        ? '${projected.round()}/${goal.round()}'
        : '${projected.round()}';

    final innerFont = (size * 9 / 58).floorToDouble();
    final labelFont = (size * 8 / 58).floorToDouble();
    final stroke    = size * 5 / 58;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          // Soft red glow on overshoot — keeps macro color intact,
          // two shadow layers fade the warning outward.
          decoration: overGoal
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.10),
                      blurRadius: 20,
                      spreadRadius: 6,
                    ),
                  ],
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _DonutPainter(
                  current: current,
                  addition: addition,
                  goal: goal,
                  color: color,
                  strokeWidth: stroke,
                ),
              ),
              Text(
                addStr,
                style: TextStyle(
                  fontSize: innerFont,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: labelFont,
            fontWeight: FontWeight.w600,
            color: cs.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          totalStr,
          style: TextStyle(fontSize: labelFont, color: cs.textMuted),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.current,
    required this.addition,
    required this.goal,
    required this.color,
    this.strokeWidth = 5.0,
  });

  final double current;
  final double addition;
  final double goal;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (goal <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final stroke = strokeWidth;
    const start   = -pi / 2;
    const full    = pi * 2;

    final bg = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color       = color.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, bg);

    final currentFrac   = (current / goal).clamp(0.0, 1.0);
    final projectedFrac = ((current + addition) / goal).clamp(0.0, 1.0);
    final currentSweep  = currentFrac * full;
    final addSweep      = (projectedFrac - currentFrac) * full;
    final rect          = Rect.fromCircle(center: center, radius: radius);

    if (currentSweep > 0.01) {
      canvas.drawArc(
        rect, start, currentSweep, false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap   = StrokeCap.butt
          ..color       = color.withValues(alpha: 0.38),
      );
    }
    if (addSweep > 0.01) {
      canvas.drawArc(
        rect, start + currentSweep, addSweep, false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap   = StrokeCap.butt
          ..color       = color,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.current     != current     ||
      old.addition    != addition    ||
      old.goal        != goal        ||
      old.color       != color       ||
      old.strokeWidth != strokeWidth;
}
