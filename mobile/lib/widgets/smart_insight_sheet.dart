import 'package:flutter/material.dart';
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
                    Row(
                      children: [
                        _SpinningSparkle(size: 18, color: AppColors.kcal),
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
// Card carousel — H-swipe navigates meal slots, V-swipe navigates options
// ---------------------------------------------------------------------------

const _kPeek  = 28.0;  // horizontal: adjacent slot visible on each side
const _kPeekH = 72.0;  // vertical: how much of the next option card peeks below

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

class _CardDeckState extends State<_CardDeck> with TickerProviderStateMixin {
  // ── Slot (horizontal) ────────────────────────────────────────────────────
  int _slotIdx = 0;
  double _dragX = 0;
  double _hS = 0, _hE = 0;
  late final AnimationController _hCtrl;

  // ── Option (vertical) ────────────────────────────────────────────────────
  late List<int> _optIdxs;
  double _dragY = 0;
  double _vS = 0, _vE = 0;
  late final AnimationController _vCtrl;

  // ── Gesture direction lock ────────────────────────────────────────────────
  bool? _isHoriz;

  // ── Layout (set by LayoutBuilder each frame) ──────────────────────────────
  double _cardW  = 300;
  double _availH = 300; // full slot area height; card height = availH - (n-1)*kPeekH

  @override
  void initState() {
    super.initState();
    _optIdxs = List.filled(widget.slots.length, 0);

    _hCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _hCtrl.addListener(() {
      final t = Curves.easeOutCubic.transform(_hCtrl.value);
      setState(() => _dragX = _hS + (_hE - _hS) * t);
    });
    _hCtrl.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      setState(() {
        if (_hE < 0 && _slotIdx < widget.slots.length - 1) _slotIdx++;
        else if (_hE > 0 && _slotIdx > 0)                  _slotIdx--;
        _dragX = 0;
      });
    });

    _vCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _vCtrl.addListener(() {
      final t = Curves.easeOutCubic.transform(_vCtrl.value);
      setState(() => _dragY = _vS + (_vE - _vS) * t);
    });
    _vCtrl.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      setState(() {
        final cnt = widget.suggestions[widget.slots[_slotIdx]]!.length;
        final cur = _optIdxs[_slotIdx];
        if (_vE < 0 && cur < cnt - 1) _optIdxs[_slotIdx] = cur + 1;
        else if (_vE > 0 && cur > 0)  _optIdxs[_slotIdx] = cur - 1;
        _dragY = 0;
      });
    });
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  void _hTo(double t) { _hS = _dragX; _hE = t; _hCtrl..reset()..forward(); }
  void _vTo(double t) { _vS = _dragY; _vE = t; _vCtrl..reset()..forward(); }

  void _onPanStart(DragStartDetails _) {
    _isHoriz = null;
    if (_hCtrl.isAnimating) _hCtrl.stop();
    if (_vCtrl.isAnimating) _vCtrl.stop();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _isHoriz ??= d.delta.dx.abs() >= d.delta.dy.abs();
    if (_isHoriz!) setState(() => _dragX += d.delta.dx);
    else           setState(() => _dragY += d.delta.dy);
  }

  void _onPanEnd(DragEndDetails d) {
    final vx    = d.velocity.pixelsPerSecond.dx;
    final vy    = d.velocity.pixelsPerSecond.dy;
    final horiz = _isHoriz == true || (_isHoriz == null && vx.abs() >= vy.abs());
    _isHoriz = null;

    if (horiz) {
      if ((_dragX < -48 || vx < -500) && _slotIdx < widget.slots.length - 1) {
        _hTo(-_cardW);
      } else if ((_dragX > 48 || vx > 500) && _slotIdx > 0) {
        _hTo(_cardW);
      } else {
        _hTo(0);
      }
    } else {
      final cnt   = widget.suggestions[widget.slots[_slotIdx]]!.length;
      final cur   = _optIdxs[_slotIdx];
      final cardH = _availH - (cnt - 1) * _kPeekH;
      if ((_dragY < -48 || vy < -500) && cur < cnt - 1) {
        _vTo(-cardH);
      } else if ((_dragY > 48 || vy > 500) && cur > 0) {
        _vTo(cardH);
      } else {
        _vTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(builder: (_, box) {
            _cardW  = box.maxWidth  - 2 * _kPeek;
            _availH = box.maxHeight;
            return GestureDetector(
              onPanStart:  _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd:    _onPanEnd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int si = 0; si < widget.slots.length; si++)
                    _buildSlot(context, si),
                ],
              ),
            );
          }),
        ),
        if (widget.slots.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.slots.length, (i) {
              final active = i == _slotIdx;
              final color  = _mealColor(widget.slots[i]);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? color : cs.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
        const _InfoRow(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSlot(BuildContext context, int si) {
    final left = _kPeek + (si - _slotIdx) * _cardW + _dragX;
    final cW   = 2 * _kPeek + _cardW;
    if (left >= cW + 4 || left + _cardW <= -4) return const SizedBox.shrink();

    final slot   = widget.slots[si];
    final opts   = widget.suggestions[slot]!;
    final n      = opts.length;
    final curOpt = _optIdxs[si];
    final dy     = si == _slotIdx ? _dragY : 0.0;
    // Front card fills the space; each additional option adds one kPeekH peek
    final cardH  = _availH - (n - 1) * _kPeekH;

    return Positioned(
      left: left,
      top: 0,
      width: _cardW,
      height: _availH,
      child: ClipRect(
        child: Stack(
          // Render back-to-front: lowest oi painted last = highest z-order
          children: [
            for (int oi = n - 1; oi >= 0; oi--)
              _buildWalletCard(oi, curOpt, cardH, dy, slot, opts),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(
      int oi, int curOpt, double cardH, double dy,
      String slot, List<MealInsight> opts) {
    final top = (oi - curOpt) * cardH + dy;
    if (top >= _availH + 4 || top + cardH <= -4) return const SizedBox.shrink();

    final insight = opts[oi];
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: cardH,
      child: _MealSlotCard(
        meal: slot,
        insight: insight,
        optionIdx: oi,
        optionCount: opts.length,
        onViewDetail: () =>
            _showMealDetailSheet(widget.parentContext, widget.ref, insight),
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
  });

  final String meal;
  final MealInsight insight;
  final int optionIdx;
  final int optionCount;
  final VoidCallback onViewDetail;

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
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(_mealIcon(meal), color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mealLabels[meal] ?? meal,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: cs.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mealTagline(meal),
                            style: TextStyle(fontSize: 12, color: cs.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            names + extra,
                            style: TextStyle(fontSize: 12, color: cs.textMuted),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: color.withValues(alpha: 0.7), size: 20),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(19)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    _MacroPill('P', '${m.protein.round()}g', AppColors.protein),
                    const SizedBox(width: 10),
                    _MacroPill('C', '${m.carbs.round()}g', AppColors.carbs),
                    const SizedBox(width: 10),
                    _MacroPill('F', '${m.fat.round()}g', AppColors.fat),
                    const Spacer(),
                    Text(
                      '${m.kcal.round()} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.kcalColor,
                      ),
                    ),
                    if (optionCount > 1) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${optionIdx + 1}/$optionCount',
                        style: TextStyle(fontSize: 10, color: cs.textMuted),
                      ),
                    ],
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
              _PulsingSparkle(size: 36, color: AppColors.kcal),
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

// ---------------------------------------------------------------------------
// Meal detail sheet
// ---------------------------------------------------------------------------

void _showMealDetailSheet(
  BuildContext context,
  WidgetRef ref,
  MealInsight insight,
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
      child: _MealDetailSheet(insight: insight, parentContext: context),
    ),
  );
}

class _MealDetailSheet extends ConsumerStatefulWidget {
  const _MealDetailSheet({
    required this.insight,
    required this.parentContext,
  });
  final MealInsight insight;
  final BuildContext parentContext;

  @override
  ConsumerState<_MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<_MealDetailSheet> {
  bool _logging = false;

  Future<void> _logAll() async {
    setState(() => _logging = true);
    final today    = todayISO();
    final notifier = ref.read(entriesProvider(today).notifier);
    bool allOk = true;
    for (final item in widget.insight.items) {
      final ok = await notifier.addEntry(
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
    final m     = widget.insight.totalMacros;

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
                Text(
                  mealLabels[widget.insight.meal] ?? widget.insight.meal,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.border),
          // Food list + macro summary
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: widget.insight.items.length + 1,
              separatorBuilder: (_, i) =>
                  i < widget.insight.items.length - 1
                      ? Divider(height: 24, color: cs.border)
                      : const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                if (i == widget.insight.items.length) {
                  return _MacroSummaryRow(macros: m, color: color);
                }
                final item = widget.insight.items[i];
                final im   = item.macros;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            _SmallPill(
                                'C ${im.carbs.round()}g', AppColors.carbs),
                            const SizedBox(width: 6),
                            _SmallPill('F ${im.fat.round()}g', AppColors.fat),
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
                            style: TextStyle(
                                fontSize: 12, color: cs.kcalColor)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Macro impact preview
          _MacroImpactSection(suggestion: widget.insight.totalMacros),
          // Log button
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: _logging ? null : _logAll,
              child: _logging
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Log ${mealLabels[widget.insight.meal] ?? widget.insight.meal}'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro impact section — shows current progress + what this meal would add
// ---------------------------------------------------------------------------

class _MacroImpactSection extends ConsumerWidget {
  const _MacroImpactSection({required this.suggestion});
  final MacroValues suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs      = AppColorScheme.of(context);
    final today   = todayISO();
    final current = ref.watch(macroTotalsProvider(today));
    final goals   = ref.read(settingsProvider).goalsForDate(today);

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
          const SizedBox(height: 12),
          _ImpactBar(
            label: 'Protein',
            current: current.protein,
            addition: suggestion.protein,
            goal: goals.protein,
            color: AppColors.protein,
            unit: 'g',
          ),
          const SizedBox(height: 10),
          _ImpactBar(
            label: 'Carbs',
            current: current.carbs,
            addition: suggestion.carbs,
            goal: goals.carbs,
            color: AppColors.carbs,
            unit: 'g',
          ),
          const SizedBox(height: 10),
          _ImpactBar(
            label: 'Fat',
            current: current.fat,
            addition: suggestion.fat,
            goal: goals.fat,
            color: AppColors.fat,
            unit: 'g',
          ),
          const SizedBox(height: 10),
          _ImpactBar(
            label: 'Calories',
            current: current.kcal,
            addition: suggestion.kcal,
            goal: goals.kcal,
            color: AppColorScheme.of(context).kcalColor,
            unit: ' kcal',
          ),
        ],
      ),
    );
  }
}

class _ImpactBar extends StatelessWidget {
  const _ImpactBar({
    required this.label,
    required this.current,
    required this.addition,
    required this.goal,
    required this.color,
    required this.unit,
  });

  final String label;
  final double current;
  final double addition;
  final double goal;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final cs             = AppColorScheme.of(context);
    final projected      = current + addition;
    final currentRatio   = goal > 0 ? (current   / goal).clamp(0.0, 1.0) : 0.0;
    final projectedRatio = goal > 0 ? (projected / goal).clamp(0.0, 1.0) : 0.0;
    final addRatio       = projectedRatio - currentRatio;
    final overGoal       = projected > goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.textMuted)),
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '+${addition.round()}$unit  ',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '→ ${projected.round()} / ${goal.round()}$unit',
                    style: TextStyle(fontSize: 11, color: cs.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  children: [
                    // Background track
                    Container(color: cs.border),
                    // Current portion (muted)
                    Positioned(
                      left: 0,
                      child: Container(
                        width: currentRatio * w,
                        height: 7,
                        color: color.withValues(alpha: 0.40),
                      ),
                    ),
                    // Addition portion (full color)
                    Positioned(
                      left: currentRatio * w,
                      child: Container(
                        width: addRatio * w,
                        height: 7,
                        color: overGoal
                            ? AppColors.danger.withValues(alpha: 0.8)
                            : color,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
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

// ---------------------------------------------------------------------------
// Animated sparkle icons
// ---------------------------------------------------------------------------

/// Slow continuous 360° rotation — used in the main sheet header.
class _SpinningSparkle extends StatefulWidget {
  const _SpinningSparkle({required this.size, required this.color});
  final double size;
  final Color  color;

  @override
  State<_SpinningSparkle> createState() => _SpinningSparkleState();
}

class _SpinningSparkleState extends State<_SpinningSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _ctrl,
        child: Icon(Icons.auto_awesome_rounded,
            size: widget.size, color: widget.color),
      );
}

/// Gentle scale + opacity breathe — used in the "What is Smart Insight?" dialog.
class _PulsingSparkle extends StatefulWidget {
  const _PulsingSparkle({required this.size, required this.color});
  final double size;
  final Color  color;

  @override
  State<_PulsingSparkle> createState() => _PulsingSparkleState();
}

class _PulsingSparkleState extends State<_PulsingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scale   = Tween<double>(begin: 1.0,  end: 1.15).animate(curve);
    _opacity = Tween<double>(begin: 0.70, end: 1.0 ).animate(curve);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: FadeTransition(
          opacity: _opacity,
          child: Icon(Icons.auto_awesome_rounded,
              size: widget.size, color: widget.color),
        ),
      );
}

