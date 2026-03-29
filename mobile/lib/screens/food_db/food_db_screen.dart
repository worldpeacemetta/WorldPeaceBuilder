import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/food.dart';
import '../../providers/foods_provider.dart';
import '../../theme.dart';
import '../../widgets/add_food_sheet.dart';

class FoodDbScreen extends ConsumerStatefulWidget {
  const FoodDbScreen({super.key});

  @override
  ConsumerState<FoodDbScreen> createState() => _FoodDbScreenState();
}

class _FoodDbScreenState extends ConsumerState<FoodDbScreen> {
  String _search = '';
  String? _categoryFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
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

          // Category chips
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
                  label: '${categoryEmojis[cat] ?? ''} ${categoryLabels[cat] ?? cat}',
                  selected: _categoryFilter == cat,
                  onTap: () => setState(() =>
                      _categoryFilter = _categoryFilter == cat ? null : cat),
                )),
              ],
            ),
          ),

          const Divider(height: 1),

          // Food list
          Expanded(
            child: foodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                    const SizedBox(height: 8),
                    Text('$e', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
                      f.name.toLowerCase().contains(_search.toLowerCase()) ||
                      (f.brand?.toLowerCase().contains(_search.toLowerCase()) ?? false);
                  final matchCat = _categoryFilter == null || f.category == _categoryFilter;
                  return matchSearch && matchCat;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_food_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          foods.isEmpty
                              ? 'No foods yet. Tap + to add.'
                              : _search.isNotEmpty
                                  ? 'No results for "$_search"'
                                  : 'No foods in ${categoryLabels[_categoryFilter] ?? _categoryFilter}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                  itemBuilder: (ctx, i) => _FoodTile(food: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddFoodSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Food'),
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
// Food tile with swipe-to-reveal Edit / Delete
// ---------------------------------------------------------------------------
class _FoodTile extends ConsumerStatefulWidget {
  const _FoodTile({required this.food});
  final Food food;

  @override
  ConsumerState<_FoodTile> createState() => _FoodTileState();
}

class _FoodTileState extends ConsumerState<_FoodTile>
    with SingleTickerProviderStateMixin {
  static const _revealWidth = 144.0; // total width of action buttons
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(foodsProvider.notifier).deleteFood(widget.food.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Swipe left → reveal; swipe right or tap outside → close
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
              // Action buttons (revealed behind)
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit
                    GestureDetector(
                      onTap: () {
                        _close();
                        showAddFoodSheet(context, ref, existing: widget.food);
                      },
                      child: Container(
                        width: 72,
                        color: AppColors.protein,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Colors.white, size: 20),
                            SizedBox(height: 4),
                            Text('Edit',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    // Delete
                    GestureDetector(
                      onTap: _delete,
                      child: Container(
                        width: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          borderRadius:
                              BorderRadius.only(topRight: Radius.zero),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.white, size: 20),
                            SizedBox(height: 4),
                            Text('Delete',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tile (slides left to reveal actions)
              Transform.translate(
                offset: Offset(offset, 0),
                child: Container(
                  color: AppColors.card,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      widget.food.displayName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${widget.food.kcal.round()} kcal · P ${widget.food.protein.round()}g · C ${widget.food.carbs.round()}g · F ${widget.food.fat.round()}g'
                      '  |  per ${widget.food.unit == 'per100g' ? '100 g' : 'serving'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    trailing: Text(
                      categoryEmojis[widget.food.category] ?? '🍽️',
                      style: const TextStyle(fontSize: 18),
                    ),
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
