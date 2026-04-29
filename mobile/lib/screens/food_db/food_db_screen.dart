import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/food.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/foods_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/add_entry_sheet.dart';
import '../../widgets/add_food_sheet.dart';
import '../../widgets/barcode_scanner_sheet.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class FoodDbScreen extends ConsumerStatefulWidget {
  const FoodDbScreen({super.key});

  @override
  ConsumerState<FoodDbScreen> createState() => _FoodDbScreenState();
}

class _FoodDbScreenState extends ConsumerState<FoodDbScreen> {
  String _search = '';
  String? _categoryFilter;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logDate    = todayISO();
    final totals     = ref.watch(macroTotalsProvider(logDate));
    final goals      = ref.watch(settingsProvider).goalsForDate(logDate);
    final foodsAsync = ref.watch(foodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(foodsProvider.notifier).fetch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Four-macro pill bar ──────────────────────────────────────────
          _FourMacroBar(totals: totals, goals: goals),

          // ── Action bar ────────────────────────────────────────────────────
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search foods…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _showSearch = false;
                      _search = '';
                      _searchCtrl.clear();
                    }),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.qr_code_scanner_outlined,
                      label: 'Scan',
                      onTap: () async {
                        final result =
                            await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const BarcodeScannerSheet(),
                        );
                        if (result == null || !mounted) return;
                        showAddFoodSheet(context, ref, scannedData: result);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.add_rounded,
                      label: 'New Food',
                      onTap: () => showAddFoodSheet(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: () => setState(() => _showSearch = true),
                    ),
                  ),
                ],
              ),
            ),

          // ── Category chips ────────────────────────────────────────────────
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _categoryFilter == null,
                  onTap: () => setState(() => _categoryFilter = null),
                ),
                ...foodCategories.map((cat) => _CategoryChip(
                      label:
                          '${categoryEmojis[cat] ?? ''} ${categoryLabels[cat] ?? cat}',
                      selected: _categoryFilter == cat,
                      onTap: () => setState(() => _categoryFilter =
                          _categoryFilter == cat ? null : cat),
                    )),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Food list ─────────────────────────────────────────────────────
          Expanded(
            child: foodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 40),
                    const SizedBox(height: 8),
                    Text('$e',
                        style: TextStyle(
                            color: AppColorScheme.of(context).textMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.read(foodsProvider.notifier).fetch(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (foods) {
                final filtered = foods.where((f) {
                  final matchSearch = _search.isEmpty ||
                      f.name
                          .toLowerCase()
                          .contains(_search.toLowerCase()) ||
                      (f.brand
                              ?.toLowerCase()
                              .contains(_search.toLowerCase()) ??
                          false);
                  final matchCat =
                      _categoryFilter == null || f.category == _categoryFilter;
                  return matchSearch && matchCat;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.no_food_outlined,
                            size: 48, color: AppColorScheme.of(context).textMuted),
                        const SizedBox(height: 10),
                        Text(
                          foods.isEmpty
                              ? 'No foods yet. Tap New Food to add.'
                              : _search.isNotEmpty
                                  ? 'No results for "$_search"'
                                  : 'No foods in ${categoryLabels[_categoryFilter] ?? _categoryFilter}',
                          style: TextStyle(
                              color: AppColorScheme.of(context).textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (ctx, i) =>
                      _FoodTile(food: filtered[i], logDate: logDate),
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
// Four-macro pill bar — one pill-arc per macro, all in a row
// ---------------------------------------------------------------------------
class _FourMacroBar extends StatelessWidget {
  const _FourMacroBar({required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(child: _PillArc(label: 'K', actual: totals.kcal,    goal: goals.kcal,    unit: 'kcal', color: AppColorScheme.of(context).kcalColor)),
          const SizedBox(width: 8),
          Expanded(child: _PillArc(label: 'P', actual: totals.protein, goal: goals.protein, unit: 'g',    color: AppColors.protein, isProtein: true)),
          const SizedBox(width: 8),
          Expanded(child: _PillArc(label: 'C', actual: totals.carbs,   goal: goals.carbs,   unit: 'g',    color: AppColors.carbs)),
          const SizedBox(width: 8),
          Expanded(child: _PillArc(label: 'F', actual: totals.fat,     goal: goals.fat,     unit: 'g',    color: AppColors.fat)),
        ],
      ),
    );
  }
}

class _PillArc extends StatelessWidget {
  const _PillArc({
    required this.label, required this.actual, required this.goal,
    required this.unit,  required this.color,  this.isProtein = false,
  });
  final String label, unit;
  final double actual, goal;
  final Color color;
  final bool isProtein;

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0.0;
    final c = (!isProtein && goal > 0 && actual > goal * 1.05)
        ? AppColors.danger
        : color;
    final cs = AppColorScheme.of(context);
    return CustomPaint(
      painter: _PillArcPainter(progress: progress, color: c, borderColor: cs.border),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: c, fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(actual.round().toString(),
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: c)),
            Text('/ ${goal.round()} $unit',
                style: TextStyle(
                    fontSize: 9, color: cs.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _PillArcPainter extends CustomPainter {
  const _PillArcPainter({required this.progress, required this.color, required this.borderColor});
  final double progress;
  final Color color;
  final Color borderColor;

  static const _sw = 2.5;
  static const _r  = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = _sw / 2 + 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(_r),
    );

    // Background border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _sw,
    );

    // Progress arc traced along the pill border
    if (progress > 0) {
      final path = Path()..addRRect(rrect);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * progress),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PillArcPainter old) =>
      old.progress != progress || old.color != color || old.borderColor != borderColor;
}

// ---------------------------------------------------------------------------
// Action bar button
// ---------------------------------------------------------------------------
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: cs.textPrimary),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: cs.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category filter chip
// ---------------------------------------------------------------------------
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Food tile — emoji left, + quick-log right, swipe edit/delete
// ---------------------------------------------------------------------------
class _FoodTile extends ConsumerStatefulWidget {
  const _FoodTile({required this.food, required this.logDate});
  final Food food;
  final String logDate;

  @override
  ConsumerState<_FoodTile> createState() => _FoodTileState();
}

class _FoodTileState extends ConsumerState<_FoodTile>
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('Remove "${widget.food.name}" from your database?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(foodsProvider.notifier).deleteFood(widget.food.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      color: cs.card,
      child: Row(
      children: [
        // ── Swipeable tile area ─────────────────────────────────────────
        Expanded(
          child: GestureDetector(
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
                    // Morph edit/delete buttons
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      child: _MorphButtons(
                        progress: _slideAnim.value,
                        onEdit: () {
                          _close();
                          showAddFoodSheet(context, ref,
                              existing: widget.food);
                        },
                        onDelete: _delete,
                      ),
                    ),
                    // Tile content (slides left)
                    Transform.translate(
                      offset: Offset(offset, 0),
                      child: Container(
                        color: cs.card,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          // Category emoji on the LEFT
                          leading: Text(
                            categoryEmojis[widget.food.category] ?? '🍽️',
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            widget.food.displayName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.food.kcal.round()} kcal · P ${widget.food.protein.round()}g · C ${widget.food.carbs.round()}g · F ${widget.food.fat.round()}g'
                                '  ·  per ${widget.food.unit == 'per100g' ? '100 g' : 'serving'}',
                                style: TextStyle(
                                    fontSize: 12, color: cs.textMuted),
                              ),
                              const SizedBox(height: 6),
                              _MacroRatioBar(
                                protein: widget.food.protein,
                                carbs: widget.food.carbs,
                                fat: widget.food.fat,
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Quick-log + button (always visible) ─────────────────────────
        GestureDetector(
          onTap: () {
            setAllDates(ref, widget.logDate);
            showAddEntrySheet(context, ref, widget.logDate,
                preselectedFood: widget.food);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.border,
              ),
              child: Icon(Icons.add, size: 18, color: cs.textPrimary),
            ),
          ),
        ),
      ],
    ),
    );
  }
}

// ── Morph buttons (circle → rectangle) ───────────────────────────────────────

class _MorphButtons extends StatelessWidget {
  const _MorphButtons({
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

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
              width: btnW,
              radius: radius,
              color: AppColors.protein,
              icon: Icons.edit_outlined,
              label: 'Edit',
              labelOpacity: labelOpacity,
              onTap: onEdit,
            ),
            SizedBox(width: _lerp(6.0, 0.0, progress)),
            _MorphBtn(
              width: btnW,
              radius: radius,
              color: AppColors.danger,
              icon: Icons.delete_outline,
              label: 'Delete',
              labelOpacity: labelOpacity,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MorphBtn extends StatelessWidget {
  const _MorphBtn({
    required this.width,
    required this.radius,
    required this.color,
    required this.icon,
    required this.label,
    required this.labelOpacity,
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
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (labelOpacity > 0) ...[
              const SizedBox(height: 3),
              Opacity(
                opacity: labelOpacity,
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Macro ratio bar ───────────────────────────────────────────────────────────

class _MacroRatioBar extends StatelessWidget {
  const _MacroRatioBar({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    final proteinKcal = protein * 4;
    final carbsKcal = carbs * 4;
    final fatKcal = fat * 9;
    final total = proteinKcal + carbsKcal + fatKcal;

    if (total <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: constraints.maxWidth * 0.5,
          height: 4,
          child: Row(
            children: [
              if (carbsKcal > 0)
                Expanded(
                  flex: (carbsKcal / total * 1000).round(),
                  child: const ColoredBox(color: AppColors.carbs),
                ),
              if (fatKcal > 0)
                Expanded(
                  flex: (fatKcal / total * 1000).round(),
                  child: const ColoredBox(color: AppColors.fat),
                ),
              if (proteinKcal > 0)
                Expanded(
                  flex: (proteinKcal / total * 1000).round(),
                  child: const ColoredBox(color: AppColors.protein),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
