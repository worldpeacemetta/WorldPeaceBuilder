import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../models/food.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/add_entry_sheet.dart';
import '../../widgets/mode_pill.dart';
import '../daily_log/daily_log_screen.dart';

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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entriesProvider(widget.date));
    final entries = entriesAsync.valueOrNull ?? [];
    final settings = ref.watch(settingsProvider);
    final goals = settings.goalsForDate(widget.date);

    final totals = MacroValues.sum(entries.map((e) => e.macros));

    final entriesByMeal = <String, List<Entry>>{};
    for (final meal in mealOrder) {
      final list = entries.where((e) => e.meal == meal).toList();
      if (list.isNotEmpty) entriesByMeal[meal] = list;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateFull(widget.date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ModePill(date: widget.date),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_outlined, color: AppColors.textPrimary),
                onPressed: () => showAddEntrySheet(context, ref, widget.date),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PageView(
                    controller: _pageController,
                    scrollBehavior: const ScrollBehavior().copyWith(dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    }),
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    children: [
                      _MacroTotalsPanel(
                        totals: totals,
                        goals: goals,
                      ),
                      _MealBreakdownPanel(
                        entriesByMeal: entriesByMeal,
                        totalKcal: totals.kcal,
                      ),
                      _TopFoodsPanel(
                        entries: entries,
                        macro: _topFoodsMacro,
                        onMacroChanged: (m) => setState(() => _topFoodsMacro = m),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? AppColors.textPrimary
                            : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (entries.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No entries for this day',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
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
                  final mealTotals =
                      MacroValues.sum(mealEntries.map((e) => e.macros));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              (mealLabels[meal] ?? meal).toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${mealTotals.kcal.round()} kcal',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...mealEntries.map((entry) => _DetailEntryTile(
                            entry: entry,
                            date: widget.date,
                          )),
                      const Divider(height: 1, color: AppColors.border),
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

class _MacroTotalsPanel extends StatelessWidget {
  final MacroValues totals;
  final MacroGoals goals;

  const _MacroTotalsPanel({required this.totals, required this.goals});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MacroItem('Calories', totals.kcal, goals.kcal, AppColors.kcal, 'kcal'),
      _MacroItem('Protein', totals.protein, goals.protein, AppColors.protein, 'g'),
      _MacroItem('Carbs', totals.carbs, goals.carbs, AppColors.carbs, 'g'),
      _MacroItem('Fat', totals.fat, goals.fat, AppColors.fat, 'g'),
    ];

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((item) {
          final pct = item.goal > 0 ? (item.actual / item.goal).clamp(0.0, 1.0) : 0.0;
          final over = item.goal > 0 && item.actual > item.goal;
          final pctLabel =
              item.goal > 0 ? '${(item.actual / item.goal * 100).round()}%' : '—';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '${item.actual.round()} / ${item.goal.round()} ${item.unit}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pctLabel,
                      style: TextStyle(
                        color: over ? AppColors.danger : item.color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        over ? AppColors.danger : item.color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MacroItem {
  final String label;
  final double actual;
  final double goal;
  final Color color;
  final String unit;

  _MacroItem(this.label, this.actual, this.goal, this.color, this.unit);
}

class _MealBreakdownPanel extends StatelessWidget {
  final Map<String, List<Entry>> entriesByMeal;
  final double totalKcal;

  const _MealBreakdownPanel({
    required this.entriesByMeal,
    required this.totalKcal,
  });

  static const _mealEmojis = {
    'breakfast': '🌅',
    'lunch': '☀️',
    'dinner': '🌙',
    'snack': '🍎',
    'other': '🍽️',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: mealOrder
            .where((m) => entriesByMeal.containsKey(m))
            .map((meal) {
          final mealEntries = entriesByMeal[meal]!;
          final mealTotals =
              MacroValues.sum(mealEntries.map((e) => e.macros));
          final share = totalKcal > 0
              ? (mealTotals.kcal / totalKcal).clamp(0.0, 1.0)
              : 0.0;
          final emoji = _mealEmojis[meal] ?? '🍽️';
          final label = mealLabels[meal] ?? meal;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('$emoji $label',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 12)),
                    const Spacer(),
                    Text(
                      '${mealTotals.kcal.round()} kcal',
                      style: const TextStyle(
                        color: AppColors.kcal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'P${mealTotals.protein.round()} C${mealTotals.carbs.round()} F${mealTotals.fat.round()}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.kcal),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TopFoodsPanel extends StatelessWidget {
  final List<Entry> entries;
  final String macro;
  final ValueChanged<String> onMacroChanged;

  const _TopFoodsPanel({
    required this.entries,
    required this.macro,
    required this.onMacroChanged,
  });

  double _macroValue(MacroValues m, String key) {
    switch (key) {
      case 'protein':
        return m.protein;
      case 'carbs':
        return m.carbs;
      case 'fat':
        return m.fat;
      default:
        return m.kcal;
    }
  }

  Color _macroColor(String key) {
    switch (key) {
      case 'protein':
        return AppColors.protein;
      case 'carbs':
        return AppColors.carbs;
      case 'fat':
        return AppColors.fat;
      default:
        return AppColors.kcal;
    }
  }

  String _macroUnit(String key) => key == 'kcal' ? 'kcal' : 'g';

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((a, b) => _macroValue(b.macros, macro)
          .compareTo(_macroValue(a.macros, macro)));
    final top5 = sorted.take(3).toList();
    final maxVal = top5.isNotEmpty ? _macroValue(top5.first.macros, macro) : 1.0;
    final color = _macroColor(macro);
    final unit = _macroUnit(macro);

    const toggleLabels = ['Cal', 'Pro', 'Carb', 'Fat'];
    const toggleKeys = ['kcal', 'protein', 'carbs', 'fat'];

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final selected = toggleKeys[i] == macro;
              return GestureDetector(
                onTap: () => onMacroChanged(toggleKeys[i]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.border : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    toggleLabels[i],
                    style: TextStyle(
                      color:
                          selected ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          ...top5.map((entry) {
            final val = _macroValue(entry.macros, macro);
            final share = maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.food?.name ?? entry.foodId,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${val.round()} $unit',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 3,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

class _DetailEntryTile extends ConsumerWidget {
  final Entry entry;
  final String date;

  const _DetailEntryTile({required this.entry, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = entry.macros;
    final food = entry.food;
    final unit = food?.unit ?? 'g';
    final qty = entry.qty % 1 == 0
        ? entry.qty.toInt().toString()
        : entry.qty.toStringAsFixed(1);

    return ListTile(
      title: Text(
        food?.name ?? entry.foodId,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '$qty $unit  ·  P ${macros.protein.round()}g  C ${macros.carbs.round()}g  F ${macros.fat.round()}g',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${macros.kcal.round()}',
            style: const TextStyle(
              color: AppColors.kcal,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 18, color: AppColors.textMuted),
            color: AppColors.card,
            onSelected: (value) async {
              if (value == 'edit') {
                showEditEntrySheet(context, ref, entry, date);
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: const Text(
                      'Delete Entry',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    content: const Text(
                      'Are you sure you want to delete this entry?',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref
                      .read(entriesProvider(date).notifier)
                      .deleteEntry(entry.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
