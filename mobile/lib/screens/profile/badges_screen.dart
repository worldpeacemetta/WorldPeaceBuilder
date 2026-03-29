import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/badge.dart';
import '../../providers/badges_provider.dart';
import '../../theme.dart';
import '../../widgets/badge_widget.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesState = ref.watch(badgesProvider);
    final earned = badgesState.earned;
    final total  = kBadges.length;
    final count  = kBadges.where((b) => earned.contains(b.stringId)).length;

    // Group badges by category
    final categories = <String, List<BadgeDef>>{};
    for (final b in kBadges) {
      categories.putIfAbsent(b.category, () => []).add(b);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$count / $total',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: badgesState.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ProgressBar(count: count, total: total),
                ),
                const SizedBox(height: 20),
                // Categories
                ...categories.entries.map((entry) => _CategorySection(
                      category: entry.key,
                      badges: entry.value,
                      earned: earned,
                    )),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$count unlocked',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(pct * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.protein),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.badges,
    required this.earned,
  });
  final String category;
  final List<BadgeDef> badges;
  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            category.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...badges.map((b) => _BadgeRow(def: b, unlocked: earned.contains(b.stringId))),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.def, required this.unlocked});
  final BadgeDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: unlocked
            ? Border.all(
                color: def.colorEnd.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          BadgeWidget(def: def, size: 48, locked: !unlocked),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        def.name,
                        style: TextStyle(
                          color: unlocked
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: def.colorStart.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Unlocked',
                          style: TextStyle(
                            color: def.colorEnd,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  def.desc,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
