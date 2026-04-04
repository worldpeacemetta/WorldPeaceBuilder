import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../models/food.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/add_entry_sheet.dart';
import '../../widgets/macro_progress_card.dart';
import '../../widgets/mode_pill.dart';
import '../daily_log/daily_log_screen.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class DayDetailScreen extends ConsumerStatefulWidget {
  final String date;
  const DayDetailScreen({super.key, required this.date});

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _topFoodsMacro = 'kcal';
  static const _pageCount = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entriesProvider(widget.date));
    final entries = entriesAsync.valueOrNull ?? [];
    final goals = ref.watch(settingsProvider).goalsForDate(widget.date);
    final totals = MacroValues.sum(entries.map((e) => e.macros));

    final entriesByMeal = <String, List<Entry>>{};
    for (final meal in mealOrder) {
      final list = entries.where((e) => e.meal == meal).toList();
      if (list.isNotEmpty) entriesByMeal[meal] = list;
    }

    final cs = AppColorScheme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: cs.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDateFull(widget.date),
                    style: TextStyle(
                        color: cs.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                ModePill(date: widget.date),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_outlined, color: cs.textPrimary),
                onPressed: () =>
                    showAddEntrySheet(context, ref, widget.date),
              ),
            ],
          ),

          // ── Swipeable chart panels ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 340,
                  child: PageView(
                    controller: _pageController,
                    scrollBehavior: const ScrollBehavior().copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                        }),
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    children: [
                      // 1 — Macro breakdown donuts
                      MacroProgressCard(totals: totals, goals: goals),
                      // 2 — Meal breakdown (stacked bar + rows)
                      _MealBreakdownPanel(entries: entries),
                      // 3 — Top foods by macro
                      _TopFoodsPanel(
                        entries: entries,
                        macro: _topFoodsMacro,
                        onMacroChanged: (m) =>
                            setState(() => _topFoodsMacro = m),
                      ),
                      // 4 — Macro split: today vs target
                      _MacroSplitPanel(totals: totals, goals: goals),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pageCount, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentPage ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? cs.textPrimary
                            : cs.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Meal tables ──────────────────────────────────────────────────
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No entries for this day',
                      style: TextStyle(color: cs.textMuted)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final meal = mealOrder
                      .where((m) => entriesByMeal.containsKey(m))
                      .toList()[index];
                  final mealEntries = entriesByMeal[meal]!;
                  final mt = MacroValues.sum(mealEntries.map((e) => e.macros));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Meal header ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: cs.border.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_mealEmoji(meal)}  ${(mealLabels[meal] ?? meal).toUpperCase()}',
                              style: TextStyle(
                                color: cs.textMuted,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            // All 4 macro totals
                            _MealHeaderMacros(macros: mt),
                          ],
                        ),
                      ),
                      ...mealEntries.map((entry) =>
                          _DetailEntryTile(entry: entry, date: widget.date)),
                      Divider(height: 1, color: cs.border),
                    ],
                  );
                },
                childCount: entriesByMeal.length,
              ),
            ),
        ],
      ),
    );
  }
}

String _mealEmoji(String meal) => const {
      'breakfast': '🌅',
      'lunch': '☀️',
      'dinner': '🌙',
      'snack': '🍎',
      'other': '🍽️',
    }[meal] ??
    '🍽️';

// ---------------------------------------------------------------------------
// Meal header macro summary
// ---------------------------------------------------------------------------
class _MealHeaderMacros extends StatelessWidget {
  const _MealHeaderMacros({required this.macros});
  final MacroValues macros;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _M('K', macros.kcal.round(), AppColors.kcal),
        const SizedBox(width: 6),
        _M('P', macros.protein.round(), AppColors.protein),
        const SizedBox(width: 6),
        _M('C', macros.carbs.round(), AppColors.carbs),
        const SizedBox(width: 6),
        _M('F', macros.fat.round(), AppColors.fat),
      ],
    );
  }

  Widget _M(String label, int value, Color color) => Text(
        '$label$value',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      );
}

// ---------------------------------------------------------------------------
// Chart 2 — Meal breakdown: stacked bar + compact rows
// ---------------------------------------------------------------------------
const _mealColors = {
  'breakfast': Color(0xFFFFB347),
  'lunch': AppColors.protein,
  'dinner': AppColors.kcal,
  'snack': AppColors.carbs,
  'other': AppColors.fat,
};

class _MealBreakdownPanel extends StatelessWidget {
  const _MealBreakdownPanel({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final mealTotals = <String, MacroValues>{};
    for (final meal in mealOrder) {
      final items = entries.where((e) => e.meal == meal).toList();
      if (items.isEmpty) continue;
      mealTotals[meal] = MacroValues.sum(items.map((e) => e.macros));
    }
    if (mealTotals.isEmpty) {
      return Center(
          child: Text('No meals logged',
              style: TextStyle(color: cs.textMuted)));
    }
    final totalKcal = mealTotals.values.fold(0.0, (s, m) => s + m.kcal);

    return Container(
      color: cs.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stacked proportion bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 7,
              child: Row(
                children: mealTotals.entries.map((e) {
                  final flex = totalKcal > 0
                      ? ((e.value.kcal / totalKcal) * 1000).round()
                      : 0;
                  return Flexible(
                    flex: flex,
                    child: Container(
                        color: _mealColors[e.key] ?? AppColors.kcal),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Meal rows
          ...mealTotals.entries.map((e) {
            final color = _mealColors[e.key] ?? AppColors.kcal;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                      width: 5, height: 5,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text(_mealEmoji(e.key),
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(mealLabels[e.key] ?? e.key,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  Text('${e.value.kcal.round()}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(' kcal',
                      style:
                          TextStyle(fontSize: 11, color: cs.textMuted)),
                  const SizedBox(width: 8),
                  Text(
                      'P${e.value.protein.round()} C${e.value.carbs.round()} F${e.value.fat.round()}',
                      style: TextStyle(
                          fontSize: 10, color: cs.textMuted)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart 3 — Top foods (unchanged)
// ---------------------------------------------------------------------------
class _TopFoodsPanel extends StatelessWidget {
  const _TopFoodsPanel({
    required this.entries,
    required this.macro,
    required this.onMacroChanged,
  });
  final List<Entry> entries;
  final String macro;
  final ValueChanged<String> onMacroChanged;

  double _macroValue(MacroValues m) => switch (macro) {
        'protein' => m.protein,
        'carbs' => m.carbs,
        'fat' => m.fat,
        _ => m.kcal,
      };

  Color get _color => switch (macro) {
        'protein' => AppColors.protein,
        'carbs' => AppColors.carbs,
        'fat' => AppColors.fat,
        _ => AppColors.kcal,
      };

  String get _unit => macro == 'kcal' ? 'kcal' : 'g';

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((a, b) =>
          _macroValue(b.macros).compareTo(_macroValue(a.macros)));
    final top3 = sorted.take(3).toList();
    final maxVal = top3.isNotEmpty ? _macroValue(top3.first.macros) : 1.0;
    const keys = ['kcal', 'protein', 'carbs', 'fat'];
    const labels = ['Cal', 'Pro', 'Carb', 'Fat'];
    const colors = <Color>[
      AppColors.kcal, AppColors.protein, AppColors.carbs, AppColors.fat
    ];

    final cs = AppColorScheme.of(context);

    return Container(
      color: cs.card,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          // Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final sel = keys[i] == macro;
              return GestureDetector(
                onTap: () => onMacroChanged(keys[i]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: sel
                        ? colors[i].withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? colors[i] : cs.border),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                        color: sel ? colors[i] : cs.textMuted,
                        fontSize: 11,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.normal,
                      )),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          ...top3.map((entry) {
            final val = _macroValue(entry.macros);
            final share =
                maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.food?.name ?? entry.foodId,
                          style: TextStyle(
                              color: cs.textPrimary,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${val.round()} $_unit',
                          style: TextStyle(
                              color: _color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 3,
                      backgroundColor: cs.border,
                      valueColor: AlwaysStoppedAnimation<Color>(_color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart 4 — Macro split: today's P/C/F % vs target
// ---------------------------------------------------------------------------
class _MacroSplitPanel extends StatelessWidget {
  const _MacroSplitPanel({required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  // kcal per gram
  static const _pFactor = 4.0;
  static const _cFactor = 4.0;
  static const _fFactor = 9.0;

  List<double> _splitKcal(double p, double c, double f) {
    final pk = p * _pFactor;
    final ck = c * _cFactor;
    final fk = f * _fFactor;
    final total = pk + ck + fk;
    if (total <= 0) return [1, 1, 1];
    return [pk / total, ck / total, fk / total];
  }

  @override
  Widget build(BuildContext context) {
    final actual = _splitKcal(totals.protein, totals.carbs, totals.fat);
    final target = _splitKcal(goals.protein, goals.carbs, goals.fat);
    const colors = [AppColors.protein, AppColors.carbs, AppColors.fat];
    const names = ['Protein', 'Carbs', 'Fat'];

    Widget bar(List<double> fracs) => ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: List.generate(3, (i) {
                final flex = (fracs[i] * 1000).round();
                return Flexible(
                    flex: flex,
                    child: Container(color: colors[i]));
              }),
            ),
          ),
        );

    final cs = AppColorScheme.of(context);

    return Container(
      color: cs.card,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macro Split  ·  % of calories',
              style:
                  TextStyle(fontSize: 11, color: cs.textMuted)),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                  width: 46,
                  child: Text('Today',
                      style: TextStyle(
                          fontSize: 10, color: cs.textMuted))),
              Expanded(child: bar(actual)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                  width: 46,
                  child: Text('Target',
                      style: TextStyle(
                          fontSize: 10, color: cs.textMuted))),
              Expanded(child: bar(target)),
            ],
          ),
          const SizedBox(height: 14),
          // Legend row
          Row(
            children: List.generate(3, (i) {
              final aPct = (actual[i] * 100).round();
              final tPct = (target[i] * 100).round();
              final diff = aPct - tPct;
              final diffStr =
                  diff == 0 ? '=' : (diff > 0 ? '+$diff%' : '$diff%');
              final diffColor = diff == 0
                  ? cs.textMuted
                  : (diff > 0 ? AppColors.protein : AppColors.carbs);
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                              color: colors[i],
                              shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(names[i],
                          style: TextStyle(
                              fontSize: 9,
                              color: cs.textMuted)),
                    ]),
                    const SizedBox(height: 2),
                    Text('$aPct% today',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors[i])),
                    Text('$tPct% goal  $diffStr',
                        style: TextStyle(
                            fontSize: 9, color: diffColor)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entry tile — emoji leading, formatted qty, inline colored macros
// ---------------------------------------------------------------------------
class _DetailEntryTile extends ConsumerStatefulWidget {
  final Entry entry;
  final String date;
  const _DetailEntryTile({required this.entry, required this.date});

  @override
  ConsumerState<_DetailEntryTile> createState() => _DetailEntryTileState();
}

class _DetailEntryTileState extends ConsumerState<_DetailEntryTile>
    with SingleTickerProviderStateMixin {
  static const _revealWidth = 144.0;
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    _open ? _ctrl.reverse() : _ctrl.forward();
    _open = !_open;
  }

  void _close() {
    if (_open) {
      _ctrl.reverse();
      _open = false;
    }
  }

  Future<void> _delete() async {
    _close();
    final cs = AppColorScheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.card,
        title: Text('Delete Entry',
            style: TextStyle(color: cs.textPrimary)),
        content: Text('Remove this food from the log?',
            style: TextStyle(color: cs.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: cs.textMuted))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref
          .read(entriesProvider(widget.date).notifier)
          .deleteEntry(widget.entry.id);
    }
  }

  String _fmtQty() {
    final food = widget.entry.food;
    final n = widget.entry.qty % 1 == 0
        ? widget.entry.qty.toInt().toString()
        : widget.entry.qty.toStringAsFixed(1);
    if (food?.unit == 'per100g') return '${n}g';
    return '$n serving${widget.entry.qty == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final macros = widget.entry.macros;
    final food = widget.entry.food;
    final emoji = categoryEmojis[food?.category] ?? '🍽️';

    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        if (d.delta.dx < -4 && !_open) _toggle();
        if (d.delta.dx > 4 && _open) _toggle();
      },
      onTap: _close,
      child: AnimatedBuilder(
        animation: _slideAnim,
        builder: (_, __) {
          final offset = -_revealWidth * _slideAnim.value;
          return Stack(
            children: [
              Positioned(
                right: 0, top: 0, bottom: 0,
                child: _MorphButtons(
                  progress: _slideAnim.value,
                  onEdit: () {
                    _close();
                    showEditEntrySheet(
                        context, ref, widget.entry, widget.date);
                  },
                  onDelete: _delete,
                ),
              ),
              Transform.translate(
                offset: Offset(offset, 0),
                child: Container(
                  color: cs.card,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Category emoji
                      Text(emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      // Name + qty + macro chips
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food?.name ?? widget.entry.foodId,
                              style: TextStyle(
                                  color: cs.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(_fmtQty(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: cs.textMuted)),
                                Text('  ·  ',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: cs.textMuted)),
                                _MC('K', macros.kcal.round(),
                                    AppColors.kcal),
                                const SizedBox(width: 5),
                                _MC('P', macros.protein.round(),
                                    AppColors.protein, 'g'),
                                const SizedBox(width: 5),
                                _MC('C', macros.carbs.round(),
                                    AppColors.carbs, 'g'),
                                const SizedBox(width: 5),
                                _MC('F', macros.fat.round(),
                                    AppColors.fat, 'g'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _MC(String label, int value, Color color, [String unit = '']) =>
    Text('$label$value$unit',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color));

// ── Morph buttons (circle → rectangle) ───────────────────────────────────────

class _MorphButtons extends StatelessWidget {
  const _MorphButtons(
      {required this.progress, required this.onEdit, required this.onDelete});
  final double progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    const fullW = 72.0;
    const circleD = 44.0;
    final btnW = _lerp(circleD, fullW, progress);
    final radius = _lerp(circleD / 2, 5.0, progress);
    final labelOpacity = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
    final pad = _lerp(8.0, 0.0, progress);

    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MorphBtn(
                width: btnW, radius: radius, color: AppColors.protein,
                icon: Icons.edit_outlined, label: 'Edit',
                labelOpacity: labelOpacity, onTap: onEdit),
            SizedBox(width: _lerp(6.0, 0.0, progress)),
            _MorphBtn(
                width: btnW, radius: radius, color: AppColors.danger,
                icon: Icons.delete_outline, label: 'Delete',
                labelOpacity: labelOpacity, onTap: onDelete),
          ],
        ),
      ),
    );
  }
}

class _MorphBtn extends StatelessWidget {
  const _MorphBtn({
    required this.width, required this.radius, required this.color,
    required this.icon, required this.label, required this.labelOpacity,
    required this.onTap,
  });
  final double width, radius, labelOpacity;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(radius)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (labelOpacity > 0) ...[
              const SizedBox(height: 3),
              Opacity(
                opacity: labelOpacity,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
