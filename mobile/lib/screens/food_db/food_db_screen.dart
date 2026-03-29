import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../models/food.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/foods_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/add_entry_sheet.dart';
import '../../widgets/add_food_sheet.dart';
import '../../widgets/barcode_scanner_sheet.dart';

// Returns the likely current meal based on time of day.
String _mealForNow() {
  final h = DateTime.now().hour;
  if (h < 10) return 'breakfast';
  if (h < 14) return 'lunch';
  if (h < 17) return 'snack';
  if (h < 21) return 'dinner';
  return 'other';
}

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
  int _macroIndex = 0; // 0=kcal 1=protein 2=carbs 3=fat
  final _searchCtrl = TextEditingController();

  static const _macroKeys   = ['kcal', 'protein', 'carbs', 'fat'];
  static const _macroColors = [AppColors.kcal, AppColors.protein, AppColors.carbs, AppColors.fat];
  static const _macroUnits  = ['kcal', 'g', 'g', 'g'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _actual(MacroValues t) => switch (_macroKeys[_macroIndex]) {
    'protein' => t.protein, 'carbs' => t.carbs, 'fat' => t.fat, _ => t.kcal,
  };

  double _goalVal(MacroGoals g) => switch (_macroKeys[_macroIndex]) {
    'protein' => g.protein, 'carbs' => g.carbs, 'fat' => g.fat, _ => g.kcal,
  };

  @override
  Widget build(BuildContext context) {
    final logDate    = ref.watch(logDateProvider);
    final totals     = ref.watch(macroTotalsProvider(logDate));
    final goals      = ref.watch(settingsProvider).goalsForDate(logDate);
    final foodsAsync = ref.watch(foodsProvider);

    final actual   = _actual(totals);
    final goal     = _goalVal(goals);
    final progress = goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0.0;
    final isOver   = goal > 0 && actual > goal;
    final color    = _macroColors[_macroIndex];
    final unit     = _macroUnits[_macroIndex];

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
          // ── Macro KPI bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Left: current meal chip
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      mealLabels[_mealForNow()] ?? 'Now',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                // Center: donut KPI
                _MacroKpi(
                  actual: actual,
                  goal: goal,
                  progress: progress,
                  isOver: isOver,
                  color: color,
                  unit: unit,
                ),
                // Right: up/down to switch macro
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(
                            () => _macroIndex = (_macroIndex - 1 + 4) % 4),
                        child: const Icon(Icons.keyboard_arrow_up,
                            color: AppColors.textMuted, size: 24),
                      ),
                      GestureDetector(
                        onTap: () => setState(
                            () => _macroIndex = (_macroIndex + 1) % 4),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.textMuted, size: 24),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
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
                        const Icon(Icons.no_food_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          foods.isEmpty
                              ? 'No foods yet. Tap New Food to add.'
                              : _search.isNotEmpty
                                  ? 'No results for "$_search"'
                                  : 'No foods in ${categoryLabels[_categoryFilter] ?? _categoryFilter}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
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
// Macro KPI — small donut with actual / goal
// ---------------------------------------------------------------------------
class _MacroKpi extends StatelessWidget {
  const _MacroKpi({
    required this.actual,
    required this.goal,
    required this.progress,
    required this.isOver,
    required this.color,
    required this.unit,
  });
  final double actual, goal, progress;
  final bool isOver;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = isOver ? AppColors.danger : color;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(96, 96),
            painter: _ArcPainter(progress: progress, color: c),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actual.round().toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
              Text(
                '/ ${goal.round()}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              Text(
                unit,
                style: TextStyle(fontSize: 9, color: c),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const sw = 8.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 2 * pi, false,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * progress, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
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
    return Row(
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
                        color: AppColors.card,
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
                          subtitle: Text(
                            '${widget.food.kcal.round()} kcal · P ${widget.food.protein.round()}g · C ${widget.food.carbs.round()}g · F ${widget.food.fat.round()}g'
                            '  ·  per ${widget.food.unit == 'per100g' ? '100 g' : 'serving'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
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
          onTap: () => showAddEntrySheet(
            context, ref, widget.logDate,
            preselectedFood: widget.food,
          ),
          child: Container(
            width: 48,
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.protein, width: 1.5),
              ),
              child: const Icon(Icons.add, size: 16, color: AppColors.protein),
            ),
          ),
        ),
      ],
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
